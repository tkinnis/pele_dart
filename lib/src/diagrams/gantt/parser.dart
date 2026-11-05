// Upstream: src/diagrams/gantt/parser.ts

import 'dart:typed_data';

import '../../errors.dart';
import '../../util/math_js.dart';
import 'lexer.dart';
import 'tokens.dart';

// The calls the grammar's actions make, under Mermaid's names.
abstract interface class GanttBuilder {
  void setDateFormat(String txt);
  void enableInclusiveEndDates();
  // ignore: non_constant_identifier_names
  void TopAxis();
  void setAxisFormat(String txt);
  void setTickInterval(String txt);
  void setExcludes(String txt);
  void setIncludes(String txt);
  void setTodayMarker(String txt);
  void setWeekday(String txt);
  void setWeekend(String txt);
  void setDiagramTitle(String txt);
  void setAccTitle(String txt);
  void setAccDescription(String txt);
  void addSection(String txt);
  void addTask(String descr, String data);
  void setClickEvent(String ids, String functionName, String? functionArgs);
  void setLink(String ids, String link);
}

const List<String> _weekdays = <String>[
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

const String _line =
    "'EOF', 'SPACE', 'NL', 'weekday_monday', 'weekday_tuesday', 'weekday_wednesday', 'weekday_thursday', "
    "'weekday_friday', 'weekday_saturday', 'weekday_sunday', 'weekend_friday', 'weekend_saturday', 'dateFormat', "
    "'inclusiveEndDates', 'topAxis', 'axisFormat', 'tickInterval', 'excludes', 'includes', 'todayMarker', 'title', "
    "'acc_title', 'acc_descr', 'acc_descr_multiline_value', 'section', 'taskTxt', 'click'";

// Tokens that can start a line, which are also the only ones that can follow a complete statement.
final Uint8List _startsLine = () {
  final arr = Uint8List(T.EOF + 1);
  for (var t = T.weekday_monday; t <= T.weekend_saturday; t++) {
    arr[t] = 1;
  }
  for (final t in const <int>[
    T.EOF,
    T.NL,
    T.dateFormat,
    T.inclusiveEndDates,
    T.topAxis,
    T.axisFormat,
    T.tickInterval,
    T.excludes,
    T.includes,
    T.todayMarker,
    T.title,
    T.acc_title,
    T.acc_descr,
    T.acc_descr_multiline_value,
    T.section,
    T.taskTxt,
    T.click,
  ]) {
    arr[t] = 1;
  }
  return arr;
}();

void parseGantt(String src, GanttBuilder db) {
  final tok = tokenize(src);
  final types = tok.types;
  final texts = tok.texts;
  final starts = tok.starts;
  var i = 0;

  Never fail(String expected) {
    final t = types[i];
    throw syntaxError(
      'gantt',
      src,
      starts[i],
      "Expecting $expected, got '${t == T.END ? '1' : TOKEN_NAMES[t]}'",
    );
  }

  bool isLineStarter(int t) =>
      t >= 0 && t < _startsLine.length && _startsLine[t] == 1;

  // Mermaid's parser runs a statement's action only after seeing that the next token can follow it.
  void end([String also = '']) {
    if (!isLineStarter(types[i])) fail(_line + also);
  }

  if (types[i] != T.gantt) fail("'gantt'");
  i++;

  while (true) {
    final t = types[i];
    final text = texts[i];
    if (!isLineStarter(t)) fail(_line);
    i++;
    switch (t) {
      case T.EOF:
        if (types[i] == T.END) return;
        end();
        break;
      case T.NL:
        break;
      case T.dateFormat:
        end();
        db.setDateFormat(sliceJs(text, 11));
        break;
      case T.inclusiveEndDates:
        end();
        db.enableInclusiveEndDates();
        break;
      case T.topAxis:
        end();
        db.TopAxis();
        break;
      case T.axisFormat:
        end();
        db.setAxisFormat(sliceJs(text, 11));
        break;
      case T.tickInterval:
        end();
        db.setTickInterval(sliceJs(text, 13));
        break;
      case T.excludes:
        end();
        db.setExcludes(sliceJs(text, 9));
        break;
      case T.includes:
        end();
        db.setIncludes(sliceJs(text, 9));
        break;
      case T.todayMarker:
        end();
        db.setTodayMarker(sliceJs(text, 12));
        break;
      case T.weekend_friday:
        end();
        db.setWeekend('friday');
        break;
      case T.weekend_saturday:
        end();
        db.setWeekend('saturday');
        break;
      case T.title:
        end();
        db.setDiagramTitle(sliceJs(text, 6));
        break;
      case T.acc_title:
        if (types[i] != T.acc_title_value) fail("'acc_title_value'");
        final value = texts[i++];
        end();
        db.setAccTitle(value.trim());
        break;
      case T.acc_descr:
        if (types[i] != T.acc_descr_value) fail("'acc_descr_value'");
        final value = texts[i++];
        end();
        db.setAccDescription(value.trim());
        break;
      case T.acc_descr_multiline_value:
        end();
        db.setAccDescription(text.trim());
        break;
      case T.section:
        end();
        db.addSection(sliceJs(text, 8));
        break;
      case T.taskTxt:
        if (types[i] != T.taskData) fail("'taskData'");
        final data = texts[i++];
        end();
        db.addTask(text, data);
        break;
      case T.click:
        String? name;
        String? args;
        String? href;
        if (types[i] == T.callbackname) {
          name = texts[i++];
          if (types[i] == T.callbackargs) args = texts[i++];
          if (types[i] == T.href) {
            href = texts[i++];
            end();
          } else {
            end(args == null ? ", 'callbackargs', 'href'" : ", 'href'");
          }
        } else if (types[i] == T.href) {
          href = texts[i++];
          if (types[i] == T.callbackname) {
            name = texts[i++];
            if (types[i] == T.callbackargs) {
              args = texts[i++];
              end();
            } else {
              end(", 'callbackargs'");
            }
          } else {
            end(", 'callbackname'");
          }
        } else {
          fail("'callbackname', 'href'");
        }
        if (name != null) db.setClickEvent(text, name, args);
        if (href != null) db.setLink(text, href);
        break;
      default:
        end();
        db.setWeekday(_weekdays[t - T.weekday_monday]);
    }
  }
}
