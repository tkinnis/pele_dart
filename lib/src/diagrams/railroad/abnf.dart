// Upstream: src/diagrams/railroad/abnf.ts

import '../common/tokens.dart' show Reader, TokenType;
import 'common.dart';
import 'types.dart';

// `railroad-abnf-beta`: ABNF as in RFC 5234, with each rule closed by a semicolon.

abstract final class _T {
  static const int equals = 1;
  static const int semicolon = 2;
  static const int slash = 3;
  static const int group = 4;
  static const int option = 6;
  static const int title = 8;
  static const int name = 11;
  static const int string = 12;
  static const int number = 13;
  static const int repeat = 14;
  static const int exact = 15;
}

const String _digits = '0123456789';
final TokenType _name = TokenType(
  name: 'ABNF_RULENAME',
  pattern: RegExp(r'[A-Za-z][A-Za-z0-9-]*'),
  first: LETTERS,
);
final TokenType _comment = TokenType(
  name: 'ABNF_COMMENT',
  pattern: RegExp(r';[^\n\r]*'),
  hidden: true,
  first: ';',
);

final List<TokenType> ABNF_TOKENS = <TokenType>[
  opening('railroad-abnf-beta', _name),
  literal('='),
  // A semicolon closes a rule only at the end of its line; with anything after it, it starts a comment.
  literal(';', <TokenType>[_comment]),
  literal('/'),
  literal('('),
  literal(')'),
  literal('['),
  literal(']'),
  title(r'[A-Za-z0-9-]'),
  ACC_TITLE,
  ACC_DESCR,
  _name,
  TokenType(name: 'ABNF_STRING', pattern: RegExp(r'"[^"]*"'), first: '"'),
  TokenType(
    name: 'ABNF_NUMVAL',
    pattern: RegExp(r'%[xXdDbB][0-9A-Fa-f]+(?:-[0-9A-Fa-f]+|\.[0-9A-Fa-f]+)*'),
    first: '%',
  ),
  TokenType(
    name: 'ABNF_REPEAT',
    pattern: RegExp(r'[0-9]*\*[0-9]*'),
    first: '$_digits*',
  ),
  TokenType(
    name: 'ABNF_EXACT_REPEAT',
    pattern: RegExp(r'[0-9]+'),
    first: _digits,
  ),
  ...hiddenTokens('ABNF'),
  _comment,
];

abstract interface class AbnfPart implements HasParts<AbnfPart> {
  String get $type;
}

class AbnfPrimary implements AbnfPart {
  const AbnfPrimary._({
    required this.$type,
    this.value,
    this.name,
    this.element,
  });

  const AbnfPrimary.literal(String $type, String value)
    : this._($type: $type, value: value);

  const AbnfPrimary.ruleName(String name)
    : this._($type: 'AbnfRuleName', name: name);

  const AbnfPrimary.group(String $type, AbnfAlternation element)
    : this._($type: $type, element: element);

  @override
  final String $type;
  final String? value;
  final String? name;
  final AbnfAlternation? element;

  @override
  List<AbnfPart> get nodeParts =>
      element != null ? <AbnfPart>[element!] : const <AbnfPart>[];
}

class AbnfElement implements AbnfPart {
  const AbnfElement({required this.primary, this.repeat});

  @override
  final String $type = 'AbnfElement';
  final String? repeat;
  final AbnfPrimary primary;

  @override
  List<AbnfPart> get nodeParts => <AbnfPart>[primary];
}

class AbnfConcatenation implements AbnfPart {
  AbnfConcatenation() : elements = <AbnfElement>[];

  @override
  final String $type = 'AbnfConcatenation';
  final List<AbnfElement> elements;

  @override
  List<AbnfPart> get nodeParts => elements;
}

class AbnfAlternation implements AbnfPart {
  AbnfAlternation() : alternatives = <AbnfConcatenation>[];

  @override
  final String $type = 'AbnfAlternation';
  final List<AbnfConcatenation> alternatives;

  @override
  List<AbnfPart> get nodeParts => alternatives;
}

class AbnfRule implements RuleNode<AbnfPart> {
  const AbnfRule({required this.name, required this.definition});

  final String $type = 'AbnfRule';
  @override
  final String name;
  @override
  final AbnfAlternation definition;
}

typedef AbnfAst = Grammar<AbnfRule>;

// One open bracket, or the rule itself at the bottom of the stack.
class _Frame {
  _Frame({
    required this.alternation,
    required this.concatenation,
    this.node,
    required this.close,
    this.repeat,
  });

  final AbnfAlternation alternation;
  AbnfConcatenation concatenation;
  // The bracket's node, its closing token, and the repeat written before it.
  final AbnfPrimary? node;
  final int close;
  final String? repeat;
}

_Frame _frame(
  AbnfPrimary? node,
  AbnfAlternation alternation,
  int close,
  String? repeat,
) {
  final concatenation = AbnfConcatenation();
  alternation.alternatives.add(concatenation);
  return _Frame(
    alternation: alternation,
    concatenation: concatenation,
    node: node,
    close: close,
    repeat: repeat,
  );
}

AbnfAlternation _alternation(Reader r) {
  final stack = <_Frame>[];
  var top = _frame(null, AbnfAlternation(), -2, null);
  for (;;) {
    var repeat = r.kind == _T.repeat || r.kind == _T.exact ? r.take() : null;
    AbnfPrimary primary;
    final kind = r.kind;
    switch (kind) {
      case _T.string:
        {
          final raw = r.take();
          primary = AbnfPrimary.literal(
            'AbnfStringLiteral',
            raw.substring(1, raw.length - 1),
          );
          break;
        }
      case _T.number:
        primary = AbnfPrimary.literal('AbnfNumVal', r.take());
        break;
      case _T.name:
        primary = AbnfPrimary.ruleName(r.take());
        break;
      case _T.group:
      case _T.option:
        {
          r.i++;
          final element = AbnfAlternation();
          stack.add(top);
          top = _frame(
            AbnfPrimary.group(
              kind == _T.group ? 'AbnfGroup' : 'AbnfOptionalGroup',
              element,
            ),
            element,
            kind + 1,
            repeat,
          );
          continue;
        }
      default:
        r.fail('a string, a number, a name, or an opening bracket');
    }
    for (;;) {
      top.concatenation.elements.add(
        AbnfElement(primary: primary, repeat: repeat),
      );
      final k = r.kind;
      if (k == top.close) {
        r.i++;
        primary = top.node!;
        repeat = top.repeat;
        top = stack.removeLast();
        continue;
      }
      if (k == _T.slash) {
        r.i++;
        top.concatenation = AbnfConcatenation();
        top.alternation.alternatives.add(top.concatenation);
      } else if (k != _T.string &&
          k != _T.number &&
          k != _T.name &&
          k != _T.group &&
          k != _T.option &&
          k != _T.repeat &&
          k != _T.exact) {
        if (stack.isEmpty) return top.alternation;
        r.fail("token of type '${ABNF_TOKENS[top.close].name}'");
      }
      break;
    }
  }
}

AbnfAst parseAbnf(String src) {
  return parseGrammar<AbnfRule>(
    src,
    ABNF_TOKENS,
    'RailroadAbnf',
    _T.title,
    (text) => text.substring(1, text.length - 1),
    (r) {
      final name = r.expect(_T.name);
      r.expect(_T.equals);
      final definition = _alternation(r);
      r.expect(_T.semicolon);
      return AbnfRule(name: name, definition: definition);
    },
  );
}

RailroadNode _node(AbnfPart part, List<RailroadNode> kids) {
  switch (part.$type) {
    case 'AbnfAlternation':
      return choice(kids);
    case 'AbnfConcatenation':
      return sequence(kids);
    case 'AbnfElement':
      {
        final el = part as AbnfElement;
        final repeat = el.repeat;
        if (repeat == null || repeat.isEmpty) return kids[0];
        final star = repeat.indexOf('*');
        final exact = star == -1;
        final min = star > 0
            ? double.parse(repeat.substring(0, star))
            : (exact ? double.parse(repeat) : 0.0);
        final max = exact
            ? min
            : (star < repeat.length - 1
                  ? double.parse(repeat.substring(star + 1))
                  : double.infinity);
        return min == 0 && max == 1
            ? optional(kids[0])
            : repetition(kids[0], min, max);
      }
    case 'AbnfStringLiteral':
    case 'AbnfNumVal':
      return terminal((part as AbnfPrimary).value!);
    case 'AbnfRuleName':
      return nonterminal((part as AbnfPrimary).name!);
    case 'AbnfGroup':
      return kids[0];
    default:
      return optional(kids[0]);
  }
}

List<RailroadRule> abnfRules(AbnfAst ast) => toRules<AbnfPart>(ast, _node);
