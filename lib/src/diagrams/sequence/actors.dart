// Upstream: src/diagrams/sequence/actors.ts

import 'dart:math' as math;

import '../../svg/builder.dart';
import '../../svg/theme.dart';
import '../../text/label.dart';

const double _PAD_X = 16;
const double _PAD_Y = 10;
const double _GLYPH = 34;
const double _GLYPH_GAP = 4;
const double _STACK = 5;
const int _CAP = 6;
const String _SHAPE = ' fill="var(--_s)" stroke="var(--_b)"';
const String _LINE = ' fill="none" stroke="var(--_b)"';

const Set<String> _KINDS = <String>{
  'participant',
  'actor',
  'boundary',
  'control',
  'entity',
  'database',
  'collections',
  'queue',
};

const Set<String> _FIGURES = <String>{
  'actor',
  'boundary',
  'control',
  'entity',
  'database',
};

class ActorSize {
  const ActorSize({required this.w, required this.h});

  final double w;
  final double h;
}

String actorKind(String type) {
  return _KINDS.contains(type) ? type : 'participant';
}

/// A figure stands above its label. The other kinds hold the label inside.
bool isFigure(String kind) {
  return _FIGURES.contains(kind);
}

ActorSize actorSize(
  String kind,
  Label label,
  double minW,
  double minH, [
  double? paddingX,
]) {
  final px = paddingX ?? _PAD_X;
  if (isFigure(kind)) {
    return ActorSize(
      w: math.max<double>(40, label.width + 8),
      h: _GLYPH + (label.height > 0 ? _GLYPH_GAP + label.height : 0),
    );
  }
  final extra = kind == 'collections'
      ? _STACK
      : (kind == 'queue' ? 2.0 * _CAP : 0.0);
  return ActorSize(
    w: math.max<double>(minW, label.width + 2 * px) + extra,
    h:
        math.max<double>(minH, label.height + 2 * _PAD_Y) +
        (kind == 'collections' ? _STACK : 0.0),
  );
}

String _figure(String kind, double cx, double top) {
  final x = num(cx);
  String y(double dy) => num(top + dy);
  switch (kind) {
    case 'actor':
      return '<circle cx="$x" cy="${y(7)}" r="6"$_SHAPE/>'
          '<path d="M$x,${y(13)}V${y(24)}M${num(cx - 10)},${y(17)}H${num(cx + 10)}M${num(cx - 8)},${y(34)}L$x,${y(24)}L${num(cx + 8)},${y(34)}"$_LINE/>';
    case 'boundary':
      return '<path d="M${num(cx - 19)},${y(6)}V${y(28)}M${num(cx - 19)},${y(17)}H${num(cx - 8)}"$_LINE/>'
          '<circle cx="${num(cx + 3)}" cy="${y(17)}" r="11"$_SHAPE/>';
    case 'control':
      return '<circle cx="$x" cy="${y(21)}" r="11"$_SHAPE/>'
          '<path d="M${num(cx + 5)},${y(5)}L${num(cx - 1)},${y(10)}L${num(cx + 5)},${y(15)}"$_LINE/>';
    case 'entity':
      return '<circle cx="$x" cy="${y(15)}" r="11"$_SHAPE/>'
          '<path d="M${num(cx - 11)},${y(30)}H${num(cx + 11)}"$_LINE/>';
    default:
      final l = num(cx - 14);
      final r = num(cx + 14);
      return '<path d="M$l,${y(7)}V${y(27)}A14,5 0 0 0 $r,${y(27)}V${y(7)}A14,5 0 0 0 $l,${y(7)}Z"$_SHAPE/>'
          '<path d="M$l,${y(7)}A14,5 0 0 0 $r,${y(7)}"$_LINE/>';
  }
}

/// Draws a participant whose bounding box has its top center at `(cx, top)`.
String drawActor(
  String kind,
  double cx,
  double top,
  ActorSize size,
  Label label,
  IconResolver? icons, [
  String ink = '',
]) {
  final w = size.w;
  final h = size.h;
  const text = ' class="pele-label"';
  if (isFigure(kind)) {
    return _figure(kind, cx, top) +
        labelSvg(
          label,
          cx,
          top + _GLYPH + _GLYPH_GAP + label.height / 2,
          text + ink,
          icons,
        );
  }
  final left = cx - w / 2;
  if (kind == 'collections') {
    final bw = w - _STACK;
    final bh = h - _STACK;
    final back =
        '<rect x="${num(left + _STACK)}" y="${num(top)}" width="${num(bw)}" height="${num(bh)}"$_SHAPE$roundedAttr/>';
    final front =
        '<rect x="${num(left)}" y="${num(top + _STACK)}" width="${num(bw)}" height="${num(bh)}"$_SHAPE$roundedAttr/>';
    return back +
        front +
        labelSvg(label, left + bw / 2, top + _STACK + bh / 2, text, icons);
  }
  if (kind == 'queue') {
    final l = num(left + _CAP);
    final r = num(left + w - _CAP);
    final b = num(top + h);
    final ry = num(h / 2);
    return '<path d="M$l,${num(top)}H$r'
        'A$_CAP,$ry 0 0 1 $r,$b'
        'H$l'
        'A$_CAP,$ry 0 0 1 $l,${num(top)}Z"$_SHAPE/>'
        '<path d="M$r,${num(top)}A$_CAP,$ry 0 0 0 $r,$b"$_LINE/>'
        '${labelSvg(label, cx - _CAP / 2, top + h / 2, text, icons)}';
  }
  return '<rect x="${num(left)}" y="${num(top)}" width="${num(w)}" height="${num(h)}"$_SHAPE$roundedAttr/>'
      '${labelSvg(label, cx, top + h / 2, text, icons)}';
}
