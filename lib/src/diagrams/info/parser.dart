// Upstream: src/diagrams/info/parser.ts

import '../common/tokens.dart';

class _T {
  static const int showInfo = 0;
  static const int info = 1;
  static const int accDescr = 2;
  static const int accTitle = 3;
  static const int title = 4;
  static const int newline = 5;
}

final List<TokenType> INFO_TOKENS = <TokenType>[
  keyword('showInfo'),
  keyword('info'),
  ACC_DESCR,
  ACC_TITLE,
  TITLE,
  NEWLINE,
  WHITESPACE,
  YAML,
  DIRECTIVE,
  SINGLE_LINE_COMMENT,
];

class InfoAst {
  final String $type = 'Info';
  String? title;
  String? accTitle;
  String? accDescr;

  InfoAst({this.title, this.accTitle, this.accDescr});
}

InfoAst parseInfo(String src) {
  final r = Reader(tokenize(src, INFO_TOKENS, 'info'), INFO_TOKENS, 'info');
  final ast = InfoAst();

  while (r.kind == _T.newline) {
    r.i++;
  }
  r.expect(_T.info);
  while (r.kind == _T.newline) {
    r.i++;
  }
  if (r.accept(_T.showInfo)) {
    while (r.kind == _T.newline) {
      r.i++;
    }
  }
  while (r.kind != -1) {
    final kind = r.kind;
    if (kind == _T.accDescr) {
      ast.accDescr = accDescrValue(r.take());
    } else if (kind == _T.accTitle) {
      ast.accTitle = accTitleValue(r.take());
    } else if (kind == _T.title) {
      ast.title = titleValue(r.take());
    } else {
      r.fail('a title or the end of input');
    }
    if (r.kind == -1) break;
    if (r.kind != _T.newline) r.fail('a line break or the end of input');
    while (r.kind == _T.newline) {
      r.i++;
    }
  }
  return ast;
}
