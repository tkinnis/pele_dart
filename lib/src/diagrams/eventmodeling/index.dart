// Upstream: src/diagrams/eventmodeling/index.ts

import '../../types.dart';
import 'model.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<EventModelingModel> eventmodeling = Diagram<EventModelingModel>(
  type: 'eventmodeling',
  keepComments: true,
  parse: (source, config, title, lineOffset, limits) =>
      buildEventModel(parseEventModel(source), title),
  render: renderEventModel,
);
