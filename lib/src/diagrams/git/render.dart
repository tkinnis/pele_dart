// Upstream: src/diagrams/git/render.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../../preprocess.dart';
import '../../svg/builder.dart';
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

const double _dot = 7;
const double _step = 44;
const double _lane = 44;
// Shorter than a step, so a curve between lanes never runs through a commit on a lane it crosses.
const double _curve = 36;
const double _gap = 8;
const double _labelGap = 20;
const double _tail = 20;
const double _notch = 7;
const double _tagGap = 6;
const double _half = math.sqrt1_2;
const List<String> _classes = <String>[
  'normal',
  'reverse',
  'highlight',
  'merge',
  'cherry-pick',
];

class _View {
  _View({
    required this.commit,
    required this.index,
    required this.lane,
    required this.m,
    required this.label,
    required this.tags,
  });

  final GitCommit commit;
  final int index;
  final int lane;
  double m;
  final Label? label;
  final List<Label> tags;
}

bool _flag(Config config, String key, bool fallback) {
  final git = config['gitGraph'];
  final value = git is Map ? git[key] : null;
  return value is bool ? value : fallback;
}

double _tagWidth(Label tag) {
  return _notch + 4 + tag.width + 6;
}

String _symbol(int type, double x, double y, String color) {
  final at = 'cx="${num(x)}" cy="${num(y)}"';
  if (type == CommitType.highlight) {
    return '<rect x="${num(x - _dot - 1)}" y="${num(y - _dot - 1)}" width="${num(2 * _dot + 2)}" height="${num(2 * _dot + 2)}" rx="2" fill="$color"/>';
  }
  if (type == CommitType.merge) {
    return '<circle $at r="${num(_dot - 1)}" fill="var(--_bg)" stroke="$color" stroke-width="2"/><circle $at r="2.5" fill="$color"/>';
  }
  final dot = '<circle $at r="${num(_dot)}" fill="$color"/>';
  if (type == CommitType.reverse) {
    return '$dot'
        '<path d="M${num(x - 3)},${num(y - 3)}l6,6M${num(x - 3)},${num(y + 3)}l6,-6" fill="none" stroke="var(--_bg)" stroke-width="1.5" stroke-linecap="round"/>';
  }
  if (type == CommitType.cherryPick) {
    return '$dot'
        '<path d="M${num(x - 2.6)},${num(y + 1)}L${num(x + 0.8)},${num(y - 4.2)}L${num(x + 2.6)},${num(y + 1)}" fill="none" stroke="var(--_bg)" stroke-linejoin="round"/>'
        '<circle cx="${num(x - 2.6)}" cy="${num(y + 2.2)}" r="1.8" fill="var(--_bg)"/>'
        '<circle cx="${num(x + 2.6)}" cy="${num(y + 2.2)}" r="1.8" fill="var(--_bg)"/>';
  }
  return dot;
}

Rendered renderGit(GitModel model, Config config, RenderOptions options) {
  if (model.direction != 'LR') {
    return _draw(model, config, options, model.direction);
  }
  return turnToFit(
    options,
    (down) => _draw(model, config, options, down ? 'TB' : 'LR'),
  );
}

Rendered _draw(
  GitModel model,
  Config config,
  RenderOptions options,
  GitDirection direction,
) {
  final size = options.fontSize ?? 16;
  final small = roundJs(size * 0.75).toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;

  final showBranches = _flag(config, 'showBranches', true);
  final showCommitLabel = _flag(config, 'showCommitLabel', true);
  final rotate = _flag(config, 'rotateCommitLabel', true);
  final parallel = _flag(config, 'parallelCommits', false);
  final vertical = direction != 'LR';
  final flip = direction == 'BT';

  final laneOf = <String, int>{};
  for (var i = 0; i < model.lanes.length; i++) {
    laneOf[model.lanes[i]] = i;
  }
  final laneCount = model.lanes.length;
  final medium = roundJs(size * 0.875).toDouble();
  // Mermaid writes branch names, tags, and commit ids as plain text, so tags in them show as written.
  final names = model.lanes
      .map(
        (name) => plainLabel(showBranches ? name : '', measurer, medium, 4000),
      )
      .toList();

  final views = <_View>[];
  final byId = <String, _View>{};
  final sortedCommits = model.commits.values.toList()
    ..sort((a, b) => a.seq.compareTo(b.seq));
  for (final commit in sortedCommits) {
    final labelled =
        showCommitLabel &&
        commit.type != CommitType.cherryPick &&
        (commit.type != CommitType.merge || commit.customId == true);
    final tags = <Label>[];
    for (final tag in commit.tags) {
      final label = plainLabel(tag, measurer, small, 4000);
      if (label.lines.isNotEmpty) tags.add(label);
    }
    final view = _View(
      commit: commit,
      index: views.length,
      lane: laneOf[commit.branch] ?? 0,
      m: 0,
      label: labelled ? plainLabel(commit.id, measurer, small, 4000) : null,
      tags: tags,
    );
    views.add(view);
    byId[commit.id] = view;
  }

  // Room each commit needs: along the main axis on either side, and across it towards the
  // previous lane (`lo`) and the next one (`hi`). Tags sit on one side of a lane and ids on the other.
  final half = Float64List(views.length);
  final tagHalf = Float64List(views.length);
  final lo = Float64List(laneCount)..fillRange(0, laneCount, _dot);
  final hi = Float64List(laneCount)..fillRange(0, laneCount, _dot);
  for (var k = 0; k < views.length; k++) {
    final view = views[k];
    final label = view.label;
    final tags = view.tags;
    var tagsMain = 0.0;
    var tagsCross = 0.0;
    for (final tag in tags) {
      final w = _tagWidth(tag);
      if (vertical) {
        tagsMain = math.max(tagsMain, tag.height);
        tagsCross += w + 4;
      } else {
        tagsMain = math.max(tagsMain, w);
        tagsCross += tag.height + 3;
      }
    }
    var labelMain = 0.0;
    var labelCross = 0.0;
    if (label != null && label.lines.isNotEmpty) {
      if (rotate) {
        labelCross = 3 + _half * (label.width + label.height);
      } else {
        labelMain = vertical ? label.height : label.width;
        labelCross = 6 + (vertical ? label.width : label.height);
      }
    }
    half[k] = math.max(_dot, math.max(tagsMain / 2, labelMain / 2));
    tagHalf[k] = tagsMain / 2;
    final tagSide = _dot + (tags.isNotEmpty ? _tagGap + tagsCross : 0);
    final labelSide = _dot + labelCross;
    final lane = view.lane;
    lo[lane] = math.max(lo[lane], vertical ? labelSide : tagSide);
    hi[lane] = math.max(hi[lane], vertical ? tagSide : labelSide);
  }

  // In a left-to-right graph the tags stand over their commit. A connector that comes down from
  // a lane above joins the commit's lane this far before the commit, clear of the tags, and the
  // commit is placed far enough along to leave room for that.
  final lead = Float64List(views.length);
  if (!vertical) {
    for (var k = 0; k < views.length; k++) {
      final view = views[k];
      if (tagHalf[k] == 0) continue;
      for (final id in view.commit.parents) {
        final parent = byId[id];
        if (parent != null && parent.lane < view.lane) {
          lead[k] = tagHalf[k] + 4;
        }
      }
    }
  }
  double space(int p, int k) => math.max(
    _step,
    math.max(
      half[p] + half[k] + _gap,
      lead[k] > 0 ? half[p] + _curve + lead[k] : 0.0,
    ),
  );

  for (var k = 0; k < views.length; k++) {
    final view = views[k];
    if (!parallel) {
      view.m = k == 0 ? 0 : views[k - 1].m + space(k - 1, k);
      continue;
    }
    // Mermaid's `parallelCommits`: a commit sits one step after its furthest parent, so branches
    // that grow side by side share positions instead of taking turns.
    var m = 0.0;
    for (final id in view.commit.parents) {
      final parent = byId[id];
      if (parent == null || parent.index >= k) continue;
      m = math.max(m, parent.m + space(parent.index, k));
    }
    view.m = m;
  }
  var end = 0.0;
  for (final view in views) {
    end = math.max(end, view.m);
  }

  final cross = Float64List(laneCount);
  for (var i = 0; i < laneCount; i++) {
    final name = names[i];
    final reach = name.lines.isEmpty
        ? 0.0
        : (vertical ? name.width / 2 + 8 : name.height / 2 + 2);
    lo[i] = math.max(lo[i], reach);
    hi[i] = math.max(hi[i], reach);
    if (i > 0) {
      cross[i] = cross[i - 1] + math.max(_lane, hi[i - 1] + lo[i] + _gap);
    }
  }

  double px(double m, double c) => vertical ? c : m;
  double py(double m, double c) => vertical ? (flip ? -m : m) : c;
  String point(double m, double c) => '${num(px(m, c))},${num(py(m, c))}';

  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  void grow(double x0, double y0, double x1, double y1) {
    if (x0 < minX) minX = x0;
    if (y0 < minY) minY = y0;
    if (x1 > maxX) maxX = x1;
    if (y1 > maxY) maxY = y1;
  }

  final branchesBuf = StringBuffer();
  if (showBranches) {
    for (var i = 0; i < laneCount; i++) {
      final name = names[i];
      final color = seriesColor(i);
      final c = cross[i];
      final w = name.width + 16;
      final h = name.height + 4;
      final from = name.lines.isEmpty
          ? -_labelGap
          : -_labelGap - (vertical ? h : w);
      final cx = px(from + (vertical ? h : w) / 2, c);
      final cy = py(from + (vertical ? h : w) / 2, c);
      grow(
        px(-_labelGap, c),
        py(-_labelGap, c),
        px(-_labelGap, c),
        py(-_labelGap, c),
      );
      grow(
        px(end + _tail, c),
        py(end + _tail, c),
        px(end + _tail, c),
        py(end + _tail, c),
      );
      branchesBuf
        ..write('<g class="pele-branch" data-id="${escText(model.lanes[i])}">')
        ..write(
          '<path class="pele-lane" d="M${point(-_labelGap, c)}L${point(end + _tail, c)}" stroke="$color" stroke-dasharray="2 4"/>',
        );
      if (name.lines.isNotEmpty) {
        grow(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2);
        final ink = seriesInkFill(i);
        branchesBuf
          ..write(
            '<rect x="${num(cx - w / 2)}" y="${num(cy - h / 2)}" width="${num(w)}" height="${num(h)}" fill="$color"$roundedAttr/>',
          )
          ..write(
            labelSvg(
              name,
              cx,
              cy,
              ' class="pele-label"${ink.isNotEmpty ? ink : ' fill="var(--_bg)"'}',
            ),
          );
      }
      branchesBuf.write('</g>');
    }
  }

  // Positions of the commits on each lane, to tell whether a connector may run along it.
  final taken = List<List<double>>.generate(laneCount, (_) => <double>[]);
  for (final view in views) {
    taken[view.lane].add(view.m);
  }
  if (parallel) {
    for (final list in taken) {
      list.sort((a, b) => a.compareTo(b));
    }
  }
  bool busy(int lane, double from, double to) {
    final list = taken[lane];
    var low = 0;
    var high = list.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (list[mid] <= from) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low < list.length && list[low] < to;
  }

  final curvesBuf = StringBuffer();
  final linesBuf = StringBuffer();
  for (final view in views) {
    final commit = view.commit;
    final c2 = cross[view.lane];
    final m2 = view.m;
    for (var j = 0; j < commit.parents.length; j++) {
      final parent = byId[commit.parents[j]];
      if (parent == null || identical(parent, view)) continue;
      final c1 = cross[parent.lane];
      final m1 = parent.m;
      if (parent.lane == view.lane) {
        linesBuf.write(
          '<path class="pele-edge" d="M${point(m1, c1)}L${point(m2, c2)}" stroke="${seriesColor(view.lane)}"/>',
        );
        continue;
      }
      final merged = j > 0 && commit.type == CommitType.merge;
      final picked = j > 0 && !merged;
      final d = StringBuffer('M${point(m1, c1)}');
      if (m2 <= m1) {
        final mid = (m1 + m2) / 2;
        d.write('C${point(mid, c1)} ${point(mid, c2)} ${point(m2, c2)}');
      } else if (!merged && !busy(view.lane, m1, m2)) {
        // Leaves the parent at once and runs along the child's lane.
        final s = math.min(_curve, m2 - m1);
        d.write(
          'C${point(m1 + s / 2, c1)} ${point(m1 + s / 2, c2)} ${point(m1 + s, c2)}L${point(m2, c2)}',
        );
      } else {
        // Turns in just before the child, or before its tags when it comes from their side.
        final to = parent.lane < view.lane && m2 - lead[view.index] > m1
            ? m2 - lead[view.index]
            : m2;
        var s = math.min(_curve, to - m1);
        var along = c1;
        if (!merged || busy(parent.lane, m1, m2)) {
          // Neither lane is free to run along. Between two lanes, past the ids of one and before
          // the tags of the next, a strip stays empty, and the connector takes that.
          along = c1 > c2
              ? c2 + hi[view.lane] + _gap / 2
              : c2 - lo[view.lane] - _gap / 2;
          s = math.min(_curve, (to - m1) / 2);
          d.write(
            'C${point(m1 + s / 2, c1)} ${point(m1 + s / 2, along)} ${point(m1 + s, along)}',
          );
        }
        d.write(
          'L${point(to - s, along)}C${point(to - s / 2, along)} ${point(to - s / 2, c2)} ${point(to, c2)}',
        );
        if (to < m2) d.write('L${point(m2, c2)}');
      }
      curvesBuf.write(
        '<path class="pele-edge${merged
            ? ' pele-edge-merge'
            : picked
            ? ' pele-edge-cherry-pick'
            : ''}" d="$d" '
        'stroke="${seriesColor(merged ? parent.lane : view.lane)}"${picked ? ' stroke-dasharray="4 3"' : ''}/>',
      );
    }
  }

  final commitsBuf = StringBuffer();
  for (final view in views) {
    final commit = view.commit;
    final label = view.label;
    final tags = view.tags;
    final x = px(view.m, cross[view.lane]);
    final y = py(view.m, cross[view.lane]);
    final type = commit.customType ?? commit.type;
    grow(x - _dot - 1, y - _dot - 1, x + _dot + 1, y + _dot + 1);
    // Merges and cherry-picks carry a message Mermaid makes up; only a written one is worth showing.
    final written = commit.type < CommitType.merge && commit.message.isNotEmpty;
    final body = StringBuffer(
      written ? '<title>${escText(commit.message)}</title>' : '',
    );
    body.write(_symbol(type, x, y, seriesColor(view.lane)));

    if (label != null && label.lines.isNotEmpty) {
      final w = label.width;
      final h = label.height;
      String back(double cx, double cy) =>
          '<rect x="${num(cx - w / 2 - 2)}" y="${num(cy - h / 2 + 2)}" width="${num(w + 4)}" height="${num(h - 4)}" rx="3" fill="var(--_bg)"/>';
      if (rotate) {
        // The text ends beside the commit and trails back the way the history came.
        final k = (_half * h) / 2;
        final ax = vertical ? x - _dot - 3 - k : x + 3;
        final ay = vertical ? y : y + _dot + 3 + k;
        final reach = _half * w + k;
        grow(
          ax - reach,
          flip ? ay - reach : ay - k,
          ax + k,
          flip ? ay + k : ay + reach,
        );
        body
          ..write(
            '<g class="pele-commit-label" transform="rotate(${flip ? 45 : -45} ${num(ax)} ${num(ay)})">',
          )
          ..write(back(ax - w / 2, ay))
          ..write(labelSvg(label, ax - w / 2, ay, ''))
          ..write('</g>');
      } else {
        final cx = vertical ? x - _dot - 6 - w / 2 : x;
        final cy = vertical ? y : y + _dot + 6 + h / 2;
        grow(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2);
        body.write(
          '<g class="pele-commit-label">${back(cx, cy)}${labelSvg(label, cx, cy, '')}</g>',
        );
      }
    }

    // Beside the lane the tags form a row; above it they stack, the first one furthest out.
    var offset = _dot + _tagGap;
    for (
      var t = vertical ? 0 : tags.length - 1;
      t >= 0 && t < tags.length;
      t += vertical ? 1 : -1
    ) {
      final tag = tags[t];
      final w = _tagWidth(tag);
      final h = tag.height;
      final left = vertical ? x + offset : x - w / 2;
      final cy = vertical ? y : y - offset - h / 2;
      offset += vertical ? w + 4 : h + 3;
      grow(left, cy - h / 2, left + w, cy + h / 2);
      body
        ..write('<g class="pele-tag">')
        ..write(
          '<path d="M${num(left)},${num(cy)}L${num(left + _notch)},${num(cy - h / 2)}H${num(left + w)}V${num(cy + h / 2)}H${num(left + _notch)}Z" fill="var(--_s)" stroke="var(--_b)" stroke-linejoin="round"/>',
        )
        ..write(
          '<circle cx="${num(left + _notch)}" cy="${num(cy)}" r="1.5" fill="var(--_b)"/>',
        )
        ..write(
          labelSvg(
            tag,
            left + _notch + 4 + tag.width / 2,
            cy,
            ' fill="var(--_fg)"',
          ),
        )
        ..write('</g>');
    }

    final merge = commit.type == CommitType.merge && type != CommitType.merge
        ? ' pele-commit-merge'
        : '';
    final cls = (type >= 0 && type < _classes.length)
        ? _classes[type]
        : _classes[0];
    commitsBuf.write(
      '<g class="pele-commit pele-commit-$cls$merge" data-id="${escText(commit.id)}">$body</g>',
    );
  }

  if (minX > maxX) grow(0, 0, 0, 0);
  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    4000,
    Style.bold,
  );
  final titleHeight = title.height > 0 ? title.height + 16 : 0.0;
  final inner = math.max(maxX - minX, title.width);
  final width = (inner + 2 * pad).ceilToDouble();
  final height = (maxY - minY + titleHeight + 2 * pad).ceilToDouble();
  final dx = pad - minX + (inner - (maxX - minX)) / 2;
  final dy = pad + titleHeight - minY;

  final branches = branchesBuf.toString();
  final curves = curvesBuf.toString();
  final lines = linesBuf.toString();
  final commits = commitsBuf.toString();

  final content =
      '${labelSvg(title, width / 2, pad + title.height / 2, ' class="pele-title" font-weight="var(--_tw)"')}'
      '<g transform="translate(${num(dx)},${num(dy)})">'
      '${branches.isNotEmpty ? '<g class="pele-branches" fill="none" font-size="${num(medium)}">$branches</g>' : ''}'
      '${(curves.isNotEmpty || lines.isNotEmpty) ? '<g class="pele-edges" fill="none" stroke-width="2" stroke-linecap="round">$curves$lines</g>' : ''}'
      '${commits.isNotEmpty ? '<g class="pele-commits" font-size="${num(small)}" fill="var(--_m)">$commits</g>' : ''}'
      '</g>';

  return Rendered(
    svg: svgDocument('gitGraph', width, height, size, options, model, content),
    width: width,
    height: height,
    links: const <LinkInfo>[],
  );
}
