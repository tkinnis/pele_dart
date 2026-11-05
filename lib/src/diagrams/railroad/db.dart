// Upstream: src/diagrams/railroad/db.ts

import '../../errors.dart';
import 'abnf.dart';
import 'common.dart';
import 'ebnf.dart';
import 'ir.dart';
import 'peg.dart';
import 'types.dart';

class RailroadDb implements RailroadModel {
  @override
  final String type = 'railroad';
  @override
  Notation notation = 'railroad';
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;
  @override
  List<RailroadRule> rules = <RailroadRule>[];
  final Map<String, RailroadRule> _byName = <String, RailroadRule>{};

  void setTitle(String text) {
    title = text;
  }

  void setAccTitle(String text) {
    accTitle = text.replaceFirst(RegExp(r'^\s+'), '');
  }

  void setAccDescription(String text) {
    accDescr = text.replaceAll(RegExp(r'\n\s+'), '\n');
  }

  // A name defined again is drawn again; looking the name up gives the later definition.
  void addRule(RailroadRule rule) {
    rules.add(rule);
    _byName[rule.name] = rule;
  }

  RailroadRule? getRule(String name) {
    return _byName[name];
  }
}

final RegExp _reKeyword = RegExp(
  r'^\s*railroad-(ebnf-|abnf-|peg-)?beta',
  caseSensitive: false,
);

// Mermaid has a detector per keyword, each matching without regard to case.
Notation? notationOf(String source) {
  final m = _reKeyword.firstMatch(source);
  if (m == null) return null;
  final infix = m.group(1)?.toLowerCase();
  return infix == 'ebnf-'
      ? 'ebnf'
      : (infix == 'abnf-' ? 'abnf' : (infix == 'peg-' ? 'peg' : 'railroad'));
}

(Grammar<Object?>, List<RailroadRule>) _grammar(
  String source,
  Notation notation,
) {
  switch (notation) {
    case 'ebnf':
      {
        final ast = parseEbnf(source);
        return (ast, ebnfRules(ast));
      }
    case 'abnf':
      {
        final ast = parseAbnf(source);
        return (ast, abnfRules(ast));
      }
    case 'peg':
      {
        final ast = parsePeg(source);
        return (ast, pegRules(ast));
      }
    default:
      {
        final ast = parseIr(source);
        return (ast, irRules(ast));
      }
  }
}

// Parses the text in one notation and loads the result into the model, as Mermaid's four parsers do.
void populate(RailroadDb db, String source, Notation notation) {
  final (ast, rules) = _grammar(source, notation);
  db.notation = notation;
  if (ast.accDescr != null && ast.accDescr!.isNotEmpty) {
    db.setAccDescription(ast.accDescr!);
  }
  if (ast.accTitle != null && ast.accTitle!.isNotEmpty) {
    db.setAccTitle(ast.accTitle!);
  }
  if (ast.title != null && ast.title!.isNotEmpty) {
    db.setTitle(ast.title!);
  }
  for (final rule in rules) {
    db.addRule(rule);
  }
}

RailroadDb parseRailroad(String source, String? title) {
  final notation = notationOf(source);
  if (notation == null) {
    throw PeleError(
      'No railroad diagram keyword found.',
      'syntax',
      const PeleErrorInfo(type: 'railroad'),
    );
  }
  final db = RailroadDb();
  if (title != null && title.isNotEmpty) db.title = title;
  populate(db, source, notation);
  return db;
}
