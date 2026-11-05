// Upstream: src/diagrams/cynefin/index.ts

import '../../types.dart';
import 'model.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<CynefinModel> cynefin = Diagram<CynefinModel>(
  type: 'cynefin',
  parse: (source, config, title, lineOffset, limits) =>
      buildCynefin(parseCynefin(source), title),
  render: renderCynefin,
);
