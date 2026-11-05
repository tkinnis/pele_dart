// Upstream: src/diagrams/sequence/render.ts

import 'dart:math' as math;
import 'dart:typed_data';

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/edges.dart';
import '../../svg/ink.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../svg/title.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_width.dart';
import '../common/literal_label.dart';
import 'actors.dart';
import 'db.dart';
import 'types.dart';

enum _Head { none, arrow, cross, open, halfSolid, halfStick }

class _LineStyle {
  const _LineStyle({
    required this.dotted,
    required this.head,
    required this.atStart,
    required this.atEnd,
    required this.bottom,
  });

  final bool dotted;
  final _Head head;

  /// Where the heads are: at the receiver, at the sender only (the reverse arrows), or at both.
  final bool atStart;
  final bool atEnd;
  final bool bottom;
}

final List<_LineStyle?> _STYLES = _buildStyles();

List<_LineStyle?> _buildStyles() {
  final out = List<_LineStyle?>.filled(64, null);
  void style(
    int type,
    bool dotted,
    _Head head, [
    int ends = 1,
    bool bottom = false,
  ]) {
    out[type] = _LineStyle(
      dotted: dotted,
      head: head,
      atStart: ends != 1,
      atEnd: ends != 0,
      bottom: bottom,
    );
  }

  style(LINETYPE.SOLID, false, _Head.arrow);
  style(LINETYPE.DOTTED, true, _Head.arrow);
  style(LINETYPE.SOLID_CROSS, false, _Head.cross);
  style(LINETYPE.DOTTED_CROSS, true, _Head.cross);
  style(LINETYPE.SOLID_OPEN, false, _Head.none);
  style(LINETYPE.DOTTED_OPEN, true, _Head.none);
  style(LINETYPE.SOLID_POINT, false, _Head.open);
  style(LINETYPE.DOTTED_POINT, true, _Head.open);
  style(LINETYPE.BIDIRECTIONAL_SOLID, false, _Head.arrow, 2);
  style(LINETYPE.BIDIRECTIONAL_DOTTED, true, _Head.arrow, 2);
  for (final dotted in const <bool>[false, true]) {
    final d = dotted ? 10 : 0;
    style(LINETYPE.SOLID_TOP + d, dotted, _Head.halfSolid);
    style(LINETYPE.SOLID_BOTTOM + d, dotted, _Head.halfSolid, 1, true);
    style(LINETYPE.STICK_TOP + d, dotted, _Head.halfStick);
    style(LINETYPE.STICK_BOTTOM + d, dotted, _Head.halfStick, 1, true);
    style(LINETYPE.SOLID_ARROW_TOP_REVERSE + d, dotted, _Head.halfSolid, 0);
    style(
      LINETYPE.SOLID_ARROW_BOTTOM_REVERSE + d,
      dotted,
      _Head.halfSolid,
      0,
      true,
    );
    style(LINETYPE.STICK_ARROW_TOP_REVERSE + d, dotted, _Head.halfStick, 0);
    style(
      LINETYPE.STICK_ARROW_BOTTOM_REVERSE + d,
      dotted,
      _Head.halfStick,
      0,
      true,
    );
  }
  return out;
}

const Map<int, String> _FRAME_KIND = <int, String>{
  LINETYPE.LOOP_START: 'loop',
  LINETYPE.ALT_START: 'alt',
  LINETYPE.OPT_START: 'opt',
  LINETYPE.PAR_START: 'par',
  LINETYPE.PAR_OVER_START: 'par',
  LINETYPE.CRITICAL_START: 'critical',
  LINETYPE.BREAK_START: 'break',
  LINETYPE.RECT_START: 'rect',
};

const double _MSG_PAD = 12;
const double _SELF_W = 28;
const double _SELF_H = 22;
const int _ACT_W = 10;
const double _ACT_STEP = 4;
const double _ACT_MIN = 14;
const double _NOTE_GAP = 10;
const double _NOTE_OVER = 16;
const double _FRAME_PAD = 20;
const double _FRAME_NEST = 10;
const int _TAB_H = 20;
const double _FRAME_TEXT = 240;
const int _BADGE_H = 16;
const int _CENTRAL_R = 4;
const String _DASH = ' stroke-dasharray="4 4"';

class Numbering {
  const Numbering({
    required this.index,
    required this.shown,
    required this.visible,
  });

  /// The number each message line carries, whether or not it is shown. `NaN` for everything else.
  final List<double> index;
  final List<bool> shown;

  /// Whether numbers are on after the last statement.
  final bool visible;
}

bool isLineMessage(int? type) {
  return type != null &&
      type >= 0 &&
      type < _STYLES.length &&
      _STYLES[type] != null;
}

/// Counts message lines the way Mermaid's renderer does while it draws.
Numbering numberMessages(List<SeqMessage> messages, bool always) {
  final index = List<double>.filled(messages.length, double.nan);
  final shown = List<bool>.filled(messages.length, false);
  var current = 1.0;
  var step = 1.0;
  var visible = false;
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    index[i] = double.nan;
    shown[i] = false;
    if (m.type == LINETYPE.AUTONUMBER) {
      final spec = m.message as SeqNumbering;
      current = (spec.start != null && spec.start != 0 && !spec.start!.isNaN)
          ? spec.start!
          : current;
      step = (spec.step != null && spec.step != 0 && !spec.step!.isNaN)
          ? spec.step!
          : step;
      visible = spec.visible;
    } else if (isLineMessage(m.type)) {
      index[i] = current;
      shown[i] = visible || always;
      current = roundJs((current + step) * 100) / 100.0;
    }
  }
  return Numbering(index: index, shown: shown, visible: visible);
}

class _Column {
  _Column({
    required this.id,
    required this.actor,
    required this.kind,
    required this.label,
    required this.size,
    required this.x,
    required this.createAt,
    required this.destroyAt,
    required this.top,
    required this.lifeStart,
    required this.lifeEnd,
  });

  final String id;
  final SeqActor actor;
  final String kind;
  final Label label;
  final ActorSize size;
  double x;
  final int createAt;
  final int destroyAt;
  double top;
  double lifeStart;
  double lifeEnd;
  final List<double> activations = <double>[];
}

enum _V { line, self, note }

class _View {
  _View({
    required this.kind,
    required this.a,
    required this.b,
    required this.label,
    required this.x,
    required this.w,
  });

  final _V kind;
  final int a;
  final int b;
  Label label;
  double x;
  double w;
}

class _Frame {
  _Frame({
    required this.kind,
    required this.x0,
    required this.x1,
    required this.top,
    required this.title,
    required this.tabW,
    required this.fill,
    required this.dividers,
  });

  final String kind;
  double x0;
  double x1;
  double top;
  Label title;
  double tabW;
  final String fill;
  final List<int> dividers;
  final List<double> dividerY = <double>[];
  final List<Label> dividerLabels = <Label>[];
}

class _BoxRun {
  _BoxRun({
    required this.box,
    required this.first,
    required this.last,
    required this.title,
    required this.grow,
  });

  final SeqBox box;
  final int first;
  int last;
  final Label title;
  double grow;
}

final Label _NO_LABEL = Label(
  lines: const <List<Span>>[],
  widths: const <double>[],
  width: 0,
  height: 0,
  size: 0,
  lineHeight: 0,
);

class _MonoMeasurer implements TextMeasurer {
  const _MonoMeasurer(this._inner);

  final TextMeasurer _inner;

  @override
  double width(String text, double size, [int style = 0]) =>
      _inner.width(text, size, style | Style.Mono);
}

double _option(Config conf, String key, double fallback) {
  final value = conf[key];
  if (value is int && value >= 0 && value <= 2000) return value.toDouble();
  if (value is double && value >= 0 && value <= 2000) return value;
  return fallback;
}

String _half(
  double x,
  double y,
  double dir,
  double up,
  bool stick,
  String color,
) {
  final bx = num(x - dir * ARROW);
  if (stick) {
    return '<path class="pele-marker" d="M${num(x)},${num(y)}L$bx,${num(y + up * 5)}"/>';
  }
  return '<path class="pele-marker" d="M${num(x)},${num(y)}L$bx,${num(y + up * 4.5)}V${num(y)}Z" fill="$color" stroke="none"/>';
}

/// Draws the head whose tip is at `(x, y)` and points along `dir`. `up` is the side a half head sits on.
String _head(
  _Head type,
  double x,
  double y,
  double dir,
  double up,
  String color,
) {
  switch (type) {
    case _Head.arrow:
      return marker('arrow_point', x, y, dir, 0, color);
    case _Head.cross:
      return marker('arrow_cross', x, y, dir, 0, color);
    case _Head.open:
      return '<path class="pele-marker" d="M${num(x - dir * ARROW)},${num(y - 4.5)}L${num(x)},${num(y)}L${num(x - dir * ARROW)},${num(y + 4.5)}" stroke-linejoin="round"/>';
    case _Head.halfSolid:
      return _half(x, y, dir, up, false, color);
    case _Head.halfStick:
      return _half(x, y, dir, up, true, color);
    case _Head.none:
      return '';
  }
}

double _trim(_Head type) {
  return type == _Head.arrow ? ARROW - 1 : (type == _Head.cross ? 4 : 0);
}

Rendered renderSequence(SeqDb db, Config config, RenderOptions options) {
  return tighten(options, (tight) => _draw(db, config, options, tight));
}

Rendered _draw(
  SeqDb db,
  Config config,
  RenderOptions options,
  bool tight, [
  double hold = 0,
  bool byNeed = true,
]) {
  final conf = asConfig(config['sequence']);
  final size = options.fontSize ?? 16;
  final smallInt = roundJs(size * 0.875);
  final small = smallInt.toDouble();
  final tinyInt = roundJs(size * 0.75);
  final tiny = tinyInt.toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final monospaced =
      options.monospace != null && options.monospace!.contains('messages');
  final TextMeasurer messageMeasurer = monospaced
      ? _MonoMeasurer(measurer)
      : measurer;
  final icons = options.icons;
  final pad = options.padding ?? 8;
  final mirror = conf['mirrorActors'] != false;
  final rightAngles = conf['rightAngles'] == true;
  final actorMargin = math.min<double>(
    _option(conf, 'actorMargin', 40),
    tight ? 8 : double.infinity,
  );
  final minW = math.min<double>(
    _option(conf, 'width', 64),
    tight ? 48 : double.infinity,
  );
  final minH = _option(conf, 'height', (roundJs(size * 1.5) + 20).toDouble());
  final wrapW = math.min<double>(
    _option(conf, 'width', 160),
    tight
        ? math.max<double>(
            32,
            ((options.maxWidth ?? 320) - 2 * pad) /
                    math.max<int>(1, db.actors.length) -
                actorMargin -
                24,
          )
        : double.infinity,
  );
  // Mermaid's default of 35 corresponds to Pele's default gap. Other values move it by the difference.
  final msgGap = math.max<double>(
    4,
    14 + _option(conf, 'messageMargin', 35) - 35,
  );
  final notePad = math.min<double>(
    _option(conf, 'noteMargin', 10),
    tight ? 6 : double.infinity,
  );
  final boxPad = math.min<double>(
    _option(conf, 'boxMargin', 10),
    tight ? 6 : double.infinity,
  );
  final align = conf['messageAlign'] == 'left'
      ? -1
      : (conf['messageAlign'] == 'right' ? 1 : 0);

  final msgPad = tight ? 6.0 : _MSG_PAD;
  final noteOver = tight ? 8.0 : _NOTE_OVER;
  final framePad = tight ? 12.0 : _FRAME_PAD;
  final frameNest = tight ? 6.0 : _FRAME_NEST;
  final messages = db.messages;
  final count = messages.length;
  final numbering = numberMessages(
    messages,
    conf['showSequenceNumbers'] == true,
  );

  Label text(
    String? raw,
    double fontSize,
    bool wrap, [
    double? widthArg,
    TextMeasurer? byArg,
  ]) {
    final width = widthArg ?? wrapW;
    final by = byArg ?? measurer;
    final label = layoutLabel(
      raw,
      false,
      by,
      fontSize,
      tight || wrap ? width : double.infinity,
    );
    return tight ? breakLabel(label, by, math.max<double>(120, width)) : label;
  }

  Label messageText(String raw, bool wrap, [double? widthArg]) =>
      text(raw, small, wrap, widthArg ?? wrapW, messageMeasurer);

  Set<String?>? used;
  if (conf['hideUnusedParticipants'] == true) {
    used = <String?>{};
    for (final m in messages) {
      used.add(m.from);
      used.add(m.to);
    }
  }

  final nextLine = Int32List(count + 1);
  nextLine[count] = -1;
  for (var i = count - 1; i >= 0; i--) {
    nextLine[i] = isLineMessage(messages[i].type) ? i : nextLine[i + 1];
  }

  final cols = <_Column>[];
  final colOf = <String, int>{};
  for (final entry in db.actors.entries) {
    final id = entry.key;
    final actor = entry.value;
    if (used != null && !used.contains(id)) continue;
    final kind = actorKind(actor.type);
    final label = text(actor.description, size, actor.wrap);
    final created = db.createdActors[id];
    final destroyed = db.destroyedActors[id];
    var createAt = created == null
        ? -1
        : nextLine[math.min<int>(created, count)];
    if (createAt >= 0 && messages[createAt].to != id) createAt = -1;
    var destroyAt = destroyed == null
        ? -1
        : nextLine[math.min<int>(destroyed, count)];
    if (destroyAt >= 0 &&
        messages[destroyAt].to != id &&
        messages[destroyAt].from != id) {
      destroyAt = -1;
    }
    colOf[id] = cols.length;
    cols.add(
      _Column(
        id: id,
        actor: actor,
        kind: kind,
        label: label,
        size: actorSize(kind, label, minW, minH, tight ? 8 : null),
        x: 0,
        createAt: createAt,
        destroyAt: destroyAt,
        top: 0,
        lifeStart: 0,
        lifeEnd: -1,
      ),
    );
  }
  final last = cols.length - 1;

  // Widths between lifelines. Every message and note says how far apart the lifelines it touches must be.
  final needs = <int, double>{};
  void need(int lo, int hi, double width) {
    if (lo < 0 || hi > last) return;
    final key = lo * cols.length + hi;
    if ((needs[key] ?? 0) < width) needs[key] = width;
  }

  double badgeWidth(int i) => numbering.shown[i]
      ? math.max<double>(
          _BADGE_H.toDouble(),
          measurer.width(num(numbering.index[i]), tiny, 0) + 8,
        )
      : 0;

  final views = List<_View?>.filled(count, null);
  final sized = List<Map<double, Label>?>.filled(count, null);
  Label sizedText(int i, double room) {
    var known = sized[i];
    if (known == null) {
      if (room == wrapW) return views[i]!.label;
      sized[i] = known = <double, Label>{wrapW: views[i]!.label};
    }
    var label = known[room];
    if (label == null) {
      label = messageText(messages[i].message as String, true, room);
      known[room] = label;
    }
    return label;
  }

  for (var i = 0; i < count; i++) {
    final m = messages[i];
    final a = m.from == null ? null : colOf[m.from!];
    final b = m.to == null ? null : colOf[m.to!];
    if (a == null || b == null || m.message is! String) continue;
    final msgStr = m.message as String;
    if (m.type == LINETYPE.NOTE) {
      final label = text(msgStr, small, m.wrap);
      final w = label.width + 2 * notePad;
      if (m.placement == PLACEMENT.LEFTOF) {
        need(a - 1, a, w + 2 * _NOTE_GAP + _ACT_W);
      } else if (m.placement == PLACEMENT.RIGHTOF) {
        need(a, a + 1, w + 2 * _NOTE_GAP + _ACT_W);
      } else if (a == b) {
        need(a - 1, a, w / 2 + _NOTE_GAP);
        need(a, a + 1, w / 2 + _NOTE_GAP);
      } else {
        need(math.min<int>(a, b), math.max<int>(a, b), w - 2 * noteOver);
      }
      views[i] = _View(kind: _V.note, a: a, b: b, label: label, x: 0, w: w);
    } else if (isLineMessage(m.type)) {
      final label = messageText(msgStr, m.wrap);
      final badge = badgeWidth(i);
      if (a == b) {
        need(a, a + 1, _SELF_W + 8 + label.width + 16 + _ACT_W + badge);
        views[i] = _View(kind: _V.self, a: a, b: b, label: label, x: 0, w: 0);
      } else {
        final created = cols[b].createAt == i ? cols[b].size.w / 2 : 0.0;
        final central =
            (m.centralConnection != null && m.centralConnection != 0)
            ? 4.0 * _CENTRAL_R
            : 0.0;
        need(
          math.min<int>(a, b),
          math.max<int>(a, b),
          (tight
                  ? math.min<double>(
                      label.width,
                      math.max<double>(16, wrapW - 16),
                    )
                  : label.width) +
              2 * msgPad +
              _ACT_W +
              badge +
              created +
              central,
        );
        views[i] = _View(kind: _V.line, a: a, b: b, label: label, x: 0, w: 0);
      }
    }
  }

  final runs = <_BoxRun>[];
  for (var i = 0; i <= last; i++) {
    final box = cols[i].actor.box;
    final run = runs.isNotEmpty ? runs.last : null;
    if (box != null && run != null && run.box == box && run.last == i - 1) {
      run.last = i;
    } else if (box != null) {
      runs.add(
        _BoxRun(
          box: box,
          first: i,
          last: i,
          title: text(box.name, small, box.wrap),
          grow: 0,
        ),
      );
    }
  }

  final gaps = List<double>.filled(math.max<int>(last, 0), 0);
  for (var i = 0; i < last; i++) {
    final left = cols[i];
    final right = cols[i + 1];
    final boxed = left.actor.box != right.actor.box
        ? (left.actor.box != null ? boxPad : 0.0) +
              (right.actor.box != null ? boxPad : 0.0)
        : 0.0;
    gaps[i] = math.max<double>(
      left.size.w / 2 + right.size.w / 2 + actorMargin + boxed,
      needs[i * cols.length + i + 1] ?? 0,
    );
  }
  // A message across several lifelines widens each gap it crosses by an equal share of what is missing.
  final spans = <(int, int, double)>[];
  for (final entry in needs.entries) {
    final key = entry.key;
    final width = entry.value;
    final lo = key ~/ cols.length;
    final hi = key % cols.length;
    if (hi - lo > 1) spans.add((lo, hi, width));
  }
  spans.sort((p, q) {
    final d = (p.$2 - p.$1) - (q.$2 - q.$1);
    return d != 0 ? d : p.$1 - q.$1;
  });
  for (final (lo, hi, width) in spans) {
    var total = 0.0;
    for (var i = lo; i < hi; i++) {
      total += gaps[i];
    }
    if (total >= width) continue;
    final share = (width - total) / (hi - lo);
    for (var i = lo; i < hi; i++) {
      gaps[i] += share;
    }
  }

  void place() {
    for (var i = 1; i <= last; i++) {
      cols[i].x = cols[i - 1].x + gaps[i - 1];
    }
  }

  place();
  for (final run in runs) {
    final inner =
        cols[run.last].x +
        cols[run.last].size.w / 2 -
        (cols[run.first].x - cols[run.first].size.w / 2);
    run.grow = math.max<double>(0, (run.title.width - inner) / 2);
    if (run.grow == 0) continue;
    if (run.first > 0) gaps[run.first - 1] += run.grow;
    if (run.last < last) gaps[run.last] += run.grow;
  }

  var minX = double.infinity;
  var maxX = double.negativeInfinity;
  void extend(double x0, double x1) {
    if (x0 < minX) minX = x0;
    if (x1 > maxX) maxX = x1;
  }

  (double, double) boxEdges(_BoxRun run) => (
    cols[run.first].x - cols[run.first].size.w / 2 - boxPad - run.grow,
    cols[run.last].x + cols[run.last].size.w / 2 + boxPad + run.grow,
  );

  final frames = List<_Frame?>.filled(count, null);
  void layout() {
    place();
    minX = double.infinity;
    maxX = double.negativeInfinity;
    for (final col in cols) {
      extend(col.x - col.size.w / 2, col.x + col.size.w / 2);
    }
    for (final run in runs) {
      final (bx0, bx1) = boxEdges(run);
      extend(bx0, bx1);
    }

    // Horizontal extents of every block, from what it holds.
    final open = <_Frame>[];
    (double, double) spanAll() =>
        last < 0 ? (0, 120) : (cols[0].x - framePad, cols[last].x + framePad);
    for (var i = 0; i < count; i++) {
      final m = messages[i];
      final type = m.type;
      final frameKind = type == null ? null : _FRAME_KIND[type];
      final view = views[i];
      if (frameKind != null) {
        final frame = _Frame(
          kind: frameKind,
          x0: double.infinity,
          x1: double.negativeInfinity,
          top: 0,
          title: _NO_LABEL,
          tabW: 0,
          fill: frameKind == 'rect' && m.message is String
              ? m.message as String
              : '',
          dividers: <int>[i],
        );
        frames[i] = frame;
        open.add(frame);
      } else if (type == LINETYPE.ALT_ELSE ||
          type == LINETYPE.PAR_AND ||
          type == LINETYPE.CRITICAL_OPTION) {
        if (open.isNotEmpty) open.last.dividers.add(i);
      } else if (type == LINETYPE.LOOP_END ||
          type == LINETYPE.ALT_END ||
          type == LINETYPE.OPT_END ||
          type == LINETYPE.PAR_END ||
          type == LINETYPE.CRITICAL_END ||
          type == LINETYPE.BREAK_END ||
          type == LINETYPE.RECT_END) {
        if (open.isEmpty) continue;
        final frame = open.removeLast();
        frames[i] = frame;
        if (frame.x0 > frame.x1) {
          final (sx0, sx1) = spanAll();
          frame.x0 = sx0;
          frame.x1 = sx1;
        }
        if (frame.kind != 'rect') {
          frame.tabW = measurer.width(frame.kind, tiny, Style.Bold) + 14;
          // A block grows to the right to give its texts up to FRAME_TEXT of width before they wrap.
          for (var k = 0; k < frame.dividers.length; k++) {
            final raw = messages[frame.dividers[k]].message;
            final tab = k == 0 ? frame.tabW + 8 : 0.0;
            final room = frame.x1 - frame.x0 - 16 - tab;
            final label = (raw is String && raw.isNotEmpty)
                ? text(
                    '[$raw]',
                    small,
                    true,
                    math.max<double>(
                      room,
                      tight
                          ? math.min<double>(_FRAME_TEXT, wrapW)
                          : _FRAME_TEXT,
                    ),
                  )
                : _NO_LABEL;
            if (label.width > room) frame.x1 += label.width - room;
            if (k == 0) {
              frame.title = label;
            } else {
              frame.dividerLabels.add(label);
            }
          }
        }
        extend(frame.x0, frame.x1);
        final parent = open.isNotEmpty ? open.last : null;
        if (parent != null) {
          parent.x0 = math.min<double>(parent.x0, frame.x0 - frameNest);
          parent.x1 = math.max<double>(parent.x1, frame.x1 + frameNest);
        }
      } else if (view != null) {
        final a = cols[view.a];
        final b = cols[view.b];
        double x0;
        double x1;
        if (view.kind == _V.note) {
          if (m.placement == PLACEMENT.LEFTOF) {
            view.x = a.x - _NOTE_GAP - view.w;
          } else if (m.placement == PLACEMENT.RIGHTOF) {
            view.x = a.x + _NOTE_GAP;
          } else if (view.a == view.b) {
            view.x = a.x - view.w / 2;
          } else {
            final lo = math.min<double>(a.x, b.x) - noteOver;
            final hi = math.max<double>(a.x, b.x) + noteOver;
            if (tight || m.wrap) {
              view.label = text(
                m.message as String,
                small,
                true,
                math.max<double>(wrapW, hi - lo - 2 * notePad),
              );
            }
            view.w = math.max<double>(hi - lo, view.label.width + 2 * notePad);
            view.x = (lo + hi - view.w) / 2;
          }
          x0 = view.x;
          x1 = view.x + view.w;
        } else if (view.kind == _V.self) {
          x0 = a.x;
          x1 = a.x + _ACT_W + _SELF_W + 8 + view.label.width + badgeWidth(i);
        } else {
          x0 = math.min<double>(a.x, b.x);
          x1 = math.max<double>(a.x, b.x);
          if (tight || m.wrap) {
            view.label = sizedText(
              i,
              math.max<double>(wrapW, x1 - x0 - 2 * msgPad - _ACT_W),
            );
          }
          if (b.createAt == i) {
            if (b.x > a.x) {
              x1 += b.size.w / 2;
            } else {
              x0 -= b.size.w / 2;
            }
          }
        }
        extend(x0, x1);
        final frame = open.isNotEmpty ? open.last : null;
        if (frame != null) {
          frame.x0 = math.min<double>(frame.x0, x0 - framePad);
          frame.x1 = math.max<double>(frame.x1, x1 + framePad);
        }
      }
    }
  }

  layout();

  // Widen gaps only if it reduces message wrapping.
  var grown = false;
  var uneven = false;
  if (tight && options.maxWidth != null) {
    final spare =
        options.maxWidth!.floorToDouble() -
        (maxX - minX + 2 * pad).ceilToDouble() -
        hold;
    final stretch = Int32List(cols.length);
    final want = List<double>.filled(gaps.length, 0);
    final wrapped = <int>[];
    var lines = 0;
    for (var i = 0; spare > 0 && i < views.length; i++) {
      final view = views[i];
      if (view?.kind != _V.line) continue;
      final natural = messageText(
        messages[i].message as String,
        false,
        double.infinity,
      );
      if (view!.label.lines.length <= natural.lines.length) continue;
      wrapped.add(i);
      lines += view.label.lines.length;
      final lo = math.min<int>(view.a, view.b);
      final hi = math.max<int>(view.a, view.b);
      stretch[lo]++;
      stretch[hi]--;
      final short =
          (natural.width - (cols[hi].x - cols[lo].x - 2 * msgPad - _ACT_W)) /
          (hi - lo);
      for (var g = lo; g < hi; g++) {
        want[g] = math.max<double>(want[g], short);
      }
    }
    var active = 0;
    var crossed = 0;
    for (var i = 0; i < gaps.length; i++) {
      active += stretch[i];
      stretch[i] = active > 0 ? 1 : 0;
      crossed += stretch[i];
    }
    if (crossed > 0) {
      final before = List<double>.of(gaps);
      List<int> spread(double Function(int g) share) {
        for (var g = 0; g < gaps.length; g++) {
          gaps[g] = before[g] + share(g);
        }
        layout();
        return wrapped.map((i) => views[i]!.label.lines.length).toList();
      }

      int sumInt(List<int> counts) {
        var s = 0;
        for (final c in counts) {
          s += c;
        }
        return s;
      }

      double sumDouble(List<double> vals) {
        var s = 0.0;
        for (final v in vals) {
          s += v;
        }
        return s;
      }

      double even(int g) => (stretch[g] * spare) / crossed;
      var counts = spread(even);
      final missing = sumDouble(want);
      // Allow for rounding error.
      double needsShare(int g) => (want[g] * (spare - 0.01)) / missing;
      var anyWider = false;
      for (var g = 0; g < gaps.length; g++) {
        if (needsShare(g) > even(g)) {
          anyWider = true;
          break;
        }
      }
      // Reducing wrapping requires at least one gap wider than the even split.
      if (byNeed && crossed > 1 && missing > 0 && anyWider) {
        final first = counts;
        counts = spread(needsShare);
        var allLe = true;
        for (var k = 0; k < counts.length; k++) {
          if (counts[k] > first[k]) {
            allLe = false;
            break;
          }
        }
        uneven = sumInt(counts) < sumInt(first) && allLe;
        if (!uneven) counts = spread(even);
      }
      grown = sumInt(counts) < lines;
      if (!grown) {
        for (var g = 0; g < gaps.length; g++) {
          gaps[g] = before[g];
        }
        layout();
      }
    }
  }

  // Vertical placement, top to bottom, drawing as it goes.
  var boxTitleH = 0.0;
  for (final run in runs) {
    boxTitleH = math.max<double>(boxTitleH, run.title.height);
  }
  final boxTop = runs.isNotEmpty
      ? boxPad + (boxTitleH > 0 ? boxTitleH + 4 : 0.0)
      : 0.0;
  var rowH = 0.0;
  for (final col in cols) {
    if (col.createAt < 0) rowH = math.max<double>(rowH, col.size.h);
  }
  final headBottom = boxTop + rowH;
  for (final col in cols) {
    col.top = headBottom - col.size.h;
    col.lifeStart = headBottom;
  }

  final xs = cols.map((col) => col.x).toList();
  // Whether a lifeline runs between two x positions, where text would be struck through.
  bool crosses(double x0, double x1) {
    var lo = 0;
    var hi = xs.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (xs[mid] <= x0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo < xs.length && xs[lo] < x1;
  }

  final stack = <_Frame>[];
  final inks = <String, String?>{};
  String? inkOf(String? fill) {
    if (fill == null || fill.isEmpty) return null;
    if (!inks.containsKey(fill)) {
      inks[fill] = ink(resolveStyle(<String>['fill:$fill']).shape);
    }
    return inks[fill];
  }

  String inkOn(String? fill) {
    final color = inkOf(fill);
    return (color != null && color.isNotEmpty) ? ' fill="$color"' : '';
  }

  // Prefer the innermost rect's fill, then a containing box's.
  String? fillUnder(double l, double r) {
    for (var k = stack.length - 1; k >= 0; k--) {
      if (stack[k].kind == 'rect') return stack[k].fill;
    }
    for (final run in runs) {
      final (x0, x1) = boxEdges(run);
      if (l >= x0 && r <= x1) return run.box.fill;
    }
    return null;
  }

  String under(double l, double r) => inkOn(fillUnder(l, r));

  String backed(Label label, double cx, double cy, [bool frame = false]) {
    if (label.width == 0) return '';
    final l = cx - label.width / 2;
    final plate = crosses(l, l + label.width);
    final back = plate
        ? '<rect x="${num(l - 3)}" y="${num(cy - label.height / 2 + 2)}" width="${num(label.width + 6)}" height="${num(label.height - 4)}" rx="3" fill="var(--_bg)" stroke="none"/>'
        : '';
    final fill = plate ? '' : under(l, l + label.width);
    return back +
        labelSvg(
          label,
          cx,
          cy,
          frame
              ? ' class="pele-frame-label"${fill.isNotEmpty ? fill : ' fill="var(--_m)"'} stroke="none"'
              : fill,
          icons,
        );
  }

  double leftEdge(_Column col, [int extra = 0]) =>
      col.activations.length + extra > 0 ? col.x - _ACT_W / 2 : col.x;

  double rightEdge(_Column col, [int extra = 0]) {
    final depth = col.activations.length + extra;
    return depth > 0 ? col.x + _ACT_W / 2 + (depth - 1) * _ACT_STEP : col.x;
  }

  // Shaded blocks and activations close from the inside out. They are written in reverse, so that
  // the inner ones end up on top.
  final rectsOut = <String>[];
  final activationsOut = <String>[];
  final framesOut = StringBuffer();
  final edgesOut = StringBuffer();
  final labelsOut = StringBuffer();
  final notesOut = StringBuffer();
  final actorsOut = StringBuffer();
  final crossesOut = StringBuffer();

  double endActivation(_Column col, double end) {
    final start = col.activations.removeLast();
    final bottom = math.max<double>(end, start + _ACT_MIN);
    final x = col.x - _ACT_W / 2 + col.activations.length * _ACT_STEP;
    extend(x, x + _ACT_W);
    activationsOut.add(
      '<rect class="pele-activation" data-id="${escText(col.id)}" x="${num(x)}" y="${num(start)}" width="$_ACT_W" height="${num(bottom - start)}" rx="2"/>',
    );
    return bottom;
  }

  // The lifeline of a destroyed participant ends in a cross a little below the message that ends it.
  double destroy(_Column col, double lineY) {
    final cx = col.x;
    final cy = lineY + 16;
    col.lifeEnd = cy;
    crossesOut.write(
      '<path class="pele-destroy" data-id="${escText(col.id)}" d="M${num(cx - 6)},${num(cy - 6)}L${num(cx + 6)},${num(cy + 6)}M${num(cx + 6)},${num(cy - 6)}L${num(cx - 6)},${num(cy + 6)}"/>',
    );
    return cy + 6;
  }

  String actorSvg(_Column col, double top, bool footer) {
    final cls = col.actor.properties['class'];
    return '<g class="pele-node pele-actor pele-actor-${col.kind}${footer ? ' pele-actor-footer' : ''}${cls is String ? classNames(cls) : ''}" data-id="${escText(col.id)}">'
        '${drawActor(col.kind, col.x, top, col.size, col.label, icons, isFigure(col.kind) ? inkOn(col.actor.box?.fill) : '')}'
        '</g>';
  }

  String badge(int i, double cx, double cy, double w) =>
      '<g class="pele-sequence-number"><rect x="${num(cx - w / 2)}" y="${num(cy - _BADGE_H / 2)}" width="${num(w)}" height="$_BADGE_H" rx="${_BADGE_H ~/ 2}" fill="var(--_l)" stroke="none"/><text x="${num(cx)}" y="${num(cy + tiny * 0.35)}" text-anchor="middle" font-size="$tinyInt" fill="var(--_bg)" stroke="none">${esc(num(numbering.index[i]))}</text></g>';

  var y = headBottom + 6;
  for (var i = 0; i < count; i++) {
    final m = messages[i];
    final type = m.type;
    final view = views[i];
    final frame = frames[i];

    if (type == LINETYPE.ACTIVE_START) {
      final col = m.from == null ? null : colOf[m.from!];
      if (col != null) cols[col].activations.add(y);
    } else if (type == LINETYPE.ACTIVE_END) {
      final col = m.from == null ? null : colOf[m.from!];
      if (col != null && cols[col].activations.isNotEmpty) {
        y = math.max<double>(y, endActivation(cols[col], y));
      }
    } else if (frame != null && frame.dividers[0] == i) {
      stack.add(frame);
      if (frame.kind == 'rect') {
        frame.top = y + 8;
        y = frame.top;
      } else {
        frame.top = y + 12;
        y =
            frame.top +
            math.max<double>(_TAB_H.toDouble(), frame.title.height + 2);
      }
    } else if (frame != null) {
      stack.removeLast();
      final bottom = y + 12;
      final x = num(frame.x0);
      final w = num(frame.x1 - frame.x0);
      if (frame.kind == 'rect') {
        final fill = frame.fill.isNotEmpty
            ? resolveStyle(<String>['fill:${frame.fill}']).shape
            : '';
        rectsOut.add(
          '<rect class="pele-rect" x="$x" y="${num(frame.top)}" width="$w" height="${num(bottom - frame.top)}"${rounded('${fill.isNotEmpty ? '' : ' fill-opacity="0.5"'}$fill')}/>',
        );
      } else {
        final inner = StringBuffer(
          '<rect x="$x" y="${num(frame.top)}" width="$w" height="${num(bottom - frame.top)}" fill="none"$roundedAttr/>',
        );
        for (var k = 0; k < frame.dividerY.length; k++) {
          final dy = frame.dividerY[k];
          final label = frame.dividerLabels[k];
          inner.write(
            '<path d="M$x,${num(dy)}H${num(frame.x1)}"$_DASH/>'
            '${backed(label, frame.x0 + 8 + label.width / 2, dy + 2 + label.height / 2, true)}',
          );
        }
        inner.write(
          '<rect x="$x" y="${num(frame.top)}" width="${num(frame.tabW)}" height="$_TAB_H" fill="var(--_s)"$roundedAttr/>'
          '<text class="pele-frame-kind" x="${num(frame.x0 + frame.tabW / 2)}" y="${num(frame.top + _TAB_H / 2 + tiny * 0.35)}" text-anchor="middle" font-size="$tinyInt" font-weight="var(--_hw)" fill="var(--_m)" stroke="none">${frame.kind}</text>'
          '${backed(frame.title, frame.x0 + frame.tabW + 8 + frame.title.width / 2, frame.top + math.max<double>(_TAB_H.toDouble(), frame.title.height) / 2, true)}',
        );
        framesOut.write(
          '<g class="pele-frame pele-frame-${frame.kind}">$inner</g>',
        );
      }
      y = bottom;
    } else if (type == LINETYPE.ALT_ELSE ||
        type == LINETYPE.PAR_AND ||
        type == LINETYPE.CRITICAL_OPTION) {
      final current = stack.isNotEmpty ? stack.last : null;
      if (current != null) {
        final label = current.dividerLabels[current.dividerY.length];
        current.dividerY.add(y + 12);
        y += 12 + (label.height > 0 ? label.height : 0);
      }
    } else if (view != null && view.kind == _V.note) {
      final a = cols[view.a];
      final h = view.label.height + 2 * math.max<double>(4, notePad - 4);
      final top = y + 10;
      var x = view.x;
      if (m.placement == PLACEMENT.RIGHTOF) {
        x += rightEdge(a) - a.x;
      } else if (m.placement == PLACEMENT.LEFTOF) {
        x += leftEdge(a) - a.x;
      }
      extend(x, x + view.w);
      notesOut.write(
        '<g class="pele-note" data-id="i${escText(m.id)}">'
        '<rect x="${num(x)}" y="${num(top)}" width="${num(view.w)}" height="${num(h)}"$roundedAttr/>'
        '${labelSvg(view.label, x + view.w / 2, top + h / 2, ' class="pele-label" stroke="none" fill="var(--_fg)"', icons)}'
        '</g>',
      );
      y = top + h;
    } else if (view != null) {
      final st = _STYLES[type!]!;
      final a = cols[view.a];
      final b = cols[view.b];
      final label = view.label;
      final bw = badgeWidth(i);
      // The activation a `+` starts belongs to this message, so the arrow stops at its edge.
      var starting = 0;
      for (var k = i + 1; k < count; k++) {
        final t = messages[k].type;
        if (t == LINETYPE.ACTIVE_START) {
          if (messages[k].from == m.to) starting++;
        } else if (t != LINETYPE.ACTIVE_END &&
            t != LINETYPE.CENTRAL_CONNECTION &&
            t != LINETYPE.CENTRAL_CONNECTION_REVERSE) {
          break;
        }
      }
      final up = st.bottom ? 1.0 : -1.0;
      final attrs = st.dotted ? _DASH : '';
      final cc = m.centralConnection;
      final circleTo =
          cc == LINETYPE.CENTRAL_CONNECTION ||
          cc == LINETYPE.CENTRAL_CONNECTION_DUAL;
      final circleFrom =
          cc == LINETYPE.CENTRAL_CONNECTION_REVERSE ||
          cc == LINETYPE.CENTRAL_CONNECTION_DUAL;
      String? line;
      var color = 'var(--_l)';
      String circle(double cx, double cy) =>
          '<circle class="pele-central" cx="${num(cx)}" cy="${num(cy)}" r="$_CENTRAL_R" fill="$color" stroke="none"/>';
      final tailAtEnd = st.atStart && !st.atEnd;
      final headTrim = _trim(st.head);
      var inner = '';
      double lineY;

      if (view.kind == _V.self) {
        final top =
            y + msgGap + math.max<double>(0, (label.height - _SELF_H) / 2);
        final bottom = top + _SELF_H;
        var x0 = circleFrom ? a.x + _CENTRAL_R : rightEdge(a);
        var x1 = circleTo ? a.x + _CENTRAL_R : rightEdge(a, starting);
        final out = math.max<double>(x0, x1) + _SELF_W + bw / 2;
        line = inkOf(fillUnder(a.x, out));
        color = line ?? color;
        if (circleFrom) inner += circle(a.x, top);
        if (circleTo) inner += circle(a.x, bottom);
        if (bw > 0) {
          inner += badge(i, tailAtEnd ? x1 : x0, tailAtEnd ? bottom : top, bw);
          if (tailAtEnd) {
            x1 += bw / 2;
          } else {
            x0 += bw / 2;
          }
        }
        // The loop leaves to the right and comes back heading left, which turns a half head over.
        final heads =
            (st.atStart ? _head(st.head, x0, top, -1, up, color) : '') +
            (st.atEnd ? _head(st.head, x1, bottom, -1, -up, color) : '');
        final from = num(x0 + (st.atStart ? headTrim : 0));
        final to = num(x1 + (st.atEnd ? headTrim : 0));
        final d = rightAngles
            ? 'M$from,${num(top)}H${num(out)}V${num(bottom)}H$to'
            : 'M$from,${num(top)}H${num(out - 6)}A6,6 0 0 1 ${num(out)},${num(top + 6)}V${num(bottom - 6)}A6,6 0 0 1 ${num(out - 6)},${num(bottom)}H$to';
        inner = '<path d="$d"$attrs/>$heads$inner';
        extend(a.x, out + 8 + label.width);
        if (label.width > 0) {
          labelsOut.write(
            '<g class="pele-edge-label" data-id="i${escText(m.id)}">${labelSvg(label, out + 8 + label.width / 2, (top + bottom) / 2, under(out + 8, out + 8 + label.width), icons)}</g>',
          );
        }
        // A label taller than the loop reaches below it, so the next row starts under the label.
        lineY = math.max<double>(bottom, (top + bottom) / 2 + label.height / 2);
      } else {
        final dir = b.x > a.x ? 1.0 : -1.0;
        final creating = b.createAt == i;
        line = inkOf(
          fillUnder(math.min<double>(a.x, b.x), math.max<double>(a.x, b.x)),
        );
        color = line ?? color;
        lineY =
            y +
            msgGap +
            math.max<double>(
              label.height > 0 ? label.height + 2 : 6,
              creating ? b.size.h / 2 - msgGap + 6 : 0,
            );
        var x0 = dir > 0 ? rightEdge(a) : leftEdge(a);
        var x1 = dir > 0 ? leftEdge(b, starting) : rightEdge(b, starting);
        if (creating) {
          b.top = lineY - b.size.h / 2;
          b.lifeStart = b.top + b.size.h;
          x1 = b.x - dir * (isFigure(b.kind) ? 18 : b.size.w / 2 + 1);
        }
        if (circleFrom) {
          inner += circle(a.x, lineY);
          x0 = a.x + dir * _CENTRAL_R;
        }
        if (circleTo) {
          inner += circle(b.x, lineY);
          x1 = b.x - dir * _CENTRAL_R;
        }
        if (bw > 0) {
          // The number sits on the lifeline at the tail of the arrow, past a connection circle if there is one.
          if (tailAtEnd) {
            final cx = circleTo ? x1 - dir * (bw / 2 + 2) : x1;
            inner += badge(i, cx, lineY, bw);
            x1 = cx - (dir * bw) / 2;
          } else {
            final cx = circleFrom ? x0 + dir * (bw / 2 + 2) : x0;
            inner += badge(i, cx, lineY, bw);
            x0 = cx + (dir * bw) / 2;
          }
        }
        final heads =
            (st.atStart
                ? _head(st.head, x0, lineY, -dir, up * dir, color)
                : '') +
            (st.atEnd ? _head(st.head, x1, lineY, dir, up * dir, color) : '');
        final from = x0 + (st.atStart ? dir * headTrim : 0);
        final to = x1 - (st.atEnd ? dir * headTrim : 0);
        inner =
            '<path d="M${num(from)},${num(lineY)}H${num(to)}"$attrs/>$heads$inner';
        if (label.width > 0) {
          final l = math.min<double>(x0, x1);
          final r = math.max<double>(x0, x1);
          final cx = align < 0
              ? l + msgPad + label.width / 2
              : (align > 0 ? r - msgPad - label.width / 2 : (l + r) / 2);
          extend(cx - label.width / 2, cx + label.width / 2);
          labelsOut.write(
            '<g class="pele-edge-label" data-id="i${escText(m.id)}">${backed(label, cx, lineY - 4 - label.height / 2)}</g>',
          );
        }
        if (creating) y = lineY + b.size.h / 2 - 6;
      }
      edgesOut.write(
        '<g class="pele-edge pele-message" data-id="i${escText(m.id)}"${(line != null && line.isNotEmpty) ? ' stroke="$line"' : ''}>$inner</g>',
      );
      y = math.max<double>(y, lineY);
      if (a.destroyAt == i) y = math.max<double>(y, destroy(a, lineY));
      if (b.destroyAt == i && !identical(b, a)) {
        y = math.max<double>(y, destroy(b, lineY));
      }
    }
  }

  y += 20;
  for (final col in cols) {
    while (col.activations.isNotEmpty) {
      endActivation(col, y);
    }
  }
  var bottom = y;
  if (mirror) {
    var footH = 0.0;
    for (final col in cols) {
      if (col.lifeEnd >= 0) continue;
      footH = math.max<double>(footH, col.size.h);
      actorsOut.write(actorSvg(col, y, true));
    }
    bottom = y + footH;
  }
  final lifelines = StringBuffer();
  for (final col in cols) {
    actorsOut.write(actorSvg(col, col.top, false));
    final end = col.lifeEnd >= 0 ? col.lifeEnd : y;
    if (end > col.lifeStart) {
      lifelines.write(
        '<path class="pele-lifeline" data-id="${escText(col.id)}" d="M${num(col.x)},${num(col.lifeStart)}V${num(end)}"/>',
      );
    }
  }

  final boxesOut = StringBuffer();
  for (final run in runs) {
    final (x0, x1) = boxEdges(run);
    final fill = run.box.fill == 'transparent'
        ? ''
        : resolveStyle(<String>['fill:${run.box.fill}']).shape;
    final boxInk = inkOn(run.box.fill);
    boxesOut.write(
      '<g class="pele-cluster pele-box"${(run.box.name != null && run.box.name!.isNotEmpty) ? ' data-id="${escText(run.box.name!)}"' : ''}>'
      '<rect x="${num(x0)}" y="0" width="${num(x1 - x0)}" height="${num(bottom + boxPad)}" fill="var(--_a)" stroke="var(--_b)"${rounded('${fill.isNotEmpty ? '' : ' fill-opacity="0.5"'}$fill')}/>'
      '${labelSvg(run.title, (x0 + x1) / 2, boxPad / 2 + 2 + run.title.height / 2, ' class="pele-cluster-label"${boxInk.isNotEmpty ? boxInk : ' fill="var(--_m)"'}', icons)}'
      '</g>',
    );
  }
  if (runs.isNotEmpty) bottom += boxPad;

  var minY = 0.0;
  var titleOut = '';
  final room = titleRoom(options);
  final plainTitle = titleLabel(
    db.title,
    measurer,
    size,
    tight ? room : double.infinity,
  );
  final title = tight
      ? breakLabel(plainTitle, measurer, math.max<double>(120, room))
      : plainTitle;
  if (minX > maxX) extend(0, math.max<double>(title.width, 40));
  if (title.width > 0) {
    final cx = (minX + maxX) / 2;
    extend(cx - title.width / 2, cx + title.width / 2);
    minY = -title.height - 12;
    titleOut = labelSvg(
      title,
      cx,
      minY + title.height / 2,
      ' class="pele-title" font-weight="var(--_tw)"',
      icons,
    );
  }

  final width = (maxX - minX + 2 * pad).ceilToDouble();
  // Retry with equal shares or room for activation notes and rounding.
  if (grown && width > options.maxWidth!) {
    return _draw(
      db,
      config,
      options,
      tight,
      uneven
          ? hold
          : (hold > 0
                ? double.infinity
                : width - options.maxWidth!.floorToDouble()),
      false,
    );
  }
  final height = (bottom - minY + 2 * pad).ceilToDouble();
  final boxesStr = boxesOut.toString();
  final lifelinesStr = lifelines.toString();
  final framesStr = framesOut.toString();
  final edgesStr = edgesOut.toString();
  final crossesStr = crossesOut.toString();
  final labelsStr = labelsOut.toString();
  final notesStr = notesOut.toString();
  final actorsStr = actorsOut.toString();
  final svg = svgDocument(
    'sequence',
    width,
    height,
    size,
    options,
    db,
    '<g transform="translate(${num(pad - minX)},${num(pad - minY)})">'
        '$titleOut'
        '${boxesStr.isNotEmpty ? '<g class="pele-boxes" font-size="$smallInt">$boxesStr</g>' : ''}'
        '${rectsOut.isNotEmpty ? '<g class="pele-rects" fill="var(--_a)">${rectsOut.reversed.join()}</g>' : ''}'
        '${lifelinesStr.isNotEmpty ? '<g class="pele-lifelines" fill="none" stroke="var(--_b)">$lifelinesStr</g>' : ''}'
        '${activationsOut.isNotEmpty ? '<g class="pele-activations" fill="var(--_s)" stroke="var(--_b)">${activationsOut.reversed.join()}</g>' : ''}'
        '${framesStr.isNotEmpty ? '<g class="pele-frames" font-size="$smallInt" stroke="var(--_b)">$framesStr</g>' : ''}'
        '${edgesStr.isNotEmpty ? '<g class="pele-edges" fill="none" stroke="var(--_l)" stroke-linecap="round">$edgesStr</g>' : ''}'
        '${crossesStr.isNotEmpty ? '<g class="pele-destroys" fill="none" stroke="var(--_l)" stroke-width="1.5" stroke-linecap="round">$crossesStr</g>' : ''}'
        '${labelsStr.isNotEmpty ? '<g class="pele-edge-labels" font-size="$smallInt"${monospaced ? ' font-family="$fontMono"' : ''}>$labelsStr</g>' : ''}'
        '${notesStr.isNotEmpty ? '<g class="pele-notes" font-size="$smallInt" fill="var(--_a)" stroke="var(--_b)">$notesStr</g>' : ''}'
        '${actorsStr.isNotEmpty ? '<g class="pele-nodes">$actorsStr</g>' : ''}'
        '</g>',
  );
  return Rendered(svg: svg, width: width, height: height, links: <LinkInfo>[]);
}
