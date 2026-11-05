// Upstream: src/diagrams/usecase/index.ts

import '../../types.dart';
import 'parser.dart';
import 'render.dart';
import 'types.dart';

export 'db.dart';
export 'graph.dart';
export 'json.dart';
export 'lexer.dart';
export 'parser.dart';
export 'render.dart';
export 'tokens.dart';
export 'types.dart';

final Diagram<UsecaseModel> usecase = Diagram<UsecaseModel>(
  type: 'usecase',
  math: true,
  parse: (source, config, title, lineOffset, limits) =>
      parseUsecase(source, title),
  render: renderUsecase,
);
