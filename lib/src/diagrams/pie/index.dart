// Upstream: src/diagrams/pie/index.ts

import '../../types.dart';
import 'model.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<PieModel> pie = Diagram<PieModel>(
  type: 'pie',
  parse: (source, config, title, lineOffset, limits) =>
      buildPie(parsePie(source), title),
  render: renderPie,
);
