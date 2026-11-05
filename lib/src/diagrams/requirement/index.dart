// Upstream: src/diagrams/requirement/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<RequirementDb> requirement = Diagram<RequirementDb>(
  type: 'requirement',
  math: true,
  parse: (source, config, title, lineOffset, limits) {
    final db = RequirementDb();
    if (title != null && title.isNotEmpty) db.title = title;
    parseRequirement(source, db);
    return db;
  },
  render: renderRequirement,
);
