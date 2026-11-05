// Upstream: src/diagrams/treeview/index.ts

import '../../types.dart';
import 'model.dart';
import 'render.dart';

final Diagram<TreeViewModel> treeView = Diagram<TreeViewModel>(
  type: 'treeView',
  parse: (source, config, title, lineOffset, limits) =>
      buildTreeView(readTreeView(source), title),
  render: renderTreeView,
);
