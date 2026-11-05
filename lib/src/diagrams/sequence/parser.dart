// Upstream: src/diagrams/sequence/parser.ts

import 'dart:typed_data';

import '../../errors.dart';
import 'lexer.dart';
import 'tokens.dart';
import 'types.dart';

/// The calls Mermaid's grammar makes on its `yy` object.
abstract interface class SeqBuilder {
  void apply(SeqItem doc);
  SeqText parseMessage(String str);
  SeqBoxData parseBoxData(String str);
  void setDiagramTitle(String text);
  void setAccTitle(String text);
  void setAccDescription(String text);
}

final Int8List _SIGNAL = _buildSignal();

Int8List _buildSignal() {
  final out = Int8List(T.STICK_ARROW_BOTTOM_REVERSE_DOTTED + 1);
  out.fillRange(0, out.length, -1);
  out[T.SOLID_OPEN_ARROW] = LINETYPE.SOLID_OPEN;
  out[T.DOTTED_OPEN_ARROW] = LINETYPE.DOTTED_OPEN;
  out[T.SOLID_ARROW] = LINETYPE.SOLID;
  out[T.DOTTED_ARROW] = LINETYPE.DOTTED;
  out[T.BIDIRECTIONAL_SOLID_ARROW] = LINETYPE.BIDIRECTIONAL_SOLID;
  out[T.BIDIRECTIONAL_DOTTED_ARROW] = LINETYPE.BIDIRECTIONAL_DOTTED;
  out[T.SOLID_CROSS] = LINETYPE.SOLID_CROSS;
  out[T.DOTTED_CROSS] = LINETYPE.DOTTED_CROSS;
  out[T.SOLID_POINT] = LINETYPE.SOLID_POINT;
  out[T.DOTTED_POINT] = LINETYPE.DOTTED_POINT;
  out[T.SOLID_ARROW_TOP] = LINETYPE.SOLID_TOP;
  out[T.SOLID_ARROW_BOTTOM] = LINETYPE.SOLID_BOTTOM;
  out[T.STICK_ARROW_TOP] = LINETYPE.STICK_TOP;
  out[T.STICK_ARROW_BOTTOM] = LINETYPE.STICK_BOTTOM;
  out[T.SOLID_ARROW_TOP_DOTTED] = LINETYPE.SOLID_TOP_DOTTED;
  out[T.SOLID_ARROW_BOTTOM_DOTTED] = LINETYPE.SOLID_BOTTOM_DOTTED;
  out[T.STICK_ARROW_TOP_DOTTED] = LINETYPE.STICK_TOP_DOTTED;
  out[T.STICK_ARROW_BOTTOM_DOTTED] = LINETYPE.STICK_BOTTOM_DOTTED;
  out[T.SOLID_ARROW_TOP_REVERSE] = LINETYPE.SOLID_ARROW_TOP_REVERSE;
  out[T.SOLID_ARROW_BOTTOM_REVERSE] = LINETYPE.SOLID_ARROW_BOTTOM_REVERSE;
  out[T.STICK_ARROW_TOP_REVERSE] = LINETYPE.STICK_ARROW_TOP_REVERSE;
  out[T.STICK_ARROW_BOTTOM_REVERSE] = LINETYPE.STICK_ARROW_BOTTOM_REVERSE;
  out[T.SOLID_ARROW_TOP_REVERSE_DOTTED] =
      LINETYPE.SOLID_ARROW_TOP_REVERSE_DOTTED;
  out[T.SOLID_ARROW_BOTTOM_REVERSE_DOTTED] =
      LINETYPE.SOLID_ARROW_BOTTOM_REVERSE_DOTTED;
  out[T.STICK_ARROW_TOP_REVERSE_DOTTED] =
      LINETYPE.STICK_ARROW_TOP_REVERSE_DOTTED;
  out[T.STICK_ARROW_BOTTOM_REVERSE_DOTTED] =
      LINETYPE.STICK_ARROW_BOTTOM_REVERSE_DOTTED;
  return out;
}

abstract final class _K {
  static const int Top = 0;
  static const int Box = 1;
  static const int Loop = 2;
  static const int Rect = 3;
  static const int Opt = 4;
  static const int Break = 5;
  static const int Alt = 6;
  static const int Par = 7;
  static const int Critical = 8;
}

class _Frame {
  _Frame({
    required this.kind,
    required this.text,
    required this.startType,
    required this.list,
    this.sections,
  });

  final int kind;
  final String text;
  final int startType;

  /// The current section's statements. Slot 0 of a block's first section is kept for its start entry.
  List<SeqItem> list;

  /// Finished sections, each followed by the divider text that ended it.
  List<Object>? sections;
}

final Int8List _BLOCK = _buildBlock();

Int8List _buildBlock() {
  final out = Int8List(T.STICK_ARROW_BOTTOM_REVERSE_DOTTED + 1);
  out.fillRange(0, out.length, -1);
  out[T.loop] = _K.Loop;
  out[T.rect] = _K.Rect;
  out[T.opt] = _K.Opt;
  out[T.break_] = _K.Break;
  out[T.alt] = _K.Alt;
  out[T.par] = _K.Par;
  out[T.par_over] = _K.Par;
  out[T.critical] = _K.Critical;
  out[T.box] = _K.Box;
  return out;
}

const String _SIGNAL_TOKENS =
    "'SOLID_OPEN_ARROW', 'DOTTED_OPEN_ARROW', 'SOLID_ARROW', 'DOTTED_ARROW', 'SOLID_CROSS', 'DOTTED_CROSS', 'SOLID_POINT', 'DOTTED_POINT'";

void parseSequence(String src, SeqBuilder db) {
  final tokenized = tokenize(src);
  final types = tokenized.types;
  final texts = tokenized.texts;
  final starts = tokenized.starts;
  var i = 0;

  Never fail(String expected) {
    final t = types[i];
    if (t == T.ERROR) throw syntaxError('sequence', src, starts[i], '', true);
    throw syntaxError(
      'sequence',
      src,
      starts[i],
      "Expecting $expected, got '${TOKEN_NAMES[t]}'",
    );
  }

  String expect(int type) {
    if (types[i] != type) fail("'${TOKEN_NAMES[type]}'");
    return texts[i++];
  }

  SeqStatement actor() {
    final t = types[i];
    if (t != T.ACTOR && t != T.link) fail("'ACTOR'");
    return SeqStatement(type: 'addParticipant', actor: texts[i++]);
  }

  SeqText text2() => db.parseMessage(expect(T.TXT).trim().substring(1));

  SeqStatement participant() {
    final t = types[i++];
    if (t == T.destroy) {
      final node = actor();
      expect(T.NEWLINE);
      node.type = 'destroyParticipant';
      return node;
    }
    final node = actor();
    if (types[i] == T.CONFIG_START && types[i - 1] == T.ACTOR) {
      i++;
      final content = expect(T.CONFIG_CONTENT);
      expect(T.CONFIG_END);
      node.config = content.trim();
    }
    node.draw = t == T.participant ? 'participant' : 'actor';
    if (types[i] == T.AS) {
      i++;
      final alias = expect(T.restOfLine);
      expect(T.NEWLINE);
      node.description = db.parseMessage(alias);
    } else if (types[i] == T.NEWLINE) {
      i++;
    } else {
      fail("'AS', 'NEWLINE'");
    }
    return node;
  }

  SeqItem signal(SeqStatement from) {
    var centralFrom = false;
    if (types[i] == T.CENTRAL) {
      centralFrom = true;
      i++;
    }
    final signalType = _SIGNAL[types[i]];
    if (signalType < 0) fail(_SIGNAL_TOKENS);
    i++;
    final mark = types[i];
    if (mark == T.CENTRAL ||
        (!centralFrom && (mark == T.PLUS || mark == T.MINUS))) {
      i++;
    }
    final to = actor();
    final msg = text2();
    final message = SeqStatement(
      type: 'addMessage',
      from: from.actor as String,
      to: to.actor as String,
      signalType: signalType,
      msg: msg,
    );
    final out = <SeqItem>[from, to, message];
    if (centralFrom) {
      final dual = mark == T.CENTRAL;
      message.activate = dual;
      message.centralConnection = dual
          ? LINETYPE.CENTRAL_CONNECTION_DUAL
          : LINETYPE.CENTRAL_CONNECTION_REVERSE;
      if (dual) {
        out.add(
          SeqStatement(
            type: 'centralConnection',
            signalType: LINETYPE.CENTRAL_CONNECTION,
            actor: to.actor,
          ),
        );
      }
      out.add(
        SeqStatement(
          type: 'centralConnectionReverse',
          signalType: LINETYPE.CENTRAL_CONNECTION_REVERSE,
          actor: from.actor,
        ),
      );
    } else if (mark == T.PLUS) {
      message.activate = true;
      out.add(
        SeqStatement(
          type: 'activeStart',
          signalType: LINETYPE.ACTIVE_START,
          actor: to.actor,
        ),
      );
    } else if (mark == T.MINUS) {
      out.add(
        SeqStatement(
          type: 'activeEnd',
          signalType: LINETYPE.ACTIVE_END,
          actor: from.actor,
        ),
      );
    } else if (mark == T.CENTRAL) {
      message.activate = true;
      message.centralConnection = LINETYPE.CENTRAL_CONNECTION;
      out.add(
        SeqStatement(
          type: 'centralConnection',
          signalType: LINETYPE.CENTRAL_CONNECTION,
          actor: to.actor,
        ),
      );
    }
    return out;
  }

  SeqItem menu(String type) {
    i++;
    final who = actor();
    return <SeqItem>[
      who,
      SeqStatement(type: type, actor: who.actor, text: text2()),
    ];
  }

  SeqItem note() {
    i++;
    final t = types[i];
    if (t == T.over) {
      i++;
      final first = actor();
      SeqItem who = first;
      var ids = <String>[first.actor as String, first.actor as String];
      if (types[i] == T.COMMA) {
        i++;
        final second = actor();
        who = <SeqItem>[first, second];
        ids = <String>[first.actor as String, second.actor as String];
      }
      return <SeqItem>[
        who,
        SeqStatement(
          type: 'addNote',
          placement: PLACEMENT.OVER,
          actor: ids,
          text: text2(),
        ),
      ];
    }
    if (t != T.left_of && t != T.right_of) {
      fail("'over', 'left_of', 'right_of'");
    }
    i++;
    final who = actor();
    final placement = t == T.left_of ? PLACEMENT.LEFTOF : PLACEMENT.RIGHTOF;
    return <SeqItem>[
      who,
      SeqStatement(
        type: 'addNote',
        placement: placement,
        actor: who.actor,
        text: text2(),
      ),
    ];
  }

  SeqStatement autonumber() {
    i++;
    final node = SeqStatement(
      type: 'sequenceIndex',
      sequenceVisible: true,
      signalType: LINETYPE.AUTONUMBER,
    );
    if (types[i] == T.NUM) {
      node.sequenceIndex = double.parse(texts[i++]);
      node.sequenceIndexStep = types[i] == T.NUM
          ? double.parse(texts[i++])
          : 1.0;
    } else if (types[i] == T.off) {
      i++;
      node.sequenceVisible = false;
    }
    if (types[i] != T.NEWLINE) fail("'NEWLINE', 'NUM', 'off'");
    i++;
    return node;
  }

  // Folds the sections of an alt, par, or critical block from the last one back, as the grammar's
  // right recursion does, so the texts reach the model builder in the same order.
  List<SeqItem> fold(_Frame frame, String divider, String key, int signalType) {
    var list = frame.list;
    final sections = frame.sections;
    if (sections != null) {
      for (var k = sections.length - 2; k >= 0; k -= 2) {
        final head = SeqStatement(type: divider, signalType: signalType);
        final parsed = db.parseMessage(sections[k + 1] as String);
        if (key == 'altText') {
          head.altText = parsed;
        } else if (key == 'parText') {
          head.parText = parsed;
        } else {
          head.optionText = parsed;
        }
        list = <SeqItem>[...(sections[k] as List<SeqItem>), head, list];
      }
    }
    return list;
  }

  List<SeqItem> close(_Frame frame) {
    final text = frame.text;
    var list = frame.list;
    switch (frame.kind) {
      case _K.Box:
        list[0] = SeqStatement(
          type: 'boxStart',
          boxData: db.parseBoxData(text),
        );
        list.add(SeqStatement(type: 'boxEnd', boxText: text));
        break;
      case _K.Loop:
        list[0] = SeqStatement(
          type: 'loopStart',
          loopText: db.parseMessage(text),
          signalType: LINETYPE.LOOP_START,
        );
        list.add(
          SeqStatement(
            type: 'loopEnd',
            loopText: text,
            signalType: LINETYPE.LOOP_END,
          ),
        );
        break;
      case _K.Rect:
        list[0] = SeqStatement(
          type: 'rectStart',
          color: db.parseMessage(text),
          signalType: LINETYPE.RECT_START,
        );
        list.add(
          SeqStatement(
            type: 'rectEnd',
            color: db.parseMessage(text),
            signalType: LINETYPE.RECT_END,
          ),
        );
        break;
      case _K.Opt:
        list[0] = SeqStatement(
          type: 'optStart',
          optText: db.parseMessage(text),
          signalType: LINETYPE.OPT_START,
        );
        list.add(
          SeqStatement(
            type: 'optEnd',
            optText: db.parseMessage(text),
            signalType: LINETYPE.OPT_END,
          ),
        );
        break;
      case _K.Break:
        list[0] = SeqStatement(
          type: 'breakStart',
          breakText: db.parseMessage(text),
          signalType: LINETYPE.BREAK_START,
        );
        list.add(
          SeqStatement(
            type: 'breakEnd',
            optText: db.parseMessage(text),
            signalType: LINETYPE.BREAK_END,
          ),
        );
        break;
      case _K.Alt:
        list = fold(frame, 'else', 'altText', LINETYPE.ALT_ELSE);
        list[0] = SeqStatement(
          type: 'altStart',
          altText: db.parseMessage(text),
          signalType: LINETYPE.ALT_START,
        );
        list.add(SeqStatement(type: 'altEnd', signalType: LINETYPE.ALT_END));
        break;
      case _K.Par:
        list = fold(frame, 'and', 'parText', LINETYPE.PAR_AND);
        list[0] = SeqStatement(
          type: 'parStart',
          parText: db.parseMessage(text),
          signalType: frame.startType,
        );
        list.add(SeqStatement(type: 'parEnd', signalType: LINETYPE.PAR_END));
        break;
      default:
        list = fold(frame, 'option', 'optionText', LINETYPE.CRITICAL_OPTION);
        list[0] = SeqStatement(
          type: 'criticalStart',
          criticalText: db.parseMessage(text),
          signalType: LINETYPE.CRITICAL_START,
        );
        list.add(
          SeqStatement(type: 'criticalEnd', signalType: LINETYPE.CRITICAL_END),
        );
    }
    return list;
  }

  while (types[i] == T.NEWLINE) {
    i++;
  }
  expect(T.SD);

  final stack = <_Frame>[];
  var frame = _Frame(
    kind: _K.Top,
    text: '',
    startType: 0,
    list: <SeqItem>[],
    sections: null,
  );

  while (true) {
    final t = types[i];
    final list = frame.list;
    if (frame.kind == _K.Box) {
      if (t == T.participant || t == T.participant_actor || t == T.destroy) {
        list.add(participant());
      } else if (t == T.NEWLINE) {
        list.add(<SeqItem>[]);
        i++;
      } else if (t == T.end) {
        i++;
        final done = close(frame);
        frame = stack.removeLast();
        frame.list.add(done);
      } else {
        fail("'end', 'NEWLINE', 'participant', 'participant_actor', 'destroy'");
      }
      continue;
    }
    switch (t) {
      case T.NEWLINE:
      case T.INVALID:
        list.add(<SeqItem>[]);
        i++;
        break;
      case T.participant:
      case T.participant_actor:
      case T.destroy:
        list.add(participant());
        break;
      case T.create:
        i++;
        final next = types[i];
        if (next != T.participant &&
            next != T.participant_actor &&
            next != T.destroy) {
          fail("'participant', 'participant_actor', 'destroy'");
        }
        final node = participant();
        node.type = 'createParticipant';
        list.add(node);
        break;
      case T.ACTOR:
        list.add(signal(actor()));
        expect(T.NEWLINE);
        break;
      case T.link:
        final next = types[i + 1];
        list.add(
          next == T.ACTOR || next == T.link
              ? menu('addALink')
              : signal(actor()),
        );
        expect(T.NEWLINE);
        break;
      case T.links:
        list.add(menu('addLinks'));
        expect(T.NEWLINE);
        break;
      case T.properties:
        list.add(menu('addProperties'));
        expect(T.NEWLINE);
        break;
      case T.details:
        list.add(menu('addDetails'));
        expect(T.NEWLINE);
        break;
      case T.note:
        list.add(note());
        expect(T.NEWLINE);
        break;
      case T.autonumber:
        list.add(autonumber());
        break;
      case T.activate:
      case T.deactivate:
        i++;
        final who = actor();
        expect(T.NEWLINE);
        list.add(
          t == T.activate
              ? SeqStatement(
                  type: 'activeStart',
                  signalType: LINETYPE.ACTIVE_START,
                  actor: who.actor,
                )
              : SeqStatement(
                  type: 'activeEnd',
                  signalType: LINETYPE.ACTIVE_END,
                  actor: who.actor,
                ),
        );
        break;
      case T.title:
      case T.legacy_title:
        final title = texts[i++].substring(t == T.title ? 6 : 7);
        db.setDiagramTitle(title);
        list.add(title);
        break;
      case T.acc_title:
        i++;
        final value = expect(T.acc_title_value).trim();
        db.setAccTitle(value);
        list.add(value);
        break;
      case T.acc_descr:
        i++;
        final value = expect(T.acc_descr_value).trim();
        db.setAccDescription(value);
        list.add(value);
        break;
      case T.acc_descr_multiline_value:
        final value = texts[i++].trim();
        db.setAccDescription(value);
        list.add(value);
        break;
      case T.loop:
      case T.rect:
      case T.opt:
      case T.break_:
      case T.alt:
      case T.par:
      case T.par_over:
      case T.critical:
      case T.box:
        i++;
        final text = expect(T.restOfLine);
        stack.add(frame);
        frame = _Frame(
          kind: _BLOCK[t],
          text: text,
          startType: t == T.par_over
              ? LINETYPE.PAR_OVER_START
              : LINETYPE.PAR_START,
          list: <SeqItem>[<SeqItem>[]],
          sections: null,
        );
        break;
      case T.else_:
      case T.and:
      case T.option:
        final kind = frame.kind;
        if (kind !=
            (t == T.else_ ? _K.Alt : (t == T.and ? _K.Par : _K.Critical))) {
          fail("'end'");
        }
        i++;
        final text = expect(T.restOfLine);
        (frame.sections ??= <Object>[]).addAll(<Object>[list, text]);
        frame.list = <SeqItem>[];
        break;
      case T.end:
        if (frame.kind == _K.Top) fail("'NEWLINE', 'EOF'");
        i++;
        final done = close(frame);
        frame = stack.removeLast();
        frame.list.add(done);
        break;
      case T.END:
        if (frame.kind != _K.Top) fail("'end'");
        db.apply(list);
        return;
      default:
        fail("'NEWLINE', 'ACTOR', 'participant', 'note', 'end'");
    }
  }
}
