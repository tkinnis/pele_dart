// Upstream: src/diagrams/timeline/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/edges.dart';
import '../../svg/palette.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit.dart';
import '../common/fit_width.dart';
import 'db.dart';

const double _padX = 12;
const double _padY = 8;
const double _minText = 152;
const double _maxText = 216;
const double _eventTextTd = 264;
const double _gap = 20;
const double _axis = 20;
const double _spine = 14;
const double _eventGap = 8;
const double _sectionGap = 8;
const double _tail = 12;
const String _onColor = ' fill="var(--_bg)"';
const String _line = ' fill="none" stroke="var(--_b)"';

class _Group {
  final int section;
  final List<int> periods;

  _Group({required this.section, required this.periods});
}

String _box(double x, double y, double w, double h, String attrs) {
  return '<rect x="${num(x)}" y="${num(y)}" width="${num(w)}" height="${num(h)}"${rounded(attrs)}/>';
}

Rendered renderTimeline(
  TimelineModel model,
  Config config,
  RenderOptions options,
) {
  if (model.direction == 'TD') return _draw(model, config, options, true);
  return turnToFit(options, (down) => _draw(model, config, options, down));
}

Rendered _draw(
  TimelineModel model,
  Config config,
  RenderOptions options,
  bool vertical,
) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875);
  final smallD = small.toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final timelineConfig = config['timeline'];
  final multicolor =
      !(timelineConfig is Map && timelineConfig['disableMulticolor'] == true);
  final periods = model.periods;
  final hasSections = model.sections.isNotEmpty;

  // Mermaid draws nothing for periods that come before the first section; here they lead, in a neutral color.
  final groups = List<_Group>.generate(
    model.sections.length,
    (section) => _Group(section: section, periods: <int>[]),
  );
  final leading = _Group(section: -1, periods: <int>[]);
  for (var i = 0; i < periods.length; i++) {
    final period = periods[i];
    final target =
        (period.sectionIndex >= 0 && period.sectionIndex < groups.length)
        ? groups[period.sectionIndex]
        : leading;
    target.periods.add(i);
  }
  if (leading.periods.isNotEmpty) groups.insert(0, leading);

  // Columns widen, up to a point, for a word that would not fit; past that the word is cut.
  // Running down, the two columns share the width the host has.
  final room = vertical && options.maxWidth != null && options.maxWidth! > 0
      ? options.maxWidth! - 2 * pad
      : double.infinity;
  const taken = _axis + _spine * 2 + 4 * _padX;
  final periodText = room.isInfinite
      ? _minText
      : math.min<double>(
          _minText,
          math.max<double>(80, roundJs((room - taken) * 0.38).toDouble()),
        );
  final eventText = room.isInfinite
      ? _eventTextTd
      : math.min<double>(
          _eventTextTd,
          math.max<double>(110, room - taken - periodText),
        );
  var textW = periodText;
  double eventTextW() => vertical ? eventText : textW;
  var periodLabels = periods
      .map((p) => plainLabel(p.text, measurer, size, textW))
      .toList();
  var eventLabels = periods
      .map(
        (p) => p.events
            .map((e) => plainLabel(e, measurer, smallD, eventTextW()))
            .toList(),
      )
      .toList();
  var widest = 0.0;
  for (final label in periodLabels) {
    widest = math.max(widest, label.width);
  }
  if (!vertical) {
    for (final labels in eventLabels) {
      for (final label in labels) {
        widest = math.max(widest, label.width);
      }
    }
  }
  var overflow = widest > textW;
  if (vertical) {
    for (final labels in eventLabels) {
      for (final label in labels) {
        overflow = overflow || label.width > eventText;
      }
    }
  }
  if (overflow) {
    textW = math.min<double>(
      math.max<double>(widest.ceilToDouble(), periodText),
      room.isInfinite ? _maxText : periodText,
    );
    periodLabels = periods
        .map((p) => fitLabel(p.text, measurer, size, textW))
        .toList();
    eventLabels = periods
        .map(
          (p) => p.events
              .map((e) => fitLabel(e, measurer, smallD, eventTextW()))
              .toList(),
        )
        .toList();
  }

  final lineHeight = roundJs(size * 1.5).toDouble();
  final colW = textW + 2 * _padX;
  final eventW = eventTextW() + 2 * _padX;
  double chipHeight(Label label) =>
      math.max(label.height, lineHeight) + 2 * _padY;
  final smallLineHeight = roundJs(smallD * 1.5).toDouble();
  double eventHeight(Label label) =>
      math.max(label.height, smallLineHeight) + 2 * _padY;
  int? seriesOf(_Group group, int period) => group.section >= 0
      ? group.section
      : hasSections
      ? null
      : multicolor
      ? period
      : 0;
  String colorOf(_Group group, int period) {
    final series = seriesOf(group, period);
    return series == null ? 'var(--_m)' : seriesColor(series);
  }

  String onColor(int? series) {
    final fill = series == null ? '' : seriesInkFill(series);
    return fill.isNotEmpty ? fill : _onColor;
  }

  var hasEvents = false;
  for (final labels in eventLabels) {
    if (labels.isNotEmpty) hasEvents = true;
  }
  var slots = 0;
  for (final group in groups) {
    slots += math.max<int>(group.periods.length, 1);
  }

  final pitch = colW + _gap;
  final drawn = periods.isNotEmpty;
  final bodyW = vertical
      ? colW +
            (hasEvents
                ? _axis + _spine * 2 + eventW
                : drawn
                ? _axis + _tail
                : 0.0)
      : slots > 0
      ? slots * pitch - _gap + (drawn ? _tail + ARROW : 0.0)
      : 0.0;
  final title = fitLabel(
    model.title,
    measurer,
    size,
    math.max<double>(bodyW, 320),
    Style.Bold,
  );
  final titleH = title.height > 0 ? title.height + 16 : 0.0;
  final width = math.max(bodyW, title.width);
  final left = pad + (width - bodyW) / 2;
  final top = pad + titleH;

  Label sectionLabel(_Group group, double w) => fitLabel(
    model.sections[group.section],
    measurer,
    size,
    w - 2 * _padX,
    Style.Bold,
  );
  String header(
    _Group group,
    Label label,
    double x,
    double y,
    double w,
    double h,
  ) =>
      _box(x, y, w, h, ' fill="${seriesColor(group.section)}"') +
      labelSvg(
        label,
        x + w / 2,
        y + h / 2,
        ' font-weight="var(--_hw)"${onColor(group.section)}',
      );
  String period(
    int i,
    _Group group,
    String color,
    double x,
    double y,
    double h,
  ) =>
      _box(x, y, colW, h, ' fill="$color"') +
      labelSvg(
        periodLabels[i],
        x + colW / 2,
        y + h / 2,
        onColor(seriesOf(group, i)),
      );
  String event(Label label, String color, double x, double y, double h) =>
      '<g class="pele-node pele-event">'
      '${_box(x, y, eventW, h, ' fill="$color" fill-opacity="0.16"')}'
      '${labelSvg(label, x + eventW / 2, y + h / 2, ' font-size="$small"')}'
      '</g>';
  String dot(double x, double y, String color) =>
      '<circle class="pele-dot" cx="${num(x)}" cy="${num(y)}" r="4" fill="$color" stroke="var(--_bg)" stroke-width="2"/>';
  String open(_Group group) => group.section >= 0
      ? '<g class="pele-cluster pele-section" data-id="${escText(model.sections[group.section].trim())}">'
      : '';
  String openPeriod(int i) =>
      '<g class="pele-node pele-period" data-id="${escText(periods[i].text.trim())}">';

  final body = StringBuffer();
  String prefix = '';
  double height;

  if (vertical) {
    final axisX = left + colW + _axis;
    final spineX = axisX + _spine;
    final eventsX = spineX + _spine;
    var y = top;
    for (final group in groups) {
      body.write(open(group));
      if (group.section >= 0) {
        final label = sectionLabel(group, bodyW);
        final h = chipHeight(label);
        body.write(header(group, label, left, y, bodyW, h));
        y += h + _sectionGap + 4;
      }
      for (final i in group.periods) {
        final color = colorOf(group, i);
        final h = chipHeight(periodLabels[i]);
        // A period and its first event share one center line, so the line between them runs straight.
        final first = eventLabels[i].isNotEmpty
            ? eventHeight(eventLabels[i][0])
            : h;
        final cy = y + math.max(h, first) / 2;
        final d = StringBuffer('M${num(left + colW)},${num(cy)}H${num(axisX)}');
        final cards = StringBuffer();
        var ey = cy - first / 2;
        var last = cy;
        for (final label in eventLabels[i]) {
          final eh = eventHeight(label);
          last = ey + eh / 2;
          d.write('M${num(spineX)},${num(last)}H${num(eventsX)}');
          cards.write(event(label, color, eventsX, ey, eh));
          ey += eh + _eventGap;
        }
        if (cards.isNotEmpty) {
          d.write('M${num(axisX)},${num(cy)}H${num(spineX)}V${num(last)}');
        }
        body
          ..write(openPeriod(i))
          ..write(period(i, group, color, left, cy - h / 2, h))
          ..write('<path class="pele-edge" d="$d"$_line/>')
          ..write(dot(axisX, cy, color))
          ..write(cards)
          ..write('</g>');
        y = math.max(cy + h / 2, ey - _eventGap) + _gap;
      }
      if (group.periods.isEmpty) y += _gap - _sectionGap - 4;
      if (group.section >= 0) body.write('</g>');
    }
    if (groups.isNotEmpty) y -= _gap;
    if (drawn) {
      final tip = y + _tail + ARROW;
      prefix =
          '<path class="pele-axis" d="M${num(axisX)},${num(top)}V${num(tip - ARROW + 1)}" fill="none" stroke="var(--_l)"/>' +
          marker('arrow_point', axisX, tip, 0, 1, 'var(--_l)');
      y = tip;
    }
    height = y + pad;
  } else {
    var headerH = 0.0;
    final sectionLabels = groups.map((group) {
      if (group.section < 0) return null;
      final label = sectionLabel(
        group,
        math.max<int>(group.periods.length, 1) * pitch - _gap,
      );
      headerH = math.max(headerH, chipHeight(label));
      return label;
    }).toList();
    var chipH = 0.0;
    for (final label in periodLabels) {
      chipH = math.max(chipH, chipHeight(label));
    }
    final periodsY = top + (hasSections ? headerH + _sectionGap : 0);
    final axisY = periodsY + chipH + (chipH > 0 ? _axis : 0);
    final eventsY = axisY + _axis;
    var bottom = drawn ? axisY + _tail : top + headerH;
    var slot = 0;
    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      final span = math.max<int>(group.periods.length, 1);
      final gx = left + slot * pitch;
      body.write(open(group));
      final label = sectionLabels[g];
      if (label != null) {
        body.write(header(group, label, gx, top, span * pitch - _gap, headerH));
      }
      for (var k = 0; k < group.periods.length; k++) {
        final i = group.periods[k];
        final color = colorOf(group, i);
        final x = gx + k * pitch;
        final cx = x + colW / 2;
        final d = StringBuffer(
          'M${num(cx)},${num(periodsY + chipH)}V${num(eventLabels[i].isNotEmpty ? eventsY : axisY)}',
        );
        final cards = StringBuffer();
        var ey = eventsY;
        for (final eventLabel in eventLabels[i]) {
          final eh = eventHeight(eventLabel);
          if (ey > eventsY) {
            d.write('M${num(cx)},${num(ey - _eventGap)}V${num(ey)}');
          }
          cards.write(event(eventLabel, color, x, ey, eh));
          ey += eh + _eventGap;
        }
        bottom = math.max(bottom, ey - _eventGap);
        body
          ..write(openPeriod(i))
          ..write(period(i, group, color, x, periodsY, chipH))
          ..write('<path class="pele-edge" d="$d"$_line/>')
          ..write(dot(cx, axisY, color))
          ..write(cards)
          ..write('</g>');
      }
      if (group.section >= 0) body.write('</g>');
      slot += span;
    }
    if (drawn) {
      final tip = left + bodyW;
      prefix =
          '<path class="pele-axis" d="M${num(left)},${num(axisY)}H${num(tip - ARROW + 1)}" fill="none" stroke="var(--_l)"/>' +
          marker('arrow_point', tip, axisY, 1, 0, 'var(--_l)');
    }
    height = bottom + pad;
  }

  final totalWidth = (width + 2 * pad).ceilToDouble();
  final totalHeight = math.max(height, pad * 2).ceilToDouble();
  final content =
      labelSvg(
        title,
        totalWidth / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      prefix +
      body.toString();
  return Rendered(
    svg: svgDocument(
      'timeline',
      totalWidth,
      totalHeight,
      size,
      options,
      model,
      content,
    ),
    width: totalWidth,
    height: totalHeight,
    links: <LinkInfo>[],
  );
}
