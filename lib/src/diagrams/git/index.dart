// Upstream: src/diagrams/git/index.ts

import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<GitModel> gitGraph = Diagram<GitModel>(
  type: 'gitGraph',
  parse: (source, config, title, lineOffset, limits) =>
      buildGit(parseGit(source), config, title),
  render: renderGit,
);
