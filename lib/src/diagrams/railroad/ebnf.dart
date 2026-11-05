// Upstream: src/diagrams/railroad/ebnf.ts

import '../../util/math_js.dart';
import '../common/tokens.dart' show Reader, TokenType;
import 'common.dart';
import 'types.dart';

// `railroad-ebnf-beta`: EBNF in the W3C and ISO 14977 styles.

abstract final class _T {
  static const int defines = 1;
  static const int equals = 2;
  static const int semicolon = 3;
  static const int bar = 4;
  static const int comma = 5;
  static const int group = 6;
  static const int option = 8;
  static const int repeat = 10;
  static const int question = 12;
  static const int star = 13;
  static const int plus = 14;
  static const int minus = 15;
  static const int title = 16;
  static const int id = 19;
  static const int string = 20;
  static const int special = 21;
}

// A question mark, text with something other than blanks in it and no `?` or `;`, and a question mark.
// Mermaid's pattern looks ahead with two nested runs, which rescans; this reads the text once.
int _specialSequence(String src, int at, int _) {
  if (charCodeAt(src, at) != 63) return -1;
  var solid = false;
  for (var i = at + 1; i < src.length; i++) {
    final c = charCodeAt(src, i);
    if (c == 63) return solid ? i + 1 : -1;
    if (c == 59) return -1;
    solid = solid || !isSpace(c);
  }
  return -1;
}

final TokenType _id = identifier('EBNF_ID');
final TokenType _special = TokenType(
  name: 'EBNF_SPECIAL_SEQUENCE',
  pattern: RegExp(r'\?(?=[^?;]*[^?\s;][^?;]*\?)[^?;]*\?'),
  first: '?',
  scanner: () => _specialSequence,
);
final List<TokenType> _hidden = hiddenTokens('EBNF');
final TokenType _isoComment = TokenType(
  name: 'EBNF_ISO_COMMENT',
  pattern: RegExp(r'\(\*[\s\S]*?\*\)'),
  hidden: true,
  first: '(',
  opener: RegExp(r'\(\*'),
);

final List<TokenType> EBNF_TOKENS = <TokenType>[
  opening('railroad-ebnf-beta', _id),
  literal('::='),
  literal('='),
  literal(';'),
  literal('|'),
  literal(','),
  literal('(', <TokenType>[_isoComment]),
  literal(')'),
  literal('['),
  literal(']'),
  literal('{'),
  literal('}'),
  literal('?', <TokenType>[_special]),
  literal('*'),
  literal('+'),
  literal('-', <TokenType>[_hidden[1]]),
  title(r'[\w-]'),
  ACC_TITLE,
  ACC_DESCR,
  _id,
  quoted('EBNF_STRING'),
  _special,
  ..._hidden,
  TokenType(
    name: 'EBNF_BLOCK_COMMENT',
    pattern: RegExp(r'\/\*[\s\S]*?\*\/'),
    hidden: true,
    first: '/',
    opener: RegExp(r'\/\*'),
  ),
  _isoComment,
];

abstract interface class EbnfPart implements HasParts<EbnfPart> {
  String get $type;
}

class EbnfPrimary implements EbnfPart {
  const EbnfPrimary._({
    required this.$type,
    this.value,
    this.name,
    this.text,
    this.element,
  });

  const EbnfPrimary.terminal(String value)
    : this._($type: 'EbnfTerminal', value: value);

  const EbnfPrimary.nonterminal(String name)
    : this._($type: 'EbnfNonTerminal', name: name);

  const EbnfPrimary.special(String text)
    : this._($type: 'EbnfSpecial', text: text);

  const EbnfPrimary.bracket(String $type, EbnfChoice element)
    : this._($type: $type, element: element);

  @override
  final String $type;
  final String? value;
  final String? name;
  final String? text;
  final EbnfChoice? element;

  @override
  List<EbnfPart> get nodeParts =>
      element != null ? <EbnfPart>[element!] : const <EbnfPart>[];
}

class EbnfPostfix {
  const EbnfPostfix.operator(this.$type, this.operator) : except = null;
  const EbnfPostfix.exception(EbnfPrimary this.except)
    : $type = 'EbnfExceptionPostfix',
      operator = null;

  final String $type;
  final String? operator;
  final EbnfPrimary? except;
}

class EbnfTerm implements EbnfPart {
  EbnfTerm({required this.base, required this.postfixes});

  @override
  final String $type = 'EbnfTerm';
  final EbnfPrimary base;
  final List<EbnfPostfix> postfixes;

  @override
  List<EbnfPart> get nodeParts => <EbnfPart>[
    base,
    for (final p in postfixes)
      if (p.except != null) p.except!,
  ];
}

class EbnfSequence implements EbnfPart {
  EbnfSequence() : elements = <EbnfTerm>[];

  @override
  final String $type = 'EbnfSequence';
  final List<EbnfTerm> elements;

  @override
  List<EbnfPart> get nodeParts => elements;
}

class EbnfChoice implements EbnfPart {
  EbnfChoice() : alternatives = <EbnfSequence>[];

  @override
  final String $type = 'EbnfChoice';
  final List<EbnfSequence> alternatives;

  @override
  List<EbnfPart> get nodeParts => alternatives;
}

class EbnfRule implements RuleNode<EbnfPart> {
  const EbnfRule({required this.name, required this.definition});

  final String $type = 'EbnfRule';
  @override
  final String name;
  @override
  final EbnfChoice definition;
}

typedef EbnfAst = Grammar<EbnfRule>;

// One open bracket, or the rule itself at the bottom of the stack.
class _Frame {
  _Frame({
    required this.choice,
    required this.sequence,
    this.node,
    required this.close,
    required this.except,
  });

  final EbnfChoice choice;
  EbnfSequence sequence;
  EbnfTerm? term;
  // The bracket's node, its closing token, and whether it is the right side of an exception.
  final EbnfPrimary? node;
  final int close;
  final bool except;
}

_Frame _frame(EbnfPrimary? node, EbnfChoice choice, int close, bool except) {
  final sequence = EbnfSequence();
  choice.alternatives.add(sequence);
  return _Frame(
    choice: choice,
    sequence: sequence,
    node: node,
    close: close,
    except: except,
  );
}

const List<String> _brackets = <String>[
  'EbnfGroup',
  'EbnfOptional',
  'EbnfRepetition',
];

EbnfChoice _definition(Reader r) {
  final stack = <_Frame>[];
  var top = _frame(null, EbnfChoice(), -2, false);
  var except = false;
  for (;;) {
    EbnfPrimary primary;
    final kind = r.kind;
    switch (kind) {
      case _T.string:
        primary = EbnfPrimary.terminal(unescape(r.take()));
        break;
      case _T.id:
        primary = EbnfPrimary.nonterminal(r.take());
        break;
      case _T.special:
        {
          final raw = r.take();
          primary = EbnfPrimary.special(
            raw.substring(1, raw.length - 1).trim(),
          );
          break;
        }
      case _T.group:
      case _T.option:
      case _T.repeat:
        {
          r.i++;
          final element = EbnfChoice();
          stack.add(top);
          top = _frame(
            EbnfPrimary.bracket(_brackets[(kind - _T.group) >> 1], element),
            element,
            kind + 1,
            except,
          );
          except = false;
          continue;
        }
      default:
        r.fail('a terminal, a name, or an opening bracket');
    }
    for (;;) {
      if (except) {
        top.term!.postfixes.add(EbnfPostfix.exception(primary));
        except = false;
      } else {
        top.term = EbnfTerm(base: primary, postfixes: <EbnfPostfix>[]);
        top.sequence.elements.add(top.term!);
      }
      final postfixes = top.term!.postfixes;
      for (;;) {
        final k = r.kind;
        if (k == _T.question) {
          postfixes.add(EbnfPostfix.operator('EbnfOptionalPostfix', r.take()));
        } else if (k == _T.star) {
          postfixes.add(
            EbnfPostfix.operator('EbnfZeroOrMorePostfix', r.take()),
          );
        } else if (k == _T.plus) {
          postfixes.add(EbnfPostfix.operator('EbnfOneOrMorePostfix', r.take()));
        } else {
          break;
        }
      }
      final k = r.kind;
      if (k == top.close) {
        r.i++;
        primary = top.node!;
        except = top.except;
        top = stack.removeLast();
        continue;
      }
      if (k == _T.minus) {
        r.i++;
        except = true;
      } else if (k == _T.comma) {
        r.i++;
      } else if (k == _T.bar) {
        r.i++;
        top.sequence = EbnfSequence();
        top.choice.alternatives.add(top.sequence);
      } else if (k != _T.string &&
          k != _T.id &&
          k != _T.special &&
          k != _T.group &&
          k != _T.option &&
          k != _T.repeat) {
        if (stack.isEmpty) return top.choice;
        r.fail("token of type '${EBNF_TOKENS[top.close].name}'");
      }
      break;
    }
  }
}

EbnfAst parseEbnf(String src) {
  return parseGrammar<EbnfRule>(
    src,
    EBNF_TOKENS,
    'RailroadEbnf',
    _T.title,
    unescape,
    (r) {
      final name = r.expect(_T.id);
      if (!r.accept(_T.equals)) r.expect(_T.defines);
      final rule = EbnfRule(name: name, definition: _definition(r));
      r.expect(_T.semicolon);
      return rule;
    },
  );
}

RailroadNode _node(EbnfPart part, List<RailroadNode> kids) {
  switch (part.$type) {
    case 'EbnfChoice':
      return choice(kids);
    case 'EbnfSequence':
      return sequence(kids);
    case 'EbnfTerm':
      {
        // Each postfix operator applies to everything before it in the term.
        final term = part as EbnfTerm;
        var result = kids[0];
        var next = 1;
        for (final postfix in term.postfixes) {
          if (postfix.$type == 'EbnfOptionalPostfix') {
            result = optional(result);
          } else if (postfix.$type == 'EbnfExceptionPostfix') {
            result = RailroadNode.sequence(<RailroadNode>[
              result,
              terminal('-'),
              kids[next++],
            ]);
          } else {
            result = repetition(
              result,
              postfix.$type == 'EbnfOneOrMorePostfix' ? 1 : 0,
            );
          }
        }
        return result;
      }
    case 'EbnfTerminal':
      return terminal((part as EbnfPrimary).value!);
    case 'EbnfNonTerminal':
      return nonterminal((part as EbnfPrimary).name!);
    case 'EbnfSpecial':
      return special((part as EbnfPrimary).text!);
    case 'EbnfGroup':
      return kids[0];
    case 'EbnfOptional':
      return optional(kids[0]);
    default:
      return repetition(kids[0], 0);
  }
}

List<RailroadRule> ebnfRules(EbnfAst ast) => toRules<EbnfPart>(ast, _node);
