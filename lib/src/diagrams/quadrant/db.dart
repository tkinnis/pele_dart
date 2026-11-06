// Upstream: src/diagrams/quadrant/db.ts

import '../../errors.dart';
import '../../svg/root.dart';

class QuadrantText {
  QuadrantText({required this.text, required this.type});

  String text;
  final String type;

  @override
  bool operator ==(Object other) =>
      other is QuadrantText && other.text == text && other.type == type;

  @override
  int get hashCode => Object.hash(text, type);
}

class PointStyle {
  PointStyle({this.radius, this.color, this.strokeColor, this.strokeWidth});

  double? radius;
  String? color;
  String? strokeColor;
  String? strokeWidth;

  @override
  bool operator ==(Object other) =>
      other is PointStyle &&
      other.radius == radius &&
      other.color == color &&
      other.strokeColor == strokeColor &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(radius, color, strokeColor, strokeWidth);
}

class QuadrantPoint extends PointStyle {
  QuadrantPoint({
    required this.x,
    required this.y,
    required this.text,
    required this.className,
    super.radius,
    super.color,
    super.strokeColor,
    super.strokeWidth,
  });

  final double x;
  final double y;
  final QuadrantText text;
  final String className;

  @override
  bool operator ==(Object other) =>
      other is QuadrantPoint &&
      other.x == x &&
      other.y == y &&
      other.text == text &&
      other.className == className &&
      other.radius == radius &&
      other.color == color &&
      other.strokeColor == strokeColor &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(
    x,
    y,
    text,
    className,
    radius,
    color,
    strokeColor,
    strokeWidth,
  );
}

abstract interface class QuadrantModel implements Accessible {
  String get type;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
  // Quadrants 1 to 4: top right, top left, bottom left, bottom right.
  List<QuadrantText?> get quadrants;
  QuadrantText? get xAxisLeft;
  QuadrantText? get xAxisRight;
  QuadrantText? get yAxisBottom;
  QuadrantText? get yAxisTop;
  List<QuadrantPoint> get points;
  Map<String, PointStyle> get classes;
}

final RegExp _reNumber = RegExp(r'^\d+$');
final RegExp _reHex = RegExp(r'^#?([\dA-Fa-f]{6}|[\dA-Fa-f]{3})$');
final RegExp _rePixels = RegExp(r'^\d+px$');

PeleError _invalid(String style, String value, String kind) {
  return PeleError(
    'value for $style $value is invalid, please use a valid $kind',
    'semantic',
    const PeleErrorInfo(type: 'quadrantChart'),
  );
}

// The first two parts of Mermaid's `style.trim().split(/\s*:\s*/)`, found in one pass.
(String, String) _keyValue(String style) {
  final s = style.trim();
  final colon = s.indexOf(':');
  if (colon == -1) return (s, 'undefined');
  final rest = s.substring(colon + 1).trimLeft();
  final next = rest.indexOf(':');
  return (
    s.substring(0, colon).trimRight(),
    next == -1 ? rest : rest.substring(0, next).trimRight(),
  );
}

PointStyle parseStyles(List<String> styles) {
  final out = PointStyle();
  for (final style in styles) {
    final (key, value) = _keyValue(style);
    if (key == 'radius') {
      if (!_reNumber.hasMatch(value)) throw _invalid(key, value, 'number');
      out.radius = double.parse(value);
    } else if (key == 'color') {
      if (!_reHex.hasMatch(value)) throw _invalid(key, value, 'hex code');
      out.color = value;
    } else if (key == 'stroke-color') {
      if (!_reHex.hasMatch(value)) throw _invalid(key, value, 'hex code');
      out.strokeColor = value;
    } else if (key == 'stroke-width') {
      if (!_rePixels.hasMatch(value)) {
        throw _invalid(key, value, 'number of pixels (eg. 10px)');
      }
      out.strokeWidth = value;
    } else {
      throw PeleError(
        'style named $key is not supported.',
        'semantic',
        const PeleErrorInfo(type: 'quadrantChart'),
      );
    }
  }
  return out;
}

QuadrantText _trimmed(QuadrantText label) {
  return QuadrantText(text: label.text.trim(), type: label.type);
}

double _jsNumber(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return 0;
  if (s.startsWith('0x') || s.startsWith('0X')) {
    final bi = BigInt.tryParse(s.substring(2), radix: 16);
    return bi != null ? bi.toDouble() : double.nan;
  }
  return double.tryParse(s) ?? double.nan;
}

class QuadrantDb implements QuadrantModel {
  @override
  final String type = 'quadrantChart';
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;
  @override
  List<QuadrantText?> quadrants = <QuadrantText?>[null, null, null, null];
  @override
  QuadrantText? xAxisLeft;
  @override
  QuadrantText? xAxisRight;
  @override
  QuadrantText? yAxisBottom;
  @override
  QuadrantText? yAxisTop;
  @override
  List<QuadrantPoint> points = <QuadrantPoint>[];
  @override
  Map<String, PointStyle> classes = <String, PointStyle>{};

  void setQuadrant1Text(QuadrantText label) {
    quadrants[0] = _trimmed(label);
  }

  void setQuadrant2Text(QuadrantText label) {
    quadrants[1] = _trimmed(label);
  }

  void setQuadrant3Text(QuadrantText label) {
    quadrants[2] = _trimmed(label);
  }

  void setQuadrant4Text(QuadrantText label) {
    quadrants[3] = _trimmed(label);
  }

  void setXAxisLeftText(QuadrantText label) {
    xAxisLeft = _trimmed(label);
  }

  void setXAxisRightText(QuadrantText label) {
    xAxisRight = _trimmed(label);
  }

  void setYAxisBottomText(QuadrantText label) {
    yAxisBottom = _trimmed(label);
  }

  void setYAxisTopText(QuadrantText label) {
    yAxisTop = _trimmed(label);
  }

  void addPoint(
    QuadrantText label,
    String className,
    String x,
    String y,
    List<String> styles,
  ) {
    final parsed = parseStyles(styles);
    points.add(
      QuadrantPoint(
        x: _jsNumber(x),
        y: _jsNumber(y),
        text: _trimmed(label),
        className: className,
        radius: parsed.radius,
        color: parsed.color,
        strokeColor: parsed.strokeColor,
        strokeWidth: parsed.strokeWidth,
      ),
    );
  }

  void addClass(String className, List<String> styles) {
    classes[className] = parseStyles(styles);
  }

  void setDiagramTitle(String text) {
    title = text;
  }

  void setAccTitle(String text) {
    accTitle = text.replaceFirst(RegExp(r'^\s+'), '');
  }

  void setAccDescription(String text) {
    accDescr = text.replaceAll(RegExp(r'\n\s+'), '\n');
  }
}
