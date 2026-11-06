// Upstream: src/diagrams/gantt/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../../util/url.dart';
import '../common/fit_width.dart';
import 'axis.dart';
import 'dates.dart';
import 'db.dart';
import 'types.dart';

const double _width = 800;
const double _minPlot = 240;
const double _labelGap = 8;
final RegExp _reBreak = RegExp(r'<br\s*\/?>', caseSensitive: false);

double? _setting(Config config, String key, double min, double max) {
  final ganttCfg = config['gantt'];
  final value = ganttCfg is Map ? ganttCfg[key] : null;
  return value is double
      ? (value.isFinite ? math.min(max, math.max(min, value)) : null)
      : (value is int ? math.min(max, math.max(min, value.toDouble())) : null);
}

String? _text(Config config, String key) {
  final ganttCfg = config['gantt'];
  final value = ganttCfg is Map ? ganttCfg[key] : null;
  return value is String ? value : null;
}

bool _flag(Config config, String key) {
  final ganttCfg = config['gantt'];
  return ganttCfg is Map && ganttCfg[key] == true;
}

// A task label sits on one row, so only its first line is kept.
Label _oneLine(String raw, TextMeasurer measurer, double size) {
  final cleaned = raw.contains('<') ? raw.replaceAll(_reBreak, ' ') : raw;
  final label = layoutLabel(cleaned, false, measurer, size, 4000);
  if (label.lines.length <= 1) return label;
  return label.copyWith(
    lines: <List<Span>>[label.lines[0]],
    widths: <double>[label.widths[0]],
    width: label.widths[0],
    height: label.lineHeight,
  );
}

// Whether scheduling gave the task a start and an end. One that waits on a task that never resolves has neither.
bool _scheduled(GanttTask task) {
  return task.startTime != null && task.endTime != null;
}

// Mermaid's compact mode: within a section, a task goes on the first row that is free when it starts.
int _packRows(List<GanttTask> tasks, int offset, Map<GanttTask, int> rowOf) {
  final sorted = tasks.where(_scheduled).toList()
    ..sort((a, b) {
      final cmp =
          a.startTime!.millisecondsSinceEpoch -
          b.startTime!.millisecondsSinceEpoch;
      return cmp != 0 ? cmp : a.order - b.order;
    });
  final free = <int>[];
  for (final task in sorted) {
    final start = task.startTime!.millisecondsSinceEpoch;
    var row = 0;
    while (row < free.length && start < free[row]) {
      row++;
    }
    final end = task.endTime!.millisecondsSinceEpoch;
    if (row == free.length) {
      free.add(end);
    } else {
      free[row] = end;
    }
    rowOf[task] = offset + row;
  }
  var rows = free.length;
  for (final task in tasks) {
    if (!rowOf.containsKey(task)) {
      rowOf[task] = offset + rows++;
    }
  }
  return math.max(rows, 1);
}

class _Bar {
  final GanttTask task;
  final Label label;
  final int row;
  final double x0;
  final double x1;
  final double labelX;
  final bool inside;

  const _Bar({
    required this.task,
    required this.label,
    required this.row,
    required this.x0,
    required this.x1,
    required this.labelX,
    required this.inside,
  });
}

Rendered renderGantt(GanttDb model, Config config, RenderOptions options) {
  final size = options.fontSize ?? 16;
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;
  final now = clock(options.now);

  final labelSize =
      _setting(config, 'fontSize', 4, 72) ?? roundJs(size * 0.8125).toDouble();
  final sectionSize = _setting(config, 'sectionFontSize', 4, 72) ?? labelSize;
  final tickSize = roundJs(size * 0.75);
  final tickSizeD = tickSize.toDouble();
  final barHeight =
      _setting(config, 'barHeight', 4, 400) ??
      roundJs(labelSize * 1.85).toDouble();
  final barGap =
      _setting(config, 'barGap', 0, 400) ?? roundJs(barHeight / 4).toDouble();
  final rowHeight = barHeight + barGap;
  final sectionStyles = roundJs(
    _setting(config, 'numberSectionStyles', 1, 1000) ?? 4,
  );
  final compact = model.displayMode == 'compact';
  final topAxis = model.topAxis || _flag(config, 'topAxis');

  final tasks = model.getTasks(now);
  final rowTasks = tasks.where((task) => !task.vert).toList();
  final verts = tasks.where((task) => task.vert && _scheduled(task)).toList();

  final categories = <String, int>{};
  for (final task in rowTasks) {
    if (!categories.containsKey(task.section)) {
      categories[task.section] = categories.length;
    }
  }

  final rowOf = <GanttTask, int>{};
  final rowSection = <String>[];
  if (compact) {
    final groups = <String, List<GanttTask>>{};
    for (final task in rowTasks) {
      final group = groups[task.section];
      if (group != null) {
        group.add(task);
      } else {
        groups[task.section] = <GanttTask>[task];
      }
    }
    for (final entry in groups.entries) {
      final section = entry.key;
      final group = entry.value;
      final rows = _packRows(group, rowSection.length, rowOf);
      for (var i = 0; i < rows; i++) {
        rowSection.add(section);
      }
    }
  } else {
    for (final task in rowTasks) {
      rowOf[task] = rowSection.length;
      rowSection.add(task.section);
    }
  }
  final rowCount = rowSection.length;

  var start = double.infinity;
  var stop = double.negativeInfinity;
  for (final task in tasks) {
    if (!_scheduled(task)) continue;
    start = math.min(start, task.startTime!.millisecondsSinceEpoch.toDouble());
    stop = math.max(stop, task.endTime!.millisecondsSinceEpoch.toDouble());
  }
  final hasPlot = start <= stop;

  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    4000,
    Style.Bold,
  );
  final titleHeight = title.height > 0 ? title.height + 16 : 0.0;

  if (!hasPlot) {
    final width = (math.max<double>(title.width, 1) + 2 * pad).ceilToDouble();
    final height = (math.max<double>(title.height, 1) + 2 * pad).ceilToDouble();
    final content = labelSvg(
      title,
      width / 2,
      pad + title.height / 2,
      ' class="pele-title" font-weight="var(--_tw)"',
    );
    return Rendered(
      svg: svgDocument('gantt', width, height, size, options, model, content),
      width: width,
      height: height,
      links: <LinkInfo>[],
    );
  }

  final sectionLabels = <String, Label>{};
  var sectionWidth = 0.0;
  for (final section in categories.keys) {
    final label = layoutLabel(section, false, measurer, sectionSize, 180);
    sectionLabels[section] = label;
    sectionWidth = math.max(sectionWidth, label.width);
  }

  final axisFormat = model.axisFormat.isNotEmpty
      ? model.axisFormat
      : (model.dateFormat == 'D'
            ? '%d'
            : (_text(config, 'axisFormat') ?? '%Y-%m-%d'));
  String tickLabel(double t) =>
      timeFormat(axisFormat, DateTime.fromMillisecondsSinceEpoch(t.round()));
  final sampleWidth = math.max(
    measurer.width(tickLabel(start), tickSizeD, 0),
    measurer.width(tickLabel(stop), tickSizeD, 0),
  );

  final left =
      pad +
      (_setting(config, 'leftPadding', 0, 2000) ??
          math.max<double>(
            sectionWidth > 0 ? sectionWidth + 24 : 0,
            sampleWidth / 2,
          ));
  final rightPadding =
      _setting(config, 'rightPadding', 0, 2000) ??
      math.max<double>(16, sampleWidth / 2);
  final target = capWidth(
    options,
    _setting(config, 'useWidth', 100, 20000) ?? _width,
    280,
  );
  final plotWidth = math.max(_minPlot, target - left - rightPadding - pad);
  final right = left + plotWidth;
  final scale = stop > start ? plotWidth / (stop - start) : 0.0;
  double x(double t) =>
      scale == 0 ? left + plotWidth / 2 : left + (t - start) * scale;

  final tickHeight = roundJs(tickSizeD * 1.75).toDouble();
  final topPadding = _setting(config, 'topPadding', 0, 2000);
  final gridStart = _setting(config, 'gridLineStartPadding', 0, 2000);
  final headHeight = pad + titleHeight + (topAxis ? tickHeight : 0);
  final plotTop = math.max(headHeight, topPadding ?? 0);
  // Mermaid starts its grid lines above the first row by the difference between these two settings.
  // Here that only uses room a larger `topPadding` leaves free.
  final gridLead = (topPadding != null && gridStart != null)
      ? math.max<double>(
          0,
          math.min(topPadding - gridStart, plotTop - headHeight),
        )
      : 0.0;
  final plotHeight = math.max(rowCount, 1) * rowHeight;
  final plotBottom = plotTop + plotHeight;

  // Bars and where their labels go: inside when they fit, otherwise beside the bar on the side with room.
  final bars = <_Bar>[];
  var extent = right + rightPadding;
  for (final task in rowTasks) {
    final label = _oneLine(task.task, measurer, labelSize);
    final row = rowOf[task]!;
    if (!_scheduled(task)) {
      final labelX = left + _labelGap + label.width / 2;
      extent = math.max(extent, labelX + label.width / 2);
      bars.add(
        _Bar(
          task: task,
          label: label,
          row: row,
          x0: double.nan,
          x1: double.nan,
          labelX: labelX,
          inside: false,
        ),
      );
      continue;
    }
    var x0 = x(task.startTime!.millisecondsSinceEpoch.toDouble());
    final renderOrEnd = (task.renderEndTime ?? task.endTime!)
        .millisecondsSinceEpoch
        .toDouble();
    var x1 = math.max(x(renderOrEnd), x0 + (task.milestone ? 0 : 2));
    if (task.milestone) {
      final mid =
          x0 + (x(task.endTime!.millisecondsSinceEpoch.toDouble()) - x0) / 2;
      x0 = mid - barHeight / 2;
      x1 = mid + barHeight / 2;
    }
    final inside = !task.milestone && label.width + 2 * _labelGap <= x1 - x0;
    var labelX = (x0 + x1) / 2;
    if (!inside) {
      final fitsRight = x1 + _labelGap + label.width <= right + rightPadding;
      final fitsLeft = x0 - _labelGap - label.width >= left;
      labelX = (fitsRight || !fitsLeft)
          ? x1 + _labelGap + label.width / 2
          : x0 - _labelGap - label.width / 2;
      extent = math.max(extent, labelX + label.width / 2);
    }
    bars.add(
      _Bar(
        task: task,
        label: label,
        row: row,
        x0: x0,
        x1: x1,
        labelX: labelX,
        inside: inside,
      ),
    );
  }

  final interval =
      (model.tickInterval != null && model.tickInterval!.isNotEmpty)
      ? model.tickInterval!
      : (_text(config, 'tickInterval') ?? '');
  final weekday = model.weekday ?? _text(config, 'weekday') ?? 'sunday';
  final count = math.max(
    2,
    math.min(10, (plotWidth / (sampleWidth + 24)).floor()),
  );
  final ticks =
      intervalTicks(interval, weekday, start, stop, (plotWidth / 3).ceil()) ??
      autoTicks(start, stop, count);

  final grid = StringBuffer();
  final axisBottom = StringBuffer();
  final axisTop = StringBuffer();
  var lastRight = double.negativeInfinity;
  var lastLabel = '';
  final bottomY = plotBottom + tickHeight / 2 + 2;
  final topY = plotTop - gridLead - tickHeight / 2 - 2;
  for (final t in ticks) {
    final tx = x(t);
    grid.write('M${num(tx)},${num(plotTop - gridLead)}V${num(plotBottom)}');
    final label = tickLabel(t);
    final width = measurer.width(label, tickSizeD, 0);
    // A label is skipped when it would run into the one before it or only repeat it; its grid line stays.
    if (tx - width / 2 < lastRight + 8 || label == lastLabel) continue;
    lastRight = tx + width / 2;
    lastLabel = label;
    extent = math.max(extent, lastRight);
    final body = 'text-anchor="middle">${esc(label)}</text>';
    axisBottom.write(
      '<text x="${num(tx)}" y="${num(bottomY + tickSizeD * 0.35)}" $body',
    );
    if (topAxis) {
      axisTop.write(
        '<text x="${num(tx)}" y="${num(topY + tickSizeD * 0.35)}" $body',
      );
    }
  }

  // Vertical markers take no row. Their labels go under the axis, on as many lines as it takes to keep them apart.
  final vertLines = StringBuffer();
  final vertLabels = StringBuffer();
  final vertEnds = <double>[];
  final vertTop = plotBottom + tickHeight + 4;
  final vertLine = roundJs(labelSize * 1.5).toDouble();
  final sortedVerts = verts.toList()
    ..sort(
      (a, b) =>
          a.startTime!.millisecondsSinceEpoch -
          b.startTime!.millisecondsSinceEpoch,
    );
  for (final task in sortedVerts) {
    final vx = x(task.startTime!.millisecondsSinceEpoch.toDouble());
    final label = _oneLine(task.task, measurer, labelSize);
    final cx = math.max(pad + label.width / 2, vx);
    var line = 0;
    while (line < vertEnds.length &&
        cx - label.width / 2 < vertEnds[line] + 8) {
      line++;
    }
    final endX = cx + label.width / 2;
    if (line == vertEnds.length) {
      vertEnds.add(endX);
    } else {
      vertEnds[line] = endX;
    }
    extent = math.max(extent, vertEnds[line]);
    vertLines.write(
      '<path class="pele-vert" data-id="${escText(task.id)}" d="M${num(vx)},${num(plotTop - gridLead)}V${num(plotBottom)}"/>',
    );
    vertLabels.write(
      labelSvg(
        label,
        cx,
        vertTop + line * vertLine + vertLine / 2,
        ' class="pele-vert-label" data-id="${escText(task.id)}"',
      ),
    );
  }

  final width = (math.max(extent, pad + title.width) + pad).ceilToDouble();
  final height =
      (plotBottom +
              tickHeight +
              (vertEnds.isNotEmpty ? 4 + vertEnds.length * vertLine : 0) +
              pad)
          .ceilToDouble();

  // Section bands, one per run of rows that share a section, shaded on alternate sections.
  final bands = StringBuffer();
  final sectionOut = StringBuffer();
  for (var row = 0; row < rowCount;) {
    final section = rowSection[row];
    var end = row + 1;
    while (end < rowCount && rowSection[end] == section) {
      end++;
    }
    final index = categories[section]! % sectionStyles;
    final y = plotTop + row * rowHeight;
    final h = (end - row) * rowHeight;
    if (categories.length > 1 || section.isNotEmpty) {
      bands.write(
        '<rect class="pele-section pele-section-$index" x="0" y="${num(y)}" width="${num(width)}" height="${num(h)}" fill="${index % 2 == 0 ? 'var(--_s)' : 'none'}"/>',
      );
    }
    final label = sectionLabels[section]!;
    sectionOut.write(
      labelSvg(
        label,
        pad + 8 + label.width / 2,
        y + h / 2,
        ' class="pele-section-label" data-id="${escText(section)}"',
        options.icons,
      ),
    );
    row = end;
  }

  // Excluded days, as Mermaid marks them: a day at a time from the first task's start, and not at all
  // when the chart spans more than five years.
  final excluded = StringBuffer();
  if (model.excludes.isNotEmpty || model.includes.isNotEmpty) {
    final startDt = DateTime.fromMillisecondsSinceEpoch(start.round());
    final sixYearsLater = add(startDt, 6, 'y');
    if (sixYearsLater != null && sixYearsLater.millisecondsSinceEpoch > stop) {
      DateTime? from;
      DateTime? to;
      void flush() {
        if (from == null || to == null) return;
        final fw = DateTime.fromMillisecondsSinceEpoch(
          from!.millisecondsSinceEpoch + from!.timeZoneOffset.inMilliseconds,
          isUtc: true,
        );
        final tw = DateTime.fromMillisecondsSinceEpoch(
          to!.millisecondsSinceEpoch + to!.timeZoneOffset.inMilliseconds,
          isUtc: true,
        );
        final dayStart = DateTime(fw.year, fw.month, fw.day, 0, 0, 0, 0);
        final dayEnd = DateTime(tw.year, tw.month, tw.day, 23, 59, 59, 999);
        final ex0 = math.max(
          left,
          x(dayStart.millisecondsSinceEpoch.toDouble()),
        );
        final ex1 = math.min(
          right,
          x(dayEnd.millisecondsSinceEpoch.toDouble()),
        );
        if (ex1 > ex0) {
          excluded.write(
            '<rect x="${num(ex0)}" y="${num(plotTop)}" width="${num(ex1 - ex0)}" height="${num(plotHeight)}"/>',
          );
        }
        from = null;
        to = null;
      }

      for (
        var day = startDt;
        day.millisecondsSinceEpoch <= stop;
        day = addDays(day, 1)
      ) {
        if (model.isInvalidDate(day)) {
          from ??= day;
          to = day;
        } else {
          flush();
        }
      }
      flush();
    }
  }

  final links = <LinkInfo>[];
  final tasksOut = StringBuffer();
  for (final bar in bars) {
    final task = bar.task;
    final cy = plotTop + bar.row * rowHeight + rowHeight / 2;
    final state = task.active
        ? 'active'
        : task.done
        ? 'done'
        : '';
    var classes = 'pele-task';
    if (state.isNotEmpty) classes += ' pele-$state';
    if (task.crit) classes += ' pele-crit';
    if (task.milestone) classes += ' pele-milestone';
    if (task.classes.contains('clickable')) classes += ' pele-clickable';

    var shape = '';
    var textFill = '';
    if (bar.x0.isNaN) {
      classes += ' pele-unscheduled';
      textFill = ' fill="var(--_m)"';
    } else {
      // A critical task takes the critical color in place of the accent. Done, it keeps the fill
      // of finished work and only its border is in that color.
      final color = task.crit ? critical : 'var(--_c)';
      final paint = state == 'done'
          ? 'fill="var(--_a)"'
          : state == 'active'
          ? 'fill="$color" fill-opacity="0.25"'
          : 'fill="$color"';
      final stroke =
          'stroke="${state == 'done' && !task.crit ? 'var(--_b)' : color}"';
      if (task.milestone) {
        final cx = (bar.x0 + bar.x1) / 2;
        final r = barHeight / 2;
        shape =
            '<path d="M${num(cx)},${num(cy - r)}L${num(cx + r)},${num(cy)}L${num(cx)},${num(cy + r)}L${num(cx - r)},${num(cy)}Z" $paint $stroke stroke-linejoin="round"/>';
      } else {
        shape =
            '<rect x="${num(bar.x0)}" y="${num(cy - barHeight / 2)}" width="${num(bar.x1 - bar.x0)}" height="${num(barHeight)}" $paint $stroke$roundedAttr/>';
      }
      if (bar.inside) {
        textFill = state.isEmpty ? ' fill="var(--_bg)"' : '';
      } else if (state == 'done') {
        textFill = ' fill="var(--_m)"';
      }
    }

    var body =
        shape +
        labelSvg(bar.label, bar.labelX, cy, ' class="pele-label"$textFill');
    final url = model.links[task.id];
    if (url != null) body = linked(body, url, task.id, links, options);
    tasksOut.write(
      '<g class="$classes" data-id="${escText(task.id)}">$body</g>',
    );
  }

  var today = '';
  if (model.todayMarker != 'off' &&
      now >= start &&
      now <= stop &&
      stop > start) {
    final tx = x(now);
    final top = plotTop - gridLead;
    final style = model.todayMarker.isNotEmpty
        ? resolveStyle(model.todayMarker.split(',')).line
        : '';
    today =
        '<g class="pele-today"><path d="M${num(tx)},${num(top)}V${num(plotBottom)}" fill="none" stroke="var(--_c)" stroke-width="2"$style/>'
        '${style.isNotEmpty ? '' : '<path d="M${num(tx - 4)},${num(top - 5)}H${num(tx + 4)}L${num(tx)},${num(top + 1)}Z" fill="var(--_c)"/>'}'
        '</g>';
  }

  final axisLine =
      'M${num(left)},${num(plotBottom)}H${num(right)}${topAxis ? 'M${num(left)},${num(plotTop - gridLead)}H${num(right)}' : ''}';
  final bandsStr = bands.toString();
  final excludedStr = excluded.toString();
  final vertLinesStr = vertLines.toString();
  final vertLabelsStr = vertLabels.toString();
  final content =
      labelSvg(
        title,
        width / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      (bandsStr.isNotEmpty ? '<g class="pele-sections">$bandsStr</g>' : '') +
      (excludedStr.isNotEmpty
          ? '<g class="pele-excluded" fill="var(--_a)">$excludedStr</g>'
          : '') +
      '<g class="pele-grid" fill="none"><path d="$grid" stroke="var(--_b)" stroke-dasharray="1 3"/><path d="$axisLine" stroke="var(--_b)"/></g>' +
      (vertLinesStr.isNotEmpty
          ? '<g class="pele-verts" fill="none" stroke="var(--_l)" stroke-width="1.5" stroke-dasharray="4 3">$vertLinesStr</g>'
          : '') +
      today +
      '<g class="pele-tasks" font-size="${num(labelSize)}">$tasksOut</g>' +
      '<g class="pele-section-labels" font-size="${num(sectionSize)}">$sectionOut</g>' +
      '<g class="pele-axis" font-size="$tickSize" fill="var(--_m)">$axisBottom$axisTop</g>' +
      (vertLabelsStr.isNotEmpty
          ? '<g class="pele-vert-labels" font-size="${num(labelSize)}">$vertLabelsStr</g>'
          : '');

  return Rendered(
    svg: svgDocument('gantt', width, height, size, options, model, content),
    width: width,
    height: height,
    links: links,
  );
}
