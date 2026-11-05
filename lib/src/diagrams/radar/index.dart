// Upstream: src/diagrams/radar/index.ts

import '../../types.dart';
import 'model.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<RadarModel> radar = Diagram<RadarModel>(
  type: 'radar',
  parse: (source, config, title, lineOffset, limits) =>
      buildRadar(parseRadar(source), title),
  render: renderRadar,
);
