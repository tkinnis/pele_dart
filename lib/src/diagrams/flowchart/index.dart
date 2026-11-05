// Upstream: src/diagrams/flowchart/index.ts

import '../../preprocess.dart';
import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<FlowDb> flowchart = Diagram<FlowDb>(
  type: 'flowchart',
  math: true,
  parse: (source, config, title, lineOffset, limits) {
    final flow = asConfig(config['flowchart']);
    final db = FlowDb(
      FlowDbOptions(
        inheritDir: flow['inheritDir'] == true,
        maxEdges: limits.maxEdges,
      ),
    );
    if (title != null && title.isNotEmpty) db.title = title;
    parseFlowchart(source, db);
    return db;
  },
  render: renderFlowchart,
);
