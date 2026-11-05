// Upstream: src/diagrams/railroad/ir.ts

import '../common/tokens.dart' show Reader, TokenType;
import 'common.dart';
import 'types.dart';

// `railroad-beta`: Mermaid's own notation, one constructor call per node.

abstract final class _T {
  static const int nonterminal = 1;
  static const int zeroOrMore = 2;
  static const int oneOrMore = 3;
  static const int sequence = 4;
  static const int optional = 5;
  static const int terminal = 6;
  static const int special = 7;
  static const int choice = 8;
  static const int equals = 9;
  static const int semicolon = 10;
  static const int open = 11;
  static const int comma = 12;
  static const int close = 13;
  static const int title = 14;
  static const int id = 17;
  static const int string = 18;
}

final TokenType _id = identifier('RR_ID');
TokenType _word(String name) => literal(name, <TokenType>[_id]);

final List<TokenType> IR_TOKENS = <TokenType>[
  opening('railroad-beta', _id),
  _word('nonterminal'),
  _word('zeroOrMore'),
  _word('oneOrMore'),
  _word('sequence'),
  _word('optional'),
  _word('terminal'),
  _word('special'),
  _word('choice'),
  literal('='),
  literal(';'),
  literal('('),
  literal(','),
  literal(')'),
  title(r'[\w-]'),
  ACC_TITLE,
  ACC_DESCR,
  _id,
  quoted('RR_STRING'),
  ...hiddenTokens('RR'),
  TokenType(
    name: 'RR_BLOCK_COMMENT',
    pattern: RegExp(r'\/\*[\s\S]*?\*\/'),
    hidden: true,
    first: '/',
    opener: RegExp(r'\/\*'),
  ),
];

class IrExpression implements HasParts<IrExpression> {
  IrExpression({
    required this.$type,
    this.elements,
    this.alternatives,
    this.element,
    this.hasElementSlot = false,
    this.value,
    this.name,
    this.text,
  });

  final String $type;
  final List<IrExpression>? elements;
  final List<IrExpression>? alternatives;
  IrExpression? element;
  final bool hasElementSlot;
  final String? value;
  final String? name;
  final String? text;

  @override
  List<IrExpression> get nodeParts {
    if (alternatives != null) return alternatives!;
    if (elements != null) return elements!;
    if (element != null) return <IrExpression>[element!];
    return const <IrExpression>[];
  }
}

class IrRule implements RuleNode<IrExpression> {
  const IrRule({required this.name, required this.definition});

  final String $type = 'RailroadRule';
  @override
  final String name;
  @override
  final IrExpression definition;
}

typedef IrAst = Grammar<IrRule>;

String _argument(Reader r) {
  r.i++;
  r.expect(_T.open);
  final value = unescape(r.expect(_T.string));
  r.expect(_T.close);
  return value;
}

IrExpression _wrapper(String $type) {
  return IrExpression($type: $type, hasElementSlot: true);
}

IrExpression _expression(Reader r) {
  final open = <IrExpression>[];
  for (;;) {
    IrExpression value;
    switch (r.kind) {
      case _T.terminal:
        value = IrExpression(
          $type: 'RailroadTerminalExpr',
          value: _argument(r),
        );
        break;
      case _T.nonterminal:
        value = IrExpression(
          $type: 'RailroadNonTerminalExpr',
          name: _argument(r),
        );
        break;
      case _T.special:
        value = IrExpression($type: 'RailroadSpecialExpr', text: _argument(r));
        break;
      case _T.sequence:
        value = IrExpression(
          $type: 'RailroadSequenceExpr',
          elements: <IrExpression>[],
        );
        break;
      case _T.choice:
        value = IrExpression(
          $type: 'RailroadChoiceExpr',
          alternatives: <IrExpression>[],
        );
        break;
      case _T.optional:
        value = _wrapper('RailroadOptionalExpr');
        break;
      case _T.oneOrMore:
        value = _wrapper('RailroadOneOrMoreExpr');
        break;
      case _T.zeroOrMore:
        value = _wrapper('RailroadZeroOrMoreExpr');
        break;
      default:
        r.fail('an expression');
    }
    if (value.elements != null ||
        value.alternatives != null ||
        value.hasElementSlot) {
      r.i++;
      r.expect(_T.open);
      open.add(value);
      continue;
    }
    for (;;) {
      if (open.isEmpty) return value;
      final parent = open.last;
      if (parent.hasElementSlot) {
        parent.element = value;
      } else {
        (parent.elements ?? parent.alternatives!).add(value);
        if (r.accept(_T.comma)) break;
      }
      r.expect(_T.close);
      open.removeLast();
      value = parent;
    }
  }
}

IrAst parseIr(String src) {
  return parseGrammar<IrRule>(src, IR_TOKENS, 'Railroad', _T.title, unescape, (
    r,
  ) {
    final name = r.expect(_T.id);
    r.expect(_T.equals);
    final definition = _expression(r);
    r.expect(_T.semicolon);
    return IrRule(name: name, definition: definition);
  });
}

RailroadNode _node(IrExpression e, List<RailroadNode> kids) {
  switch (e.$type) {
    case 'RailroadTerminalExpr':
      return terminal(e.value!);
    case 'RailroadNonTerminalExpr':
      return nonterminal(e.name!);
    case 'RailroadSpecialExpr':
      return special(e.text!);
    case 'RailroadSequenceExpr':
      return sequence(kids);
    case 'RailroadChoiceExpr':
      return choice(kids);
    case 'RailroadOptionalExpr':
      return optional(kids[0]);
    default:
      return repetition(kids[0], e.$type == 'RailroadOneOrMoreExpr' ? 1 : 0);
  }
}

List<RailroadRule> irRules(IrAst ast) => toRules<IrExpression>(ast, _node);
