// Upstream: src/diagrams/c4/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<C4Db> c4 = Diagram<C4Db>(
  type: 'c4',
  parse: (source, config, title, lineOffset, limits) {
    final db = C4Db();
    if (title != null && title.isNotEmpty) db.title = title;
    parseC4(source, db);
    return db;
  },
  render: renderC4,
);
