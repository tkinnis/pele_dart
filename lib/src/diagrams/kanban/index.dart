// Upstream: src/diagrams/kanban/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<KanbanModel> kanban = Diagram<KanbanModel>(
  type: 'kanban',
  math: true,
  parse: (source, config, title, lineOffset, limits) {
    final db = KanbanDb();
    db.title = title;
    parseKanban(source, db);
    return db;
  },
  render: renderKanban,
);
