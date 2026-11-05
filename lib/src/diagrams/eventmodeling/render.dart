// Upstream: src/diagrams/eventmodeling/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/edges.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/entities.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_width.dart';
import '../common/literal_label.dart';
import 'model.dart';

// Series slot for each kind of entity. A UI has none and is drawn plain.
const Map<EntityKind, int> _series = <EntityKind, int>{
  'command': 0,
  'event': 1,
  'readmodel': 2,
  'processor': 6,
};

const double _boxPadX = 12;
const double _boxPadY = 10;
const double _boxMinWidth = 96;
const double _boxGap = 16;
const double _stagger = 80;
const double _lanePad = 12;
const double _laneGap = 8;
const int _dataColumns = 48;
const int _noteColumns = 80;
const double _cardGap = 8;

class _Placed {
  final EmBox box;
  final Label name;
  final List<String> data;
  double x;
  double y;
  final double w;
  final double h;

  _Placed({
    required this.box,
    required this.name,
    required this.data,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}

class _Band {
  final EmLane lane;
  final Label label;
  double right;
  double y;
  double h;

  _Band({
    required this.lane,
    required this.label,
    required this.right,
    required this.y,
    required this.h,
  });
}

// Splits text into lines of at most `columns` characters, keeping its own line breaks.
List<String> _hardWrap(String text, int columns) {
  final out = <String>[];
  for (final line in decodeEntities(text).split('\n')) {
    final chars = line.length <= columns ? null : codePointsOf(line);
    if (chars == null || chars.length <= columns) {
      out.add(line);
      continue;
    }
    for (var i = 0; i < chars.length; i += columns) {
      out.add(chars.sublist(i, math.min(i + columns, chars.length)).join());
    }
  }
  return out;
}

String _lines(
  List<String> rows,
  double x,
  double y,
  double step,
  String attrs,
) {
  final body = StringBuffer();
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].isNotEmpty) {
      body.write(
        '<tspan x="${num(x)}" y="${num(y + i * step)}">${esc(rows[i])}</tspan>',
      );
    }
  }
  return body.isEmpty ? '' : '<text$attrs xml:space="preserve">$body</text>';
}

Rendered renderEventModel(
  EventModelingModel model,
  Config config,
  RenderOptions options,
) {
  return turnToFit(options, (down) => _draw(model, config, options, down));
}

Rendered _draw(
  EventModelingModel model,
  Config config,
  RenderOptions options,
  bool down,
) {
  if (down) return _verticalEventModel(model, options);
  final size = options.fontSize ?? 16;
  final nameSize = roundJs(size * 0.875);
  final small = roundJs(size * 0.8125);
  final mono = roundJs(size * 0.75);
  final monoStep = roundJs(mono * 1.4).toDouble();
  final smallStep = roundJs(small * 1.5).toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  double widest(List<String> rows, double fontSize, int style) {
    var width = 0.0;
    for (final row in rows) {
      width = math.max(width, measurer.width(row, fontSize, style));
    }
    return width;
  }

  final bands = <EmLane, _Band>{};
  var labelColumn = 0.0;
  for (final lane in model.lanes) {
    final label = layoutLabel(
      lane.label,
      false,
      measurer,
      small.toDouble(),
      4000,
      Style.Bold,
    );
    labelColumn = math.max(labelColumn, label.width);
    bands[lane] = _Band(
      lane: lane,
      label: label,
      right: double.negativeInfinity,
      y: 0,
      h: 0,
    );
  }
  labelColumn += 2 * _lanePad;

  // Time runs left to right. A frame in a new lane starts under the end of the one before it,
  // so the arrow between them can drop straight down; a frame in the same lane follows on.
  final placed = <_Placed>[];
  final byBox = <EmBox, _Placed>{};
  _Placed? previous;
  for (final box in model.boxes) {
    final band = bands[box.lane]!;
    final name = layoutLabel(
      box.name,
      false,
      measurer,
      nameSize.toDouble(),
      4000,
      Style.Bold,
    );
    final data = (box.data != null && box.data!.isNotEmpty)
        ? _hardWrap(box.data!, _dataColumns)
        : const <String>[];
    final w = math.max(
      _boxMinWidth,
      math.max(name.width, widest(data, mono.toDouble(), Style.Mono)) +
          2 * _boxPadX,
    );
    final h =
        2 * _boxPadY +
        name.height +
        (data.isNotEmpty ? 6 + data.length * monoStep : 0);
    var x = 0.0;
    if (previous != null) {
      final stagger =
          previous.x + math.max(previous.w / 2, previous.w - _stagger);
      x = identical(previous.box.lane, box.lane)
          ? band.right + _boxGap
          : math.max(stagger, band.right + _boxGap);
    }
    final item = _Placed(
      box: box,
      name: name,
      data: data,
      x: x,
      y: 0,
      w: w,
      h: h,
    );
    band.right = x + w;
    band.h = math.max(band.h, h);
    placed.add(item);
    byBox[box] = item;
    previous = item;
  }

  var contentRight = 0.0;
  for (final item in placed) {
    contentRight = math.max(contentRight, item.x + item.w);
  }
  final laneWidth = labelColumn + contentRight + _lanePad;

  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    4000,
    Style.Bold,
  );
  final titleHeight = title.height > 0 ? title.height + 12 : 0.0;
  final left = pad;
  final top = pad + titleHeight;

  var y = top;
  final lanes = StringBuffer();
  for (final band in bands.values) {
    band.y = y;
    band.h += 2 * _lanePad;
    lanes.write(
      '<g class="pele-cluster pele-em-lane" data-id="${escText(band.lane.label)}">'
      '<rect x="${num(left)}" y="${num(y)}" width="${num(laneWidth)}" height="${num(band.h)}" fill="var(--_s)"$roundedAttr/>'
      '${labelSvg(band.label, left + _lanePad + band.label.width / 2, y + band.h / 2, ' class="pele-cluster-label" font-size="$small" font-weight="var(--_hw)" fill="var(--_m)"')}'
      '</g>',
    );
    y += band.h + _laneGap;
  }
  var bottom = bands.isNotEmpty ? y - _laneGap : top;

  final nodes = StringBuffer();
  for (final item in placed) {
    final band = bands[item.box.lane]!;
    item.x += left + labelColumn;
    item.y = band.y + (band.h - item.h) / 2;
    final series = _series[item.box.kind];
    final frame =
        'x="${num(item.x)}" y="${num(item.y)}" width="${num(item.w)}" height="${num(item.h)}"';
    final shape = series == null
        ? '<rect $frame fill="var(--_bg)" stroke="var(--_b)"$roundedAttr/>'
        : '<rect $frame fill="var(--_bg)"$roundedAttr/><rect $frame fill="${seriesColor(series)}" fill-opacity="0.22" stroke="${seriesColor(series)}"$roundedAttr/>';
    final nameY = item.y + _boxPadY + item.name.height / 2;
    final text =
        labelSvg(
          item.name,
          item.x + item.w / 2,
          nameY,
          ' class="pele-label" font-size="$nameSize" font-weight="var(--_hw)"',
        ) +
        _lines(
          item.data,
          item.x + _boxPadX,
          item.y + _boxPadY + item.name.height + 6 + monoStep / 2 + mono * 0.35,
          monoStep,
          ' class="pele-em-data" font-family="$fontMono" font-size="$mono"',
        );
    nodes.write(
      '<g class="pele-node pele-em-${item.box.kind}${item.box.reset ? ' pele-em-reset' : ''}" data-id="${escText(item.box.id)}">$shape$text</g>',
    );
  }

  final edges = StringBuffer();
  final trim = markerTrim('arrow_point');
  for (final relation in model.relations) {
    final s = byBox[relation.source];
    final t = byBox[relation.target];
    if (s == null || t == null || identical(s, t)) continue;
    String d;
    String head;
    if (identical(s.box.lane, t.box.lane)) {
      // Along the lane, from the side of one box to the side of the other.
      final forward = t.x >= s.x;
      final sx = forward ? s.x + s.w : s.x;
      final tx = forward ? t.x : t.x + t.w;
      final sy = s.y + s.h / 2;
      final ty = t.y + t.h / 2;
      final dir = tx >= sx ? 1.0 : -1.0;
      d = 'M${num(sx)},${num(sy)}L${num(tx - dir * trim)},${num(ty)}';
      head = marker('arrow_point', tx, ty, dir, 0, 'var(--_l)');
    } else {
      // Between lanes, straight down or up where the boxes overlap, else in an S.
      final down = t.y > s.y;
      final from = math.max(s.x, t.x);
      final to = math.min(s.x + s.w, t.x + t.w);
      double inset(double w) => math.min(24.0, w / 4);
      final sx = to - from >= 16
          ? (from + to) / 2
          : (t.x > s.x ? s.x + s.w - inset(s.w) : s.x + inset(s.w));
      final tx = to - from >= 16
          ? sx
          : (t.x > s.x ? t.x + inset(t.w) : t.x + t.w - inset(t.w));
      final sy = down ? s.y + s.h : s.y;
      final ty = down ? t.y : t.y + t.h;
      final dir = down ? 1.0 : -1.0;
      final end = ty - dir * trim;
      final mid = (sy + end) / 2;
      d = sx == tx
          ? 'M${num(sx)},${num(sy)}V${num(end)}'
          : 'M${num(sx)},${num(sy)}C${num(sx)},${num(mid)} ${num(tx)},${num(mid)} ${num(tx)},${num(end)}';
      head = marker('arrow_point', tx, ty, 0, dir, 'var(--_l)');
    }
    edges.write(
      '<g class="pele-edge" data-id="${escText(relation.source.id)}-${escText(relation.target.id)}"><path d="$d" fill="none" stroke="var(--_l)"/>$head</g>',
    );
  }

  // Notes and given/when/then specifications, listed under the lanes with the frame they belong to.
  final names = <String, String>{
    for (final box in model.boxes) box.id: box.name,
  };
  final cards = StringBuffer();
  var cardsRight = 0.0;
  void card(String kind, String heading, String frame, List<String> rows) {
    final head = layoutLabel(
      '$heading · $frame${names.containsKey(frame) ? ' ${names[frame]!}' : ''}',
      false,
      measurer,
      small.toDouble(),
      4000,
      Style.Bold,
    );
    final w =
        math.max(head.width, widest(rows, small.toDouble(), 0)) + 2 * _boxPadX;
    final h = 2 * _boxPadY + head.height + rows.length * smallStep;
    final cy = bottom + (cards.isEmpty && bands.isEmpty ? 0 : _cardGap);
    cards.write(
      '<g class="pele-em-$kind" data-id="${escText(frame)}">'
      '<rect x="${num(left)}" y="${num(cy)}" width="${num(w)}" height="${num(h)}" fill="var(--_bg)" stroke="var(--_b)"$roundedAttr/>'
      '${labelSvg(head, left + _boxPadX + head.width / 2, cy + _boxPadY + head.height / 2, ' font-size="$small" font-weight="var(--_hw)"')}'
      '${_lines(rows, left + _boxPadX, cy + _boxPadY + head.height + smallStep / 2 + small * 0.35, smallStep, ' font-size="$small"')}'
      '</g>',
    );
    bottom = cy + h;
    cardsRight = math.max(cardsRight, w);
  }

  for (final note in model.notes) {
    card('note', 'Note', note.frame, _hardWrap(note.text, _noteColumns));
  }
  for (final spec in model.specifications) {
    final rows = <String>['Given  ${spec.given.join(', ')}'];
    if (spec.when.isNotEmpty) rows.add('When  ${spec.when.join(', ')}');
    rows.add('Then  ${spec.then.join(', ')}');
    card(
      'specification',
      'Given / When / Then',
      spec.frame,
      rows.expand((row) => _hardWrap(row, _noteColumns)).toList(),
    );
  }

  final width = math.max(
    math.max(bands.isNotEmpty ? laneWidth : 0.0, cardsRight),
    title.width,
  );
  final totalWidth = (width + 2 * pad).ceilToDouble();
  final totalHeight = (bottom + pad).ceilToDouble();
  final content =
      labelSvg(
        title,
        totalWidth / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      lanes.toString() +
      edges.toString() +
      nodes.toString() +
      cards.toString();

  return Rendered(
    svg: svgDocument(
      'eventmodeling',
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

const double _railGap = 8;
const double _cardMin = 120;
const double _arrowRoom = 20;

class _VPlaced {
  final double y;
  final double h;
  final double w;
  final int index;
  final double lane;

  const _VPlaced({
    required this.y,
    required this.h,
    required this.w,
    required this.index,
    required this.lane,
  });
}

Rendered _verticalEventModel(EventModelingModel model, RenderOptions options) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875);
  final mono = roundJs(size * 0.75);
  final pad = options.padding ?? 8;
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final room = math.max(160.0, (options.maxWidth ?? 320) - 2 * pad);
  // A relation that skips a card runs down a rail beside the cards. Relations into one card
  // share a rail; others whose runs overlap take the next rail out, so that no two follow the
  // same line.
  final order = <EmBox, int>{
    for (var index = 0; index < model.boxes.length; index++)
      model.boxes[index]: index,
  };
  final runs = <EmBox, List<int>>{};
  // A relation between neighbouring cards passes the lower card's lane heading.
  final passed = <EmBox>{};
  for (final relation in model.relations) {
    final s = order[relation.source];
    final t = order[relation.target];
    if (s == null || t == null || s == t) continue;
    if ((s - t).abs() < 2) {
      passed.add(model.boxes[math.max(s, t)]);
      continue;
    }
    final run = runs[relation.target];
    if (run != null) {
      run[0] = math.min(run[0], s);
      run[1] = math.max(run[1], s);
    } else {
      runs[relation.target] = <int>[math.min(s, t), math.max(s, t)];
    }
  }
  final railOf = <EmBox, int>{};
  final railEnds = <int>[];
  final sortedRuns = runs.entries.toList()
    ..sort((a, b) => a.value[0].compareTo(b.value[0]));
  for (final entry in sortedRuns) {
    final target = entry.key;
    final from = entry.value[0];
    final to = entry.value[1];
    var rail = railEnds.indexWhere((end) => end < from);
    if (rail < 0) {
      rail = railEnds.length;
      railEnds.add(to);
    } else {
      railEnds[rail] = to;
    }
    railOf[target] = rail;
  }
  final gutter = 24 + _railGap * math.max(0, railEnds.length - 1);
  // Rails are never shared to save room: past what the width allows, the drawing is wider.
  final cardWidth = math.max(_cardMin, room - gutter);
  final textRoom = cardWidth - 2 * _boxPadX;
  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    room,
    Style.Bold,
  );
  var y = pad + (title.height > 0 ? title.height + 12 : 0.0);
  var bottom = pad + title.height;
  var width = math.max(title.width, cardWidth + gutter);
  final nodes = StringBuffer();
  final edges = StringBuffer();
  final cards = StringBuffer();
  final placed = <EmBox, _VPlaced>{};
  Label text(String raw, double fontSize, [int style = 0]) =>
      literalLabel(decodeEntities(raw), measurer, fontSize, textRoom, style);
  for (var index = 0; index < model.boxes.length; index++) {
    final box = model.boxes[index];
    final laneRoom = passed.contains(box) ? textRoom - _arrowRoom : textRoom;
    final lane = breakLabel(
      layoutLabel(
        box.lane.label,
        false,
        measurer,
        small.toDouble(),
        laneRoom,
        Style.Bold,
      ),
      measurer,
      laneRoom,
    );
    final name = layoutLabel(
      box.name,
      false,
      measurer,
      small.toDouble(),
      textRoom - 36,
      Style.Bold,
    );
    final data = (box.data != null && box.data!.isNotEmpty)
        ? text(box.data!, mono.toDouble(), Style.Mono)
        : null;
    final w = math.max(
      math.max(cardWidth, lane.width + 2 * _boxPadX),
      math.max(
        name.width + 2 * _boxPadX + 36,
        (data?.width ?? 0) + 2 * _boxPadX,
      ),
    );
    final headH = lane.height + 12;
    final h = 2 * _boxPadY + name.height + (data != null ? data.height + 6 : 0);
    final series = _series[box.kind];
    final cy = y + headH;
    final frame =
        'x="${num(pad)}" y="${num(cy)}" width="${num(w)}" height="${num(h)}"';
    nodes.write(
      '<g class="pele-cluster pele-em-lane" data-id="${escText(box.lane.label)}">'
      '${leftLabelSvg(lane, pad + _boxPadX, y, ' class="pele-cluster-label" font-size="$small" font-weight="var(--_hw)" fill="var(--_m)"')}'
      '<g class="pele-node pele-em-${box.kind}${box.reset ? ' pele-em-reset' : ''}" data-id="${escText(box.id)}"><rect $frame fill="var(--_bg)" stroke="var(--_b)"$roundedAttr/>'
      '${series == null ? '' : '<rect $frame fill="${seriesColor(series)}" fill-opacity="0.22" stroke="${seriesColor(series)}"$roundedAttr/>'}'
      '${labelSvg(name, pad + _boxPadX + name.width / 2, cy + _boxPadY + name.height / 2, ' class="pele-label" font-size="$small" font-weight="var(--_hw)"')}'
      '<text class="pele-em-frame" x="${num(pad + w - _boxPadX)}" y="${num(cy + _boxPadY + small)}" text-anchor="end" font-size="$mono" fill="var(--_m)">${esc(box.id)}</text>'
      '${data != null ? _lines(data.lines.map((line) => line.map((span) => span.text).join()).toList(), pad + _boxPadX, cy + _boxPadY + name.height + 6 + data.lineHeight / 2 + mono * 0.35, data.lineHeight, ' class="pele-em-data" font-family="$fontMono" font-size="$mono"') : ''}'
      '</g></g>',
    );
    placed[box] = _VPlaced(y: cy, h: h, w: w, index: index, lane: lane.width);
    width = math.max(width, w + gutter);
    bottom = cy + h;
    y = bottom + 28;
  }
  for (final relation in model.relations) {
    final s = placed[relation.source];
    final t = placed[relation.target];
    if (s == null || t == null || identical(s, t)) continue;
    final down = t.y > s.y;
    final dir = down ? 1.0 : -1.0;
    final sy = down ? s.y + s.h : s.y;
    final ty = down ? t.y : t.y + t.h;
    String d;
    String head;
    if ((s.index - t.index).abs() == 1) {
      // The lower card's lane heading sits in the gap, and wraps to leave the arrow room beside it.
      final cx =
          pad +
          math.max(math.min(s.w, t.w) / 2, _boxPadX + (down ? t : s).lane + 16);
      d = 'M${num(cx)},${num(sy)}V${num(ty - dir * markerTrim('arrow_point'))}';
      head = marker('arrow_point', cx, ty, 0, dir, 'var(--_l)');
    } else {
      final rail =
          pad + width - gutter + 12 + _railGap * (railOf[relation.target] ?? 0);
      // A card can send one relation and receive another: they leave above and arrive below its middle.
      final from = s.y + s.h / 2 - 5;
      final to = t.y + t.h / 2 + 5;
      d = 'M${num(pad + s.w)},${num(from)}H${num(rail)}V${num(to)}H${num(pad + t.w + markerTrim('arrow_point'))}';
      head = marker('arrow_point', pad + t.w, to, -1, 0, 'var(--_l)');
    }
    edges.write(
      '<g class="pele-edge" data-id="${escText(relation.source.id)}-${escText(relation.target.id)}"><path d="$d" fill="none" stroke="var(--_l)"/>$head</g>',
    );
  }
  final names = <String, String>{
    for (final box in model.boxes) box.id: box.name,
  };
  void card(String kind, String heading, String frame, String raw) {
    final head = layoutLabel(
      '$heading · $frame${names.containsKey(frame) ? ' ${names[frame]!}' : ''}',
      false,
      measurer,
      small.toDouble(),
      textRoom,
      Style.Bold,
    );
    final body = text(raw, small.toDouble());
    final w = math.max(
      cardWidth,
      math.max(head.width + 2 * _boxPadX, body.width + 2 * _boxPadX),
    );
    final h = 2 * _boxPadY + head.height + body.height;
    cards.write(
      '<g class="pele-em-$kind" data-id="${escText(frame)}"><rect x="${num(pad)}" y="${num(y)}" width="${num(w)}" height="${num(h)}" fill="var(--_bg)" stroke="var(--_b)"$roundedAttr/>'
      '${labelSvg(head, pad + _boxPadX + head.width / 2, y + _boxPadY + head.height / 2, ' font-size="$small" font-weight="var(--_hw)"')}'
      '${_lines(body.lines.map((line) => line.map((span) => span.text).join()).toList(), pad + _boxPadX, y + _boxPadY + head.height + body.lineHeight / 2 + small * 0.35, body.lineHeight, ' font-size="$small"')}'
      '</g>',
    );
    bottom = y + h;
    y = bottom + _cardGap;
    width = math.max(width, w);
  }

  for (final note in model.notes) {
    card('note', 'Note', note.frame, note.text);
  }
  for (final spec in model.specifications) {
    final rows = <String>['Given  ${spec.given.join(', ')}'];
    if (spec.when.isNotEmpty) rows.add('When  ${spec.when.join(', ')}');
    rows.add('Then  ${spec.then.join(', ')}');
    card('specification', 'Given / When / Then', spec.frame, rows.join('\n'));
  }
  final totalWidth = (width + 2 * pad).ceilToDouble();
  final height = (bottom + pad).ceilToDouble();
  final content =
      labelSvg(
        title,
        totalWidth / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      edges.toString() +
      nodes.toString() +
      cards.toString();
  return Rendered(
    svg: svgDocument(
      'eventmodeling',
      totalWidth,
      height,
      size,
      options,
      model,
      content,
    ),
    width: totalWidth,
    height: height,
    links: <LinkInfo>[],
  );
}
