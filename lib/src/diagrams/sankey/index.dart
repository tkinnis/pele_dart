// Upstream: src/diagrams/sankey/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<SankeyDb> sankey = Diagram<SankeyDb>(
  type: 'sankey',
  parse: (source, config, title, lineOffset, limits) {
    final db = SankeyDb();
    if (title != null && title.isNotEmpty) db.title = title;
    parseSankey(prepareTextForParsing(source), db, source);
    return db;
  },
  render: renderSankey,
);
