// Upstream: src/diagrams/sequence/index.ts

import '../../preprocess.dart';
import '../../types.dart';
import 'db.dart';
import 'parser.dart';
import 'render.dart';

final Diagram<SeqDb> sequence = Diagram<SeqDb>(
  type: 'sequence',
  math: true,
  parse: (source, config, title, lineOffset, limits) {
    final seq = asConfig(config['sequence']);
    final db = SeqDb(
      SeqDbOptions(
        wrap: config['wrap'] is bool ? config['wrap'] as bool : null,
        sequenceWrap: seq['wrap'] == true,
      ),
    );
    if (title != null && title.isNotEmpty) db.setDiagramTitle(title);
    parseSequence(source, db);
    return db;
  },
  render: renderSequence,
);
