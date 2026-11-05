// Upstream: src/diagrams/packet/index.ts

import '../../types.dart';
import 'model.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<PacketModel> packet = Diagram<PacketModel>(
  type: 'packet',
  parse: (source, config, title, lineOffset, limits) =>
      buildPacket(parsePacket(source), config, title),
  render: renderPacket,
);
