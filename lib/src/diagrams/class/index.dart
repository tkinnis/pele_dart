// Upstream: src/diagrams/class/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<ClassDb> classDiagram = Diagram<ClassDb>(
  type: 'class',
  math: true,
  parse: (source, config, title, lineOffset, limits) {
    final db = ClassDb();
    if (title != null && title.isNotEmpty) db.title = title;
    parseClassDiagram(source, db);
    return db;
  },
  render: renderClass,
);
