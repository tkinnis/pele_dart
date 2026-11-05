// Upstream: src/diagrams/treemap/index.ts

import '../../types.dart';
import 'model.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<TreemapModel> treemap = Diagram<TreemapModel>(
  type: 'treemap',
  parse: (source, config, title, lineOffset, limits) =>
      buildTreemap(parseTreemap(source), title),
  render: renderTreemap,
);
