// Upstream: src/diagrams/journey/parser.ts

import '../../errors.dart';
import 'db.dart';
import 'lexer.dart';

const String _statement =
    "'EOF', 'SPACE', 'NEWLINE', 'title', 'acc_title', 'acc_descr', 'acc_descr_multiline_value', 'section', 'taskName'";

void parseJourney(String src, JourneyDb db) {
  final tok = tokenize(src);
  final types = tok.types;
  final texts = tok.texts;
  final starts = tok.starts;

  Never fail(int i, String expected) {
    final got = types[i] == T.END ? '1' : TOKEN_NAMES[types[i]];
    throw syntaxError(
      'journey',
      src,
      starts[i],
      "Expecting $expected, got '$got'",
    );
  }

  if (types[0] != T.journey) fail(0, "'journey'");

  for (var i = 1; ; i++) {
    final text = texts[i];
    switch (types[i]) {
      case T.NEWLINE:
        break;
      case T.title:
        db.setDiagramTitle(text.substring(6));
        break;
      case T.acc_title:
        db.setAccTitle(texts[++i].trim());
        break;
      case T.acc_descr:
        db.setAccDescription(texts[++i].trim());
        break;
      case T.acc_descr_multiline_value:
        db.setAccDescription(text.trim());
        break;
      case T.section:
        db.addSection(text.substring(8));
        break;
      case T.taskName:
        if (types[++i] != T.taskData) fail(i, "'taskData'");
        db.addTask(text, texts[i]);
        break;
      case T.EOF:
        return;
      default:
        fail(i, _statement);
    }
  }
}
