// Upstream: src/diagrams/mindmap/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<MindmapModel> mindmap = Diagram<MindmapModel>(
  type: 'mindmap',
  math: true,
  parse: (source, config, title, lineOffset, limits) {
    final db = MindmapDb()..title = title;
    parseMindmap(source, db);
    return db;
  },
  render: renderMindmap,
);
