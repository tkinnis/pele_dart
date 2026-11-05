// Upstream: src/diagrams/ishikawa/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<IshikawaDb> ishikawa = Diagram<IshikawaDb>(
  type: 'ishikawa',
  parse: (source, config, title, lineOffset, limits) {
    final db = IshikawaDb();
    db.title = title;
    parseIshikawa(source, db);
    return db;
  },
  render: renderIshikawa,
);
