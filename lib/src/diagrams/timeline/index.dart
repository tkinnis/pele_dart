// Upstream: src/diagrams/timeline/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

export 'db.dart';
export 'lexer.dart';
export 'parser.dart';
export 'render.dart';

final Diagram<TimelineModel> timeline = Diagram<TimelineModel>(
  type: 'timeline',
  parse: (source, config, title, lineOffset, limits) {
    final db = TimelineDb();
    db.title = title;
    parseTimeline(source, db);
    return db;
  },
  render: renderTimeline,
);
