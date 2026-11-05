// Upstream: src/diagrams/xychart/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<XyChartDb> xychart = Diagram<XyChartDb>(
  type: 'xychart',
  section: 'xyChart',
  parse: (source, config, title, lineOffset, limits) {
    final db = XyChartDb();
    db.title = title;
    parseXyChart(source, db);
    return db;
  },
  render: renderXyChart,
);
