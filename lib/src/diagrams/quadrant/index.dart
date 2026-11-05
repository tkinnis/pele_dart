// Upstream: src/diagrams/quadrant/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<QuadrantDb> quadrantChart = Diagram<QuadrantDb>(
  type: 'quadrantChart',
  parse: (source, config, title, lineOffset, limits) {
    final db = QuadrantDb();
    db.title = title;
    parseQuadrant(source, db);
    return db;
  },
  render: renderQuadrant,
);
