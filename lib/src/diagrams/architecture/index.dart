// Upstream: src/diagrams/architecture/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<ArchitectureDb> architecture = Diagram<ArchitectureDb>(
  type: 'architecture',
  parse: (source, config, title, lineOffset, limits) {
    final db = ArchitectureDb();
    if (title != null && title.isNotEmpty) db.title = title;
    populate(parseArchitecture(source), db);
    return db;
  },
  render: renderArchitecture,
);
