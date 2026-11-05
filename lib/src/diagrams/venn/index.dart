// Upstream: src/diagrams/venn/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<VennDb> venn = Diagram<VennDb>(
  type: 'venn',
  parse: (source, config, title, lineOffset, limits) {
    final db = VennDb();
    if (title != null && title.isNotEmpty) db.title = title;
    parseVenn(source, db);
    return db;
  },
  render: renderVenn,
);
