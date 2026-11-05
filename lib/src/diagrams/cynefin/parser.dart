// Upstream: src/diagrams/cynefin/parser.ts

import '../common/tokens.dart';

class _T {
  static const int keywordColon = 0;
  static const int keyword = 1;
  static const int arrow = 2;
  static const int colon = 3;
  static const int domain = 4;
  static const int accDescr = 5;
  static const int accTitle = 6;
  static const int title = 7;
  static const int string = 8;
  static const int newline = 9;
}

final List<TokenType> CYNEFIN_TOKENS = <TokenType>[
  const TokenType(name: 'cynefin-beta:', pattern: 'cynefin-beta:'),
  keyword('cynefin-beta'),
  const TokenType(name: '-->', pattern: '-->'),
  const TokenType(name: ':', pattern: ':'),
  TokenType(
    name: 'DOMAIN_NAME',
    pattern: RegExp(r'complex|complicated|clear|chaotic|confusion'),
  ),
  ACC_DESCR,
  ACC_TITLE,
  TITLE,
  STRING,
  NEWLINE,
  WHITESPACE,
  YAML,
  DIRECTIVE,
  SINGLE_LINE_COMMENT,
];

typedef DomainName = String;

class DomainItemAst {
  final String $type = 'DomainItem';
  final String label;

  const DomainItemAst({required this.label});
}

class DomainBlockAst {
  final String $type = 'DomainBlock';
  final DomainName domain;
  final List<DomainItemAst> items;

  DomainBlockAst({required this.domain, List<DomainItemAst>? items})
    : items = items ?? <DomainItemAst>[];
}

class TransitionAst {
  final String $type = 'Transition';
  final DomainName from;
  final DomainName to;
  String? label;

  TransitionAst({required this.from, required this.to, this.label});
}

class CynefinAst {
  final String $type = 'Cynefin';
  String? title;
  String? accTitle;
  String? accDescr;
  final List<DomainBlockAst> domains;
  final List<TransitionAst> transitions;

  CynefinAst({
    this.title,
    this.accTitle,
    this.accDescr,
    List<DomainBlockAst>? domains,
    List<TransitionAst>? transitions,
  }) : domains = domains ?? <DomainBlockAst>[],
       transitions = transitions ?? <TransitionAst>[];
}

CynefinAst parseCynefin(String src) {
  final r = Reader(
    tokenize(src, CYNEFIN_TOKENS, 'cynefin'),
    CYNEFIN_TOKENS,
    'cynefin',
  );
  final ast = CynefinAst();

  void skipLines() {
    while (r.kinds[r.i] == _T.newline) {
      r.i++;
    }
  }

  void endOfLine() {
    if (r.kind == -1) return;
    if (r.kind != _T.newline) r.fail('a line break or the end of input');
    skipLines();
  }

  skipLines();
  if (r.kind != _T.keyword && r.kind != _T.keywordColon) {
    r.fail("'cynefin-beta'");
  }
  r.i++;
  while (r.kind != -1) {
    switch (r.kind) {
      case _T.newline:
        r.i++;
        break;
      case _T.accDescr:
        ast.accDescr = accDescrValue(r.take());
        endOfLine();
        break;
      case _T.accTitle:
        ast.accTitle = accTitleValue(r.take());
        endOfLine();
        break;
      case _T.title:
        ast.title = titleValue(r.take());
        endOfLine();
        break;
      case _T.domain:
        final name = r.take();
        if (r.accept(_T.arrow)) {
          final transition = TransitionAst(from: name, to: r.expect(_T.domain));
          if (r.accept(_T.colon)) {
            transition.label = stringValue(r.expect(_T.string));
          }
          endOfLine();
          ast.transitions.add(transition);
          break;
        }
        final block = DomainBlockAst(domain: name);
        skipLines();
        while (r.kinds[r.i] == _T.string) {
          block.items.add(DomainItemAst(label: stringValue(r.take())));
          skipLines();
        }
        ast.domains.add(block);
        break;
      default:
        r.fail('a domain, a transition, a title, or a line break');
    }
  }
  return ast;
}
