// Upstream: src/diagrams/journey/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit.dart';
import '../common/fit_width.dart';
import 'db.dart';

const double _padX = 10;
const double _padY = 8;
const double _minText = 124;
const double _maxText = 200;
const double _gap = 12;
const double _bandPad = 6;
const double _gutter = 24;
const double _level = 26;
const int _face = 11;
const int _dot = 5;
const double _dotStep = 13;
const double _legendGap = 20;

const String _eyes =
    '<circle cx="-3.6" cy="-2.8" r="1.3"/><circle cx="3.6" cy="-2.8" r="1.3"/>';
const Map<String, String> _mouths = <String, String>{
  'happy': 'M-5,2A6,6 0 0 0 5,2',
  'neutral': 'M-4.5,4.5H4.5',
  'sad': 'M-5,6.5A6,6 0 0 1 5,6.5',
};

String _faceSvg(double x, double y, String mood) {
  return '<g class="pele-face pele-face-$mood" transform="translate(${num(x)},${num(y)})">'
      '<circle r="$_face" fill="var(--_bg)" stroke="var(--_l)"/>'
      '<g fill="var(--_l)">$_eyes</g>'
      '<path d="${_mouths[mood]!}" fill="none" stroke="var(--_l)" stroke-linecap="round"/>'
      '</g>';
}

Rendered renderJourney(
  JourneyModel model,
  Config config,
  RenderOptions options,
) {
  return turnToFit(options, (down) => _draw(model, config, options, down));
}

class _LegendItem {
  final String name;
  final Label label;
  final double x;
  final double y;
  final double h;

  const _LegendItem({
    required this.name,
    required this.label,
    required this.x,
    required this.y,
    required this.h,
  });
}

class _Run {
  final int start;
  final int count;
  final Label? label;

  const _Run({required this.start, required this.count, required this.label});
}

Rendered _draw(
  JourneyModel model,
  Config config,
  RenderOptions options,
  bool down,
) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875);
  final smallD = small.toDouble();
  final tiny = roundJs(size * 0.75);
  final tinyD = tiny.toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  if (down) return _verticalJourney(model, options);
  final tasks = model.tasks;
  final n = tasks.length;

  // `Task: 5:` names an actor with no name; Mermaid gives it a dot and an empty legend row.
  final names = journeyActors(tasks).where((name) => name != '').toList();
  final actor = <String, int>{};
  for (var i = 0; i < names.length; i++) {
    actor[names[i]] = i;
  }

  // Cards widen, up to a point, for a word that would not fit; past that the word is cut.
  var textW = _minText;
  var labels = tasks
      .map((task) => plainLabel(task.task, measurer, smallD, textW))
      .toList();
  var widest = 0.0;
  for (final label in labels) {
    widest = math.max(widest, label.width);
  }
  if (widest > textW) {
    textW = math.min(widest.ceilToDouble(), _maxText);
    labels = tasks
        .map((task) => fitLabel(task.task, measurer, smallD, textW))
        .toList();
  }

  final cardW = textW + 2 * _padX;
  final pitch = cardW + _gap;
  final plotW = n > 0 ? n * pitch - _gap : 0.0;

  final lineH = roundJs(smallD * 1.5).toDouble();
  final limit = math.max<double>(plotW, 240);
  final legend = <_LegendItem>[];
  var legendW = 0.0;
  var legendH = 0.0;
  var lx = 0.0;
  for (final name in names) {
    final label = fitLabel(name, measurer, smallD, limit - 2 * _dot - 6);
    final w = 2 * _dot + 6 + label.width;
    if (lx > 0 && lx + w > limit) {
      lx = 0;
      legendH += 4;
    }
    final y = lx > 0 ? legend[legend.length - 1].y : legendH;
    final h = math.max(label.height, lineH);
    legend.add(_LegendItem(name: name, label: label, x: lx, y: y, h: h));
    lx += w;
    legendW = math.max(legendW, lx);
    legendH = math.max(legendH, y + h);
    lx += _legendGap;
  }

  final bodyW = n > 0 ? _gutter + plotW : 0.0;
  final title = fitLabel(
    model.title,
    measurer,
    size,
    math.max<double>(bodyW, 320),
    Style.Bold,
  );
  final titleH = title.height > 0 ? title.height + 16 : 0.0;
  final width = math.max<double>(
    math.max<double>(bodyW, title.width),
    n > 0 ? _gutter + legendW : 0.0,
  );
  final left = pad + (width - bodyW) / 2 + _gutter;
  final top = pad + titleH;

  // A band covers a run of tasks that share a section, as in Mermaid; a section with no tasks draws nothing.
  final runs = <_Run>[];
  var bandH = 0.0;
  for (var i = 0; i < n;) {
    var end = i + 1;
    while (end < n && tasks[end].section == tasks[i].section) {
      end++;
    }
    Label? label;
    if (tasks[i].section != '') {
      label = fitLabel(
        tasks[i].section,
        measurer,
        smallD,
        (end - i) * pitch - _gap - 2 * _padX,
        Style.Bold,
      );
      bandH = math.max(bandH, math.max(label.height, lineH) + 2 * _bandPad);
    }
    runs.add(_Run(start: i, count: end - i, label: label));
    i = end;
  }

  var textH = lineH;
  for (final label in labels) {
    textH = math.max(textH, label.height);
  }
  final dotsH = names.isNotEmpty ? 2 * _dot + 6.0 : 0.0;
  final cardH = textH + dotsH + 2 * _padY;
  final cardsY = top + (bandH > 0 ? bandH + _bandPad : 0);
  final chartTop = cardsY + cardH + _face + 16;
  final chartBottom = chartTop + 4 * _level;
  final right = left + plotW;

  final body = StringBuffer();
  var bottom = top;
  if (n > 0) {
    final grid = StringBuffer();
    final scale = StringBuffer();
    for (var score = 5; score >= 1; score--) {
      final y = chartTop + (5 - score) * _level;
      grid.write('M${num(left - 6)},${num(y)}H${num(right)}');
      scale.write(
        '<text x="${num(left - 12)}" y="${num(y + tinyD * 0.35)}">$score</text>',
      );
    }
    body
      ..write(
        '<path class="pele-grid" d="$grid" fill="none" stroke="var(--_a)"/>',
      )
      ..write(
        '<g class="pele-scale" font-size="$tiny" text-anchor="end" fill="var(--_m)">$scale</g>',
      );

    final line = StringBuffer();
    final stems = StringBuffer();
    final faces = StringBuffer();
    final cards = <String>[];
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final x = left + i * pitch;
      final cx = x + cardW / 2;
      final score = task.score;
      final level = score.isNaN
          ? 3.0
          : math.min<double>(5, math.max<double>(1, score));
      final y = chartTop + (5 - level) * _level;
      line.write('${i == 0 ? 'M' : 'L'}${num(cx)},${num(y)}');
      stems.write('M${num(cx)},${num(cardsY + cardH)}V${num(y - _face)}');
      faces.write(
        _faceSvg(
          cx,
          y,
          score > 3
              ? 'happy'
              : score < 3
              ? 'sad'
              : 'neutral',
        ),
      );

      final dots = StringBuffer();
      final people = task.people.where((name) => name != '').toList();
      final step = math.min<double>(
        _dotStep,
        (cardW - 2 * _padX - 2 * _dot) / math.max<int>(people.length - 1, 1),
      );
      for (var k = 0; k < people.length; k++) {
        final name = people[k];
        dots.write(
          '<circle class="pele-actor" cx="${num(cx + (k - (people.length - 1) / 2) * step)}" cy="${num(cardsY + cardH - _padY - _dot)}" r="$_dot" fill="${seriesColor(actor[name] ?? 0)}" stroke="var(--_s)">'
          '<title>${escText(name)}</title></circle>',
        );
      }
      cards.add(
        '<g class="pele-node pele-task" data-id="${escText(task.task.trim())}">'
        '<rect x="${num(x)}" y="${num(cardsY)}" width="${num(cardW)}" height="${num(cardH)}" fill="var(--_s)" stroke="var(--_b)"$roundedAttr/>'
        '${labelSvg(labels[i], cx, cardsY + _padY + textH / 2, ' font-size="$small"')}'
        '$dots'
        '</g>',
      );
    }
    body
      ..write(
        '<path class="pele-stems" d="$stems" fill="none" stroke="var(--_b)" stroke-dasharray="2 3"/>',
      )
      ..write(
        n > 1
            ? '<path class="pele-edge" d="$line" fill="none" stroke="var(--_l)" stroke-linejoin="round"/>'
            : '',
      )
      ..write(faces);

    for (final run in runs) {
      final members = cards.sublist(run.start, run.start + run.count).join();
      if (run.label == null) {
        body.write(members);
        continue;
      }
      final x = left + run.start * pitch;
      final w = run.count * pitch - _gap;
      body.write(
        '<g class="pele-cluster pele-section" data-id="${escText(tasks[run.start].section.trim())}">'
        '<rect x="${num(x)}" y="${num(top)}" width="${num(w)}" height="${num(bandH)}" fill="var(--_a)"$roundedAttr/>'
        '${labelSvg(run.label!, x + w / 2, top + bandH / 2, ' font-size="$small" font-weight="var(--_hw)"')}'
        '$members'
        '</g>',
      );
    }
    bottom = chartBottom + _face;

    if (legend.isNotEmpty) {
      final x0 = left + (plotW - legendW) / 2;
      final y0 = bottom + 16;
      final items = StringBuffer();
      for (final item in legend) {
        final cy = y0 + item.y + item.h / 2;
        items.write(
          '<g class="pele-legend-item" data-id="${escText(item.name)}">'
          '<circle cx="${num(x0 + item.x + _dot)}" cy="${num(cy)}" r="$_dot" fill="${seriesColor(actor[item.name] ?? 0)}"/>'
          '${labelSvg(item.label, x0 + item.x + 2 * _dot + 6 + item.label.width / 2, cy, '')}'
          '</g>',
        );
      }
      body.write('<g class="pele-legend" font-size="$small">$items</g>');
      bottom = y0 + legendH;
    }
  }

  final totalWidth = (width + 2 * pad).ceilToDouble();
  final totalHeight = (math.max(bottom, pad) + pad).ceilToDouble();
  final content =
      labelSvg(
        title,
        pad + width / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      body.toString();
  return Rendered(
    svg: svgDocument(
      'journey',
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

Rendered _verticalJourney(JourneyModel model, RenderOptions options) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.875);
  final smallD = small.toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final room = math.max<double>(140, (options.maxWidth ?? 320) - 2 * pad);
  final title = fitLabel(model.title, measurer, size, room, Style.Bold);
  final names = journeyActors(model.tasks).where((name) => name != '').toList();
  final actors = <String, int>{
    for (var i = 0; i < names.length; i++) names[i]: i,
  };
  var y = pad + (title.height != 0 ? title.height + 16 : 0);
  String? section;
  final body = StringBuffer();
  var width = title.width;
  for (var index = 0; index < model.tasks.length; index++) {
    final task = model.tasks[index];
    if (task.section != section) {
      section = task.section;
      final head = fitLabel(section, measurer, size, room - 16, Style.Bold);
      if (head.height != 0) {
        body.write(
          labelSvg(
            head,
            pad + 8 + head.width / 2,
            y + head.height / 2,
            ' class="pele-cluster-label" font-weight="var(--_hw)"',
          ),
        );
        width = math.max(width, head.width + 16);
        y += head.height + 8;
      }
    }
    final label = fitLabel(task.task, measurer, smallD, room - 72);
    final people = task.people
        .where((name) => name != '')
        .map(
          (name) =>
              (name: name, label: fitLabel(name, measurer, smallD, room - 44)),
        )
        .toList();
    final textH = math.max<double>(label.height, 42);
    var h = 2 * _padY + textH;
    for (final person in people) {
      h += math.max<double>(16, person.label.height) + 4;
    }
    final w = math.max(room, label.width + 72);
    body
      ..write(
        '<g class="pele-node pele-journey-step" data-id="$index"><rect x="${num(pad)}" y="${num(y)}" width="${num(w)}" height="${num(h)}" fill="var(--_s)" stroke="var(--_b)"$roundedAttr/>',
      )
      ..write(
        labelSvg(
          label,
          pad + _padX + label.width / 2,
          y + _padY + label.height / 2,
          ' class="pele-label"',
        ),
      );
    final cx = pad + w - 28;
    body.write(
      _faceSvg(
        cx,
        y + _padY + _face,
        task.score > 3
            ? 'happy'
            : task.score < 3
            ? 'sad'
            : 'neutral',
      ),
    );
    if (!task.score.isNaN) {
      body.write(
        '<text class="pele-journey-score" x="${num(cx)}" y="${num(y + _padY + 2 * _face + smallD)}" font-size="$small" text-anchor="middle">${num(math.min<double>(5, math.max<double>(1, task.score)))}</text>',
      );
    }
    var py = y + _padY + textH + 4;
    for (final person in people) {
      final ph = math.max<double>(16, person.label.height);
      body
        ..write(
          '<circle class="pele-actor" cx="${num(pad + 16)}" cy="${num(py + ph / 2)}" r="$_dot" fill="${seriesColor(actors[person.name]!)}"/>',
        )
        ..write(
          labelSvg(
            person.label,
            pad + 28 + person.label.width / 2,
            py + ph / 2,
            ' class="pele-journey-actor" font-size="$small"',
          ),
        );
      py += ph + 4;
    }
    body.write('</g>');
    y += h;
    if (index + 1 < model.tasks.length) {
      body.write(
        '<path class="pele-edge" d="M${num(pad + w / 2)},${num(y)}v16" fill="none" stroke="var(--_l)"/>',
      );
    }
    y += 16;
    width = math.max(width, w);
  }
  final totalWidth = (width + 2 * pad).ceilToDouble();
  final height =
      (math.max<double>(
                pad + title.height,
                y - (model.tasks.isNotEmpty ? 16 : 0),
              ) +
              pad)
          .ceilToDouble();
  final content =
      labelSvg(
        title,
        totalWidth / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      body.toString();
  return Rendered(
    svg: svgDocument(
      'journey',
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
