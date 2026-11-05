// Upstream: src/diagrams/railroad/index.ts

import '../../types.dart';
import 'db.dart';
import 'render.dart';

final Diagram<RailroadDb> railroad = Diagram<RailroadDb>(
  type: 'railroad',
  parse: (source, config, title, lineOffset, limits) =>
      parseRailroad(source, title),
  render: renderRailroad,
);
