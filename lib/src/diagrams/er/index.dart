// Upstream: src/diagrams/er/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<ErDb> er = Diagram<ErDb>(
  type: 'er',
  math: true,
  parse: (source, config, title, lineOffset, limits) {
    final db = ErDb();
    if (title != null && title.isNotEmpty) db.title = title;
    parseEr(source, db);
    return db;
  },
  render: renderEr,
);
