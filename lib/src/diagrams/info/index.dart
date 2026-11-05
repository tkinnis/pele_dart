// Upstream: src/diagrams/info/index.ts

import '../../types.dart';
import 'model.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<InfoModel> info = Diagram<InfoModel>(
  type: 'info',
  parse: (source, config, title, lineOffset, limits) =>
      buildInfo(parseInfo(source), title),
  render: renderInfo,
);
