// Upstream: src/diagrams/xychart/db.ts

import '../../svg/root.dart';

class XyText {
  final String text;
  final String type;

  const XyText({required this.text, this.type = 'text'});
}

class DataPoint {
  final double value;
  final String label;

  const DataPoint({required this.value, required this.label});
}

sealed class XyAxis {
  String get type;
  String get title;
  set title(String value);
}

class BandAxis implements XyAxis {
  @override
  final String type = 'band';
  @override
  String title;
  final List<String> categories;

  BandAxis({required this.title, required this.categories});
}

class LinearAxis implements XyAxis {
  @override
  final String type = 'linear';
  @override
  String title;
  final double min;
  final double max;

  LinearAxis({required this.title, required this.min, required this.max});
}

// Each value with its place on the x axis: a category, or a number written as text.
// A category with no value has `null` (`undefined`).
typedef PlotData = List<(String, double?)>;

class Plot {
  final String type;
  final String title;
  final PlotData data;
  List<String>? pointLabels;

  Plot({
    required this.type,
    required this.title,
    required this.data,
    this.pointLabels,
  });
}

abstract interface class XyChartModel implements RootModel {
  String get type;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
  String? get orientation;
  XyAxis get xAxis;
  LinearAxis get yAxis;
  // False while the y range comes from the data and not from a `y-axis` statement.
  bool get hasSetYAxis;
  List<Plot> get plots;
}

final RegExp _leadSpacesRe = RegExp(r'^\s+');
final RegExp _newlineSpacesRe = RegExp(r'\n\s+');

String _jsNumberString(double v) {
  if (v == 0) return '0';
  final s = v.toString();
  if (!s.contains('e') && v == v.truncateToDouble() && v.abs() < 1e21) {
    return v.toInt().toString();
  }
  return s;
}

class XyChartDb implements XyChartModel {
  @override
  final String type = 'xychart';
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;
  @override
  String? orientation;
  @override
  XyAxis xAxis = BandAxis(title: '', categories: <String>[]);
  @override
  LinearAxis yAxis = LinearAxis(
    title: '',
    min: double.infinity,
    max: double.negativeInfinity,
  );
  bool hasSetXAxis = false;
  @override
  bool hasSetYAxis = false;
  @override
  final List<Plot> plots = <Plot>[];

  void setOrientation(String orientation) {
    this.orientation = orientation == 'horizontal' ? 'horizontal' : 'vertical';
  }

  void setXAxisTitle(XyText title) {
    xAxis.title = title.text.trim();
  }

  void setXAxisRangeData(double min, double max) {
    xAxis = LinearAxis(title: xAxis.title, min: min, max: max);
    hasSetXAxis = true;
  }

  void setXAxisBand(List<XyText> categories) {
    xAxis = BandAxis(
      title: xAxis.title,
      categories: categories.map((c) => c.text.trim()).toList(),
    );
    hasSetXAxis = true;
  }

  void setYAxisTitle(XyText title) {
    yAxis.title = title.text.trim();
  }

  void setYAxisRangeData(double min, double max) {
    yAxis = LinearAxis(title: yAxis.title, min: min, max: max);
    hasSetYAxis = true;
  }

  PlotData _plotData(List<double> values) {
    if (values.isEmpty) return <(String, double?)>[];
    // The first series fixes the x range when no x-axis statement did.
    if (!hasSetXAxis) setXAxisRangeData(1, values.length.toDouble());
    final x = xAxis;
    if (x is BandAxis && values.length > x.categories.length) {
      values = values.sublist(0, x.categories.length);
    }
    if (!hasSetYAxis) {
      var min = yAxis.min;
      var max = yAxis.max;
      for (final value in values) {
        if (value < min) min = value;
        if (value > max) max = value;
      }
      yAxis = LinearAxis(title: yAxis.title, min: min, max: max);
    }
    if (x is BandAxis) {
      return List<(String, double?)>.generate(
        x.categories.length,
        (i) => (x.categories[i], i < values.length ? values[i] : null),
      );
    }
    final lx = x as LinearAxis;
    if (values.length == 1) {
      return <(String, double?)>[(_jsNumberString(lx.min), values[0])];
    }
    final step = (lx.max - lx.min) / (values.length - 1);
    return List<(String, double?)>.generate(
      values.length,
      (i) => (_jsNumberString(lx.min + i * step), values[i]),
    );
  }

  void _addPlot(String type, XyText title, List<DataPoint> data) {
    final plot = Plot(
      type: type,
      title: title.text.trim(),
      data: _plotData(data.map((d) => d.value).toList()),
    );
    // Mermaid accepts labels on the points of a bar series and ignores them.
    if (type == 'line' && data.any((d) => d.label.trim().isNotEmpty)) {
      plot.pointLabels = data.map((d) => d.label.trim()).toList();
    }
    plots.add(plot);
  }

  void setLineData(XyText title, List<DataPoint> data) {
    _addPlot('line', title, data);
  }

  void setBarData(XyText title, List<DataPoint> data) {
    _addPlot('bar', title, data);
  }

  void setDiagramTitle(String text) {
    title = text;
  }

  void setAccTitle(String text) {
    accTitle = text.replaceFirst(_leadSpacesRe, '');
  }

  void setAccDescription(String text) {
    accDescr = text.replaceAll(_newlineSpacesRe, '\n');
  }
}
