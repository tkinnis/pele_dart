// Upstream: src/diagrams/railroad/peg.ts

import '../common/tokens.dart' show Reader, TokenType;
import 'common.dart';
import 'types.dart';

// `railroad-peg-beta`: parsing expression grammars.

abstract final class _T {
  static const int arrow = 1;
  static const int semicolon = 2;
  static const int slash = 3;
  static const int and = 4;
  static const int not = 5;
  static const int question = 6;
  static const int star = 7;
  static const int plus = 8;
  static const int group = 9;
  static const int groupEnd = 10;
  static const int dot = 11;
  static const int title = 12;
  static const int id = 15;
  static const int string = 16;
}

final TokenType _id = identifier('PEG_ID');

final List<TokenType> PEG_TOKENS = <TokenType>[
  opening('railroad-peg-beta', _id),
  literal('<-'),
  literal(';'),
  literal('/'),
  literal('&'),
  literal('!'),
  literal('?'),
  literal('*'),
  literal('+'),
  literal('('),
  literal(')'),
  literal('.'),
  title(r'[\w-]'),
  ACC_TITLE,
  ACC_DESCR,
  _id,
  quoted('PEG_STRING'),
  ...hiddenTokens('PEG'),
  TokenType(
    name: 'PEG_LINE_COMMENT',
    pattern: RegExp(r'#[^\n\r]*'),
    hidden: true,
    first: '#',
  ),
];

abstract interface class PegPart implements HasParts<PegPart> {
  String get $type;
}

class PegPrimary implements PegPart {
  const PegPrimary._({
    required this.$type,
    this.value,
    this.name,
    this.dot,
    this.element,
  });

  const PegPrimary.literal(String value)
    : this._($type: 'PegLiteral', value: value);

  const PegPrimary.identifier(String name)
    : this._($type: 'PegIdentifier', name: name);

  const PegPrimary.any(String dot) : this._($type: 'PegAny', dot: dot);

  const PegPrimary.group(PegChoice element)
    : this._($type: 'PegGroup', element: element);

  @override
  final String $type;
  final String? value;
  final String? name;
  final String? dot;
  final PegChoice? element;

  @override
  List<PegPart> get nodeParts =>
      element != null ? <PegPart>[element!] : const <PegPart>[];
}

class PegSuffix implements PegPart {
  PegSuffix({required this.primary, this.operator});

  @override
  final String $type = 'PegSuffix';
  final PegPrimary primary;
  String? operator;

  @override
  List<PegPart> get nodeParts => <PegPart>[primary];
}

class PegPrefix implements PegPart {
  const PegPrefix({required this.suffix, this.operator});

  @override
  final String $type = 'PegPrefix';
  final String? operator;
  final PegSuffix suffix;

  @override
  List<PegPart> get nodeParts => <PegPart>[suffix];
}

class PegSequence implements PegPart {
  PegSequence() : elements = <PegPrefix>[];

  @override
  final String $type = 'PegSequence';
  final List<PegPrefix> elements;

  @override
  List<PegPart> get nodeParts => elements;
}

class PegChoice implements PegPart {
  PegChoice() : alternatives = <PegSequence>[];

  @override
  final String $type = 'PegOrderedChoice';
  final List<PegSequence> alternatives;

  @override
  List<PegPart> get nodeParts => alternatives;
}

class PegRule implements RuleNode<PegPart> {
  const PegRule({required this.name, required this.definition});

  final String $type = 'PegRule';
  @override
  final String name;
  @override
  final PegChoice definition;
}

typedef PegAst = Grammar<PegRule>;

// One open group, or the rule itself at the bottom of the stack.
class _Frame {
  _Frame({
    required this.choice,
    required this.sequence,
    this.node,
    this.operator,
  });

  final PegChoice choice;
  PegSequence sequence;
  // The group's node and the predicate written before it.
  final PegPrimary? node;
  final String? operator;
}

_Frame _frame(PegPrimary? node, PegChoice choice, String? operator) {
  final sequence = PegSequence();
  choice.alternatives.add(sequence);
  return _Frame(
    choice: choice,
    sequence: sequence,
    node: node,
    operator: operator,
  );
}

PegChoice _definition(Reader r) {
  final stack = <_Frame>[];
  var top = _frame(null, PegChoice(), null);
  for (;;) {
    var operator = r.kind == _T.and || r.kind == _T.not ? r.take() : null;
    PegPrimary primary;
    final kind = r.kind;
    switch (kind) {
      case _T.string:
        primary = PegPrimary.literal(unescape(r.take()));
        break;
      case _T.id:
        primary = PegPrimary.identifier(r.take());
        break;
      case _T.dot:
        primary = PegPrimary.any(r.take());
        break;
      case _T.group:
        {
          r.i++;
          final element = PegChoice();
          stack.add(top);
          top = _frame(PegPrimary.group(element), element, operator);
          continue;
        }
      default:
        r.fail('a literal, a name, a dot, or an opening parenthesis');
    }
    for (;;) {
      final suffix = PegSuffix(primary: primary);
      if (r.kind == _T.question || r.kind == _T.star || r.kind == _T.plus) {
        suffix.operator = r.take();
      }
      top.sequence.elements.add(PegPrefix(suffix: suffix, operator: operator));
      final k = r.kind;
      if (k == _T.groupEnd && stack.isNotEmpty) {
        r.i++;
        primary = top.node!;
        operator = top.operator;
        top = stack.removeLast();
        continue;
      }
      if (k == _T.slash) {
        r.i++;
        top.sequence = PegSequence();
        top.choice.alternatives.add(top.sequence);
      } else if (k != _T.and &&
          k != _T.not &&
          k != _T.string &&
          k != _T.id &&
          k != _T.dot &&
          k != _T.group) {
        if (stack.isEmpty) return top.choice;
        r.fail("token of type ')'");
      }
      break;
    }
  }
}

PegAst parsePeg(String src) {
  return parseGrammar<PegRule>(
    src,
    PEG_TOKENS,
    'RailroadPeg',
    _T.title,
    unescape,
    (r) {
      final name = r.expect(_T.id);
      r.expect(_T.arrow);
      final rule = PegRule(name: name, definition: _definition(r));
      r.expect(_T.semicolon);
      return rule;
    },
  );
}

// What a predicate shows of the expression it looks ahead for.
String _label(RailroadNode node) {
  switch (node.type) {
    case 'terminal':
      return '"${node.value!}"';
    case 'nonterminal':
      return node.name!;
    case 'special':
      return node.text!;
    default:
      return '(...)';
  }
}

RailroadNode _node(PegPart part, List<RailroadNode> kids) {
  final kid = kids.isNotEmpty ? kids[0] : null;
  switch (part.$type) {
    case 'PegOrderedChoice':
      return choice(kids);
    case 'PegSequence':
      return sequence(kids);
    case 'PegPrefix':
      {
        final op = (part as PegPrefix).operator;
        return op != null && op.isNotEmpty
            ? special('$op${_label(kid!)}')
            : kid!;
      }
    case 'PegSuffix':
      {
        final op = (part as PegSuffix).operator;
        if (op == null || op.isEmpty) return kid!;
        return op == '?' ? optional(kid!) : repetition(kid!, op == '+' ? 1 : 0);
      }
    case 'PegLiteral':
      return terminal((part as PegPrimary).value!);
    case 'PegIdentifier':
      return nonterminal((part as PegPrimary).name!);
    case 'PegAny':
      return special((part as PegPrimary).dot!);
    default:
      return kid!;
  }
}

List<RailroadRule> pegRules(PegAst ast) => toRules<PegPart>(ast, _node);
