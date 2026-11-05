// Upstream: src/diagrams/timeline/parser.ts

import '../../errors.dart';
import 'db.dart';
import 'lexer.dart';

const String _statement =
    "'EOF', 'SPACE', 'NEWLINE', 'title', 'acc_title', 'acc_descr', 'acc_descr_multiline_value', 'section', 'period', 'event'";

void parseTimeline(String src, TimelineDb db) {
  final tok = tokenize(src);
  final types = tok.types;
  final texts = tok.texts;
  final starts = tok.starts;

  Never fail(int i, String expected) {
    final got = types[i] == T.END ? '1' : TOKEN_NAMES[types[i]];
    throw syntaxError(
      'timeline',
      src,
      starts[i],
      "Expecting $expected, got '$got'",
    );
  }

  final head = types[0];
  if (head != T.timeline && head != T.timeline_lr && head != T.timeline_td) {
    fail(0, "'timeline', 'timeline_lr', 'timeline_td'");
  }
  if (head != T.timeline) {
    db.setDirection(head == T.timeline_lr ? 'LR' : 'TD');
  }

  for (var i = 1; ; i++) {
    final text = texts[i];
    switch (types[i]) {
      case T.NEWLINE:
        break;
      case T.title:
        db.getCommonDb().setDiagramTitle(text.substring(6));
        break;
      case T.acc_title:
        db.getCommonDb().setAccTitle(texts[++i].trim());
        break;
      case T.acc_descr:
        db.getCommonDb().setAccDescription(texts[++i].trim());
        break;
      case T.acc_descr_multiline_value:
        db.getCommonDb().setAccDescription(text.trim());
        break;
      case T.section:
        db.addSection(text.substring(8));
        break;
      case T.period:
        db.addTask(text, 0, '');
        break;
      case T.event:
        db.addEvent(text.substring(2));
        break;
      case T.EOF:
        return;
      default:
        fail(i, _statement);
    }
  }
}
