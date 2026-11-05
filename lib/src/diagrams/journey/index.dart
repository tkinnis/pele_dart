// Upstream: src/diagrams/journey/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

export 'db.dart';
export 'lexer.dart';
export 'parser.dart';
export 'render.dart';

final Diagram<JourneyModel> journey = Diagram<JourneyModel>(
  type: 'journey',
  parse: (source, config, title, lineOffset, limits) {
    final db = JourneyDb();
    db.title = title;
    parseJourney(source, db);
    return db;
  },
  render: renderJourney,
);
