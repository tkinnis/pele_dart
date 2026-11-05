// Upstream: src/diagrams/radar/model.ts

import '../../errors.dart';
import '../../svg/root.dart';
import 'parser.dart';

class RadarAxis {
  final String name;
  final String label;

  const RadarAxis({required this.name, required this.label});
}

class RadarCurve {
  final String name;
  final String label;
  final List<double> entries;

  const RadarCurve({
    required this.name,
    required this.label,
    required this.entries,
  });
}

class RadarOptions {
  bool showLegend;
  double ticks;
  double? max;
  double min;
  String graticule;

  RadarOptions({
    this.showLegend = true,
    this.ticks = 5,
    this.max,
    this.min = 0,
    this.graticule = 'circle',
  });
}

class RadarModel implements RootModel {
  final String type = 'radar';
  final String? title;
  @override
  final String? accTitle;
  @override
  final String? accDescr;
  final List<RadarAxis> axes;
  final List<RadarCurve> curves;
  final RadarOptions options;

  const RadarModel({
    this.title,
    this.accTitle,
    this.accDescr,
    required this.axes,
    required this.curves,
    required this.options,
  });
}

const double _maxTicks = 32;
final RegExp _leadSpacesRe = RegExp(r'^\s+');
final RegExp _newlineSpacesRe = RegExp(r'\n\s+');

PeleError _invalid(String message) {
  return PeleError(message, 'semantic', const PeleErrorInfo(type: 'radar'));
}

RadarModel buildRadar(RadarAst ast, String? title) {
  final axes = ast.axes
      .map((axis) => RadarAxis(name: axis.name, label: axis.label ?? axis.name))
      .toList();

  final curves = ast.curves.map((curve) {
    List<double> entries;
    if (curve.entries[0].axis == null) {
      entries = curve.entries.map((entry) => entry.value).toList();
    } else {
      if (axes.isEmpty) {
        throw _invalid(
          'Axes must be populated before curves for reference entries',
        );
      }
      final byAxis = <String, double>{};
      for (final entry in curve.entries) {
        if (entry.axis != null && !byAxis.containsKey(entry.axis!.$refText)) {
          byAxis[entry.axis!.$refText] = entry.value;
        }
      }
      entries = axes.map((axis) {
        final value = byAxis[axis.name];
        if (value == null) {
          throw _invalid('Missing entry for axis ${axis.label}');
        }
        return value;
      }).toList();
    }
    return RadarCurve(
      name: curve.name,
      label: curve.label ?? curve.name,
      entries: entries,
    );
  }).toList();

  final options = RadarOptions();
  for (final option in ast.options) {
    switch (option.name) {
      case 'showLegend':
        options.showLegend = option.value as bool;
      case 'graticule':
        options.graticule = option.value as String;
      case 'ticks':
        options.ticks = option.value as double;
      case 'max':
        options.max = option.value as double;
      case 'min':
        options.min = option.value as double;
    }
  }
  if (options.ticks > _maxTicks) options.ticks = _maxTicks;

  final astTitle = ast.title;
  final astAccTitle = ast.accTitle;
  final astAccDescr = ast.accDescr;

  return RadarModel(
    title: (astTitle != null && astTitle.isNotEmpty) ? astTitle : title,
    accTitle: (astAccTitle != null && astAccTitle.isNotEmpty)
        ? astAccTitle.replaceFirst(_leadSpacesRe, '')
        : null,
    accDescr: (astAccDescr != null && astAccDescr.isNotEmpty)
        ? astAccDescr.replaceAll(_newlineSpacesRe, '\n')
        : null,
    axes: axes,
    curves: curves,
    options: options,
  );
}
