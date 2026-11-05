// Upstream: src/diagrams/wardley/index.ts

import '../../types.dart';
import 'model.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<WardleyModel> wardley = Diagram<WardleyModel>(
  type: 'wardley',
  section: 'wardley-beta',
  parse: (source, config, title, lineOffset, limits) =>
      buildWardley(parseWardley(source), title),
  render: renderWardley,
);
