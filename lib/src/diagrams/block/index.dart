// Upstream: src/diagrams/block/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<BlockDb> block = Diagram<BlockDb>(
  type: 'block',
  math: true,
  parse: (source, config, title, lineOffset, limits) {
    final db = BlockDb();
    db.title = title;
    parseBlock(source, db);
    return db;
  },
  render: renderBlock,
);
