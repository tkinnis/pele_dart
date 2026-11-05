// Upstream: src/diagrams/state/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<StateDb> state = Diagram<StateDb>(
  type: 'state',
  math: true,
  parse: (source, config, title, lineOffset, limits) {
    final db = StateDb();
    if (title != null && title.isNotEmpty) db.title = title;
    parseState(source, db);
    return db;
  },
  render: renderState,
);
