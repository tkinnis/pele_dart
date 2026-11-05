// Upstream: src/diagrams/gantt/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

export 'axis.dart';
export 'dates.dart';
export 'db.dart';
export 'lexer.dart';
export 'parser.dart';
export 'render.dart';
export 'tokens.dart';
export 'types.dart';

final Diagram<GanttDb> gantt = Diagram<GanttDb>(
  type: 'gantt',
  parse: (source, config, title, lineOffset, limits) {
    final db = GanttDb();
    if (title != null && title.isNotEmpty) db.title = title;
    final ganttCfg = config['gantt'];
    final mode = ganttCfg is Map ? ganttCfg['displayMode'] : null;
    if (mode is String) db.displayMode = mode;
    parseGantt(source, db);
    return db;
  },
  render: renderGantt,
);
