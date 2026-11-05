// Upstream: src/diagrams/kanban/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../svg/title.dart';
import '../../text/icons.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../../util/url.dart';
import '../common/fit_width.dart';
import '../common/icon.dart';
import 'db.dart';

const double _columnGap = 12;
const double _columnPad = 8;
const double _cardPad = 10;
const double _cardGap = 8;
const double _metaGap = 4;
const double _iconGap = 6;

// Mermaid names five priorities and gives Medium no color. Matching here ignores case. The high
// ones are marked in the critical color and the low ones in the muted one, the nearer to Medium
// the fainter. They are not series colors, as a theme may put those in any order.
const Map<String, String> _priority = <String, String>{
  'very high': 'stroke="$critical"',
  'high': 'stroke="$critical" opacity="0.5"',
  'low': 'stroke="var(--_m)" opacity="0.5"',
  'very low': 'stroke="var(--_m)"',
};

// Lays out text for a fixed width. A word too long for a line is broken between characters,
// because a card cannot grow sideways to hold it.
Label _fitLabel(
  String? raw,
  bool markdown,
  TextMeasurer measurer,
  double size,
  double max, [
  int base = 0,
]) {
  final label = layoutLabel(raw, markdown, measurer, size, max, base);
  if (label.width <= max) return label;
  final lines = <List<Span>>[];
  final widths = <double>[];
  var widest = 0.0;
  var line = <Span>[];
  var width = 0.0;
  void commit() {
    lines.add(line);
    widths.add(width);
    widest = math.max(widest, width);
    line = <Span>[];
    width = 0.0;
  }

  for (var i = 0; i < label.lines.length; i++) {
    if (label.widths[i] <= max) {
      line = label.lines[i];
      width = label.widths[i];
      commit();
      continue;
    }
    for (final span in label.lines[i]) {
      if (span.icon != null || span.math != null) {
        if (width > 0 && width + span.width > max) commit();
        line.add(span);
        width += span.width;
        continue;
      }
      var text = '';
      var from = width;
      for (final ch in codePointsOf(span.text)) {
        final w = measurer.width(ch, size, span.style);
        if (width > 0 && width + w > max) {
          if (text.isNotEmpty) {
            line.add(Span(text: text, style: span.style, width: width - from));
          }
          commit();
          text = '';
          from = 0.0;
        }
        text += ch;
        width += w;
      }
      if (text.isNotEmpty) {
        line.add(Span(text: text, style: span.style, width: width - from));
      }
    }
    commit();
  }
  final fitted = label.copyWith(
    lines: lines,
    widths: widths,
    width: widest,
    height: lines.length * label.lineHeight,
  );
  return label.heights != null ? withHeights(fitted) : fitted;
}

// Writes a label with every line starting at x, or ending there, and the first line's box starting at y.
String _textBlock(
  Label label,
  double x,
  double y,
  String attrs,
  IconResolver? icons, [
  bool end = false,
]) {
  final out = StringBuffer();
  for (var i = 0; i < label.lines.length; i++) {
    final line = label.lines[i];
    final cy = y + lineMiddle(label, i);
    if (line.length == 1 &&
        line[0].icon == null &&
        line[0].math == null &&
        (line[0].style & (Style.Sub | Style.Sup | Style.Underline)) == 0) {
      out.write(
        '<text${textStyle(attrs, line[0].style)} x="${num(x)}" y="${num(cy + label.size * 0.35)}"${end ? ' text-anchor="end"' : ''}>${esc(line[0].text)}</text>',
      );
    } else {
      final width = label.widths[i];
      out.write(
        labelSvg(
          labelLine(label, i),
          x + (end ? -width : width) / 2,
          cy,
          attrs,
          icons,
        ),
      );
    }
  }
  return out.toString();
}

class _Card {
  final KanbanNode item;
  final Label label;
  final Label ticket;
  final Label assigned;
  // Height of the rows under the text that hold the ticket and the assignee.
  final double meta;
  final double height;

  const _Card({
    required this.item,
    required this.label,
    required this.ticket,
    required this.assigned,
    required this.meta,
    required this.height,
  });
}

bool _has(String? name) =>
    name != null && name.isNotEmpty && iconMarkup(name).isNotEmpty;

Rendered renderKanban(KanbanModel model, Config config, RenderOptions options) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875).toDouble();
  final line = roundJs(size * 1.5).toDouble();
  final smallLine = roundJs(small * 1.5).toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final icons = options.icons;
  final conf = asConfig(config['kanban']);
  final sectionWidthVal = conf['sectionWidth'];
  final double? sectionWidth = sectionWidthVal is int
      ? sectionWidthVal.toDouble()
      : (sectionWidthVal is double ? sectionWidthVal : null);
  final glyph = small * 1.25;

  // Math can't break across lines, so columns widen to hold the widest expression.
  var mathWidth = 0.0;
  void holds(String? raw, double fontSize, double reserved) {
    if (raw == null || !raw.contains('\$\$')) return;
    for (final spans in layoutLabel(
      raw,
      true,
      measurer,
      fontSize,
      double.infinity,
    ).lines) {
      for (final span in spans) {
        if (span.math != null) {
          mathWidth = math.max(mathWidth, span.math!.width + reserved);
        }
      }
    }
  }

  for (final section in model.sections) {
    final count = measurer.width('${section.items.length}', small, 0);
    holds(
      section.label,
      size,
      2 * _columnPad +
          8 +
          count +
          12 +
          (_has(section.icon) ? glyph + _iconGap : 0),
    );
    for (final item in section.items) {
      const reserved = 2 * (_columnPad + _cardPad);
      holds(
        item.label,
        small,
        reserved + (_has(item.icon) ? glyph + _iconGap : 0),
      );
      holds(item.ticket, small, reserved);
      holds(item.assigned, small, reserved);
    }
  }

  final ownWidth = math.max(
    sectionWidth != null && sectionWidth > 0
        ? math.min(math.max(sectionWidth, 80.0), 2000.0)
        : 200.0,
    mathWidth.ceilToDouble(),
  );
  // A board wider than the width the host has is folded into rows of columns, which then
  // share the row between them.
  final room = options.maxWidth != null && options.maxWidth! > 0
      ? options.maxWidth! - 2 * pad
      : double.infinity;
  final count = model.sections.length;
  final fits = count * (ownWidth + _columnGap) - _columnGap <= room;
  final perRow = fits
      ? math.max<int>(count, 1)
      : math.max<int>(
          1,
          ((room + _columnGap) / (ownWidth + _columnGap)).floor(),
        );
  final columnWidth = fits
      ? ownWidth
      : math.max(
          math.max(
            math.min(ownWidth, room),
            math.min(
              ((room + _columnGap) / perRow).floorToDouble() - _columnGap,
              ownWidth * 2,
            ),
          ),
          mathWidth.ceilToDouble(),
        );
  final baseUrl = conf['ticketBaseUrl'] is String
      ? conf['ticketBaseUrl'] as String
      : '';
  final cardWidth = columnWidth - 2 * _columnPad;
  final textWidth = cardWidth - 2 * _cardPad;
  final links = <LinkInfo>[];

  final sections = model.sections;
  final titles = <Label>[];
  final countWidths = <double>[];
  final cards = <List<_Card>>[];
  var headHeight = line;
  final bodyHeights = <double>[];
  for (final section in sections) {
    final countWidth = measurer.width('${section.items.length}', small, 0);
    final reserved =
        countWidth + 12 + (_has(section.icon) ? glyph + _iconGap : 0);
    final title = _fitLabel(
      section.label,
      true,
      measurer,
      size,
      cardWidth - 8 - reserved,
      Style.Bold,
    );
    headHeight = math.max(headHeight, title.height);
    countWidths.add(countWidth);
    titles.add(title);

    final list = <_Card>[];
    var height = 0.0;
    for (final item in section.items) {
      final label = _fitLabel(
        item.label,
        true,
        measurer,
        small,
        textWidth - (_has(item.icon) ? glyph + _iconGap : 0),
      );
      final ticket = _fitLabel(item.ticket, false, measurer, small, textWidth);
      final assigned = _fitLabel(
        item.assigned,
        false,
        measurer,
        small,
        textWidth,
      );
      final meta = ticket.width + assigned.width + 8 > textWidth
          ? ticket.height + assigned.height
          : math.max(ticket.height, assigned.height);
      final cardHeight =
          2 * _cardPad +
          math.max(label.height, smallLine) +
          (meta > 0 ? _metaGap + meta : 0);
      list.add(
        _Card(
          item: item,
          label: label,
          ticket: ticket,
          assigned: assigned,
          meta: meta,
          height: cardHeight,
        ),
      );
      height += cardHeight + _cardGap;
    }
    cards.add(list);
    bodyHeights.add(height);
  }
  headHeight += 2 * _columnPad;
  final rowHeights = <double>[];
  final rowTops = <double>[];
  for (var first = 0, y = 0.0; first < sections.length; first += perRow) {
    var tallest = _cardGap;
    for (
      var index = first;
      index < math.min<int>(first + perRow, sections.length);
      index++
    ) {
      tallest = math.max(tallest, bodyHeights[index]);
    }
    rowTops.add(y);
    rowHeights.add(headHeight + tallest);
    y += headHeight + tallest + _columnGap;
  }
  final boardHeight = rowHeights.isNotEmpty
      ? rowTops.last + rowHeights.last
      : 0.0;

  final title = titleLabel(model.title, measurer, size, titleRoom(options));
  final titleHeight = title.height > 0 ? title.height + 16 : 0.0;
  final boardWidth = math.max(
    math.min<int>(sections.length, perRow) * (columnWidth + _columnGap) -
        _columnGap,
    0.0,
  );
  final width = math.max(boardWidth, title.width);
  final left = pad + (width - boardWidth) / 2;
  final edge = columnWidth - _columnPad - 4;

  final out = StringBuffer();
  for (var index = 0; index < sections.length; index++) {
    final section = sections[index];
    final row = index ~/ perRow;
    final body = StringBuffer()
      ..write(
        '<rect width="${num(columnWidth)}" height="${num(rowHeights[row])}" fill="var(--_s)"$roundedAttr/>',
      )
      ..write(
        _textBlock(
          titles[index],
          _columnPad + 4,
          _columnPad,
          ' class="pele-cluster-label" font-weight="var(--_hw)"',
          icons,
        ),
      )
      ..write(
        '<text class="pele-count" x="${num(edge)}" y="${num(_columnPad + line / 2 + small * 0.35)}" text-anchor="end" font-size="${num(small)}" fill="var(--_m)">${section.items.length}</text>',
      );
    if (_has(section.icon)) {
      body.write(
        iconSvg(
          section.icon!,
          edge - countWidths[index] - _iconGap - glyph,
          _columnPad + (line - glyph) / 2,
          glyph,
          icons,
        ),
      );
    }

    var y = headHeight;
    for (final card in cards[index]) {
      final item = card.item;
      final priority = (item.priority ?? '').trim().toLowerCase();
      final color = _priority[priority];
      final inner = StringBuffer()
        ..write(
          '<rect width="${num(cardWidth)}" height="${num(card.height)}" fill="var(--_bg)" stroke="var(--_b)"$roundedAttr/>',
        );
      if (color != null) {
        inner.write(
          '<path class="pele-priority" d="M2.5,5V${num(card.height - 5)}" fill="none" $color stroke-width="3" stroke-linecap="round"/>',
        );
      }
      inner.write(
        _textBlock(
          card.label,
          _cardPad,
          _cardPad,
          ' class="pele-label"',
          icons,
        ),
      );
      if (_has(item.icon)) {
        inner.write(
          iconSvg(
            item.icon!,
            cardWidth - _cardPad - glyph,
            _cardPad + (smallLine - glyph) / 2,
            glyph,
            icons,
          ),
        );
      }
      final bottom = card.height - _cardPad;
      if (item.ticket != null && item.ticket!.isNotEmpty) {
        final top = bottom - card.meta;
        final href = baseUrl.isNotEmpty
            ? linkUrl(
                safeUrl(baseUrl.replaceFirst('#TICKET#', item.ticket!)),
                options,
              )
            : null;
        if (href == null) {
          inner.write(
            _textBlock(
              card.ticket,
              _cardPad,
              top,
              ' class="pele-ticket" fill="var(--_m)"',
              icons,
            ),
          );
        } else {
          inner
            ..write(
              '<a href="${esc(href)}" target="_blank"${relAttr(options)}>',
            )
            ..write(
              _textBlock(
                card.ticket,
                _cardPad,
                top,
                ' class="pele-ticket" fill="var(--_c)"',
                icons,
              ),
            )
            ..write('</a>');
          links.add(LinkInfo(id: item.id, href: href, internal: false));
        }
      }
      if (item.assigned != null && item.assigned!.isNotEmpty) {
        inner.write(
          _textBlock(
            card.assigned,
            cardWidth - _cardPad,
            bottom - card.assigned.height,
            ' class="pele-assigned" fill="var(--_m)"',
            icons,
            true,
          ),
        );
      }
      body.write(
        '<g class="pele-node pele-card${color == null ? '' : ' pele-priority-${priority.replaceFirst(' ', '-')}'}${classNames(item.cssClasses ?? '')}" data-id="${escText(item.id)}" transform="translate(${num(_columnPad)},${num(y)})" font-size="${num(small)}">$inner</g>',
      );
      y += card.height + _cardGap;
    }

    out.write(
      '<g class="pele-cluster pele-column${classNames(section.cssClasses ?? '')}" data-id="${escText(section.id)}" transform="translate(${num(left + (index % perRow) * (columnWidth + _columnGap))},${num(pad + titleHeight + rowTops[row])})">$body</g>',
    );
  }

  final totalWidth = (width + 2 * pad).ceilToDouble();
  final totalHeight = (boardHeight + titleHeight + 2 * pad).ceilToDouble();
  final content =
      labelSvg(
        title,
        totalWidth / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      out.toString();

  return Rendered(
    svg: svgDocument(
      'kanban',
      totalWidth,
      totalHeight,
      size,
      options,
      const Accessible(),
      content,
    ),
    width: totalWidth,
    height: totalHeight,
    links: links,
  );
}
