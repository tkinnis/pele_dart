// Upstream: src/diagrams/git/parser.ts

import '../common/tokens.dart';

abstract final class _T {
  static const int cherryPick = 0;
  static const int gitGraphColon = 1;
  static const int highlight = 2;
  static const int gitGraph = 3;
  static const int checkout = 4;
  static const int reverse = 5;
  static const int parent = 6;
  static const int commit = 7;
  static const int normal = 8;
  static const int branch = 9;
  static const int order = 10;
  static const int switchTok = 11;
  static const int type = 12;
  static const int merge = 13;
  static const int msg = 14;
  static const int tag = 15;
  static const int id = 16;
  static const int lr = 17;
  static const int tb = 18;
  static const int bt = 19;
  static const int colon = 20;
  static const int accDescr = 21;
  static const int accTitle = 22;
  static const int title = 23;
  static const int intTok = 24;
  static const int string = 25;
  static const int newline = 26;
  static const int reference = 31;
}

final TokenType _reference = TokenType(
  name: 'REFERENCE',
  pattern: RegExp(r'\w([-\./\w]*[-\w])?'),
);
final List<TokenType> _name = <TokenType>[_reference];

// A keyword that is the start of a longer name is part of that name: `commits` is a branch.
TokenType _word(String name) {
  return TokenType(name: name, pattern: name, longer: _name);
}

final TokenType _gitGraphKw = keyword('gitGraph');

final List<TokenType> gitTokens = <TokenType>[
  _word('cherry-pick'),
  const TokenType(name: 'gitGraph:', pattern: 'gitGraph:'),
  _word('HIGHLIGHT'),
  TokenType(
    name: _gitGraphKw.name,
    pattern: _gitGraphKw.pattern,
    first: _gitGraphKw.first,
    longer: _name,
  ),
  _word('checkout'),
  _word('REVERSE'),
  const TokenType(name: 'parent:', pattern: 'parent:'),
  _word('commit'),
  _word('NORMAL'),
  _word('branch'),
  const TokenType(name: 'order:', pattern: 'order:'),
  _word('switch'),
  const TokenType(name: 'type:', pattern: 'type:'),
  _word('merge'),
  const TokenType(name: 'msg:', pattern: 'msg:'),
  const TokenType(name: 'tag:', pattern: 'tag:'),
  const TokenType(name: 'id:', pattern: 'id:'),
  _word('LR'),
  _word('TB'),
  _word('BT'),
  const TokenType(name: ':', pattern: ':'),
  // Without a closing brace the block form scans to the end of the text, and a brace is not a
  // token on its own, so the first failure is final.
  TokenType(
    name: ACC_DESCR.name,
    pattern: ACC_DESCR.pattern,
    first: ACC_DESCR.first,
    opener: RegExp(r'[\t ]*accDescr\s*\{'),
  ),
  ACC_TITLE,
  titleBefore(r'[-./\w]*[-\w]'),
  TokenType(name: 'INT', pattern: RegExp(r'0|[1-9][0-9]*(?!\.)')),
  STRING,
  NEWLINE,
  WHITESPACE,
  YAML,
  DIRECTIVE,
  SINGLE_LINE_COMMENT,
  _reference,
];

typedef CommitTypeName = String;

sealed class StatementAst {
  String get $type;
}

class CommitAst implements StatementAst {
  CommitAst({this.id, this.message, List<String>? tags, this.type})
    : tags = tags ?? <String>[];

  @override
  String get $type => 'Commit';
  String? id;
  String? message;
  final List<String> tags;
  CommitTypeName? type;
}

class BranchAst implements StatementAst {
  BranchAst({required this.name, this.order});

  @override
  String get $type => 'Branch';
  final String name;
  int? order;
}

class MergeAst implements StatementAst {
  MergeAst({required this.branch, this.id, List<String>? tags, this.type})
    : tags = tags ?? <String>[];

  @override
  String get $type => 'Merge';
  final String branch;
  String? id;
  final List<String> tags;
  CommitTypeName? type;
}

class CheckoutAst implements StatementAst {
  CheckoutAst({required this.branch});

  @override
  String get $type => 'Checkout';
  final String branch;
}

class CherryPickingAst implements StatementAst {
  CherryPickingAst({this.id, List<String>? tags, this.parent})
    : tags = tags ?? <String>[];

  @override
  String get $type => 'CherryPicking';
  String? id;
  final List<String> tags;
  String? parent;
}

// Langium names the root after the `Direction` rule when the header gives a direction.
class GitGraphAst {
  GitGraphAst({
    this.$type = 'GitGraph',
    this.dir,
    this.title,
    this.accTitle,
    this.accDescr,
    List<StatementAst>? statements,
  }) : statements = statements ?? <StatementAst>[];

  String $type;
  String? dir;
  String? title;
  String? accTitle;
  String? accDescr;
  final List<StatementAst> statements;
}

GitGraphAst parseGit(String src) {
  final r = Reader(tokenize(src, gitTokens, 'gitGraph'), gitTokens, 'gitGraph');
  final ast = GitGraphAst();

  void endOfLine() {
    if (r.kind == -1) return;
    if (r.kind != _T.newline) r.fail('a line break or the end of input');
    while (r.kind == _T.newline) {
      r.i++;
    }
  }

  String name() {
    if (r.kind == _T.reference) return r.take();
    if (r.kind == _T.string) return stringValue(r.take());
    r.fail('a branch name');
  }

  String string() => stringValue(r.expect(_T.string));

  CommitTypeName commitType() {
    if (r.kind != _T.normal && r.kind != _T.reverse && r.kind != _T.highlight) {
      r.fail('NORMAL, REVERSE, or HIGHLIGHT');
    }
    return r.take();
  }

  while (r.kind == _T.newline) {
    r.i++;
  }
  if (!r.accept(_T.gitGraphColon)) {
    r.expect(_T.gitGraph);
    final next = r.i + 1 < r.kinds.length ? r.kinds[r.i + 1] : -1;
    if ((r.kind == _T.lr || r.kind == _T.tb || r.kind == _T.bt) &&
        next == _T.colon) {
      ast.$type = 'Direction';
      ast.dir = r.take();
      r.i++;
    } else {
      r.accept(_T.colon);
    }
  }

  while (r.kind != -1) {
    switch (r.kind) {
      case _T.newline:
        r.i++;
      case _T.accDescr:
        ast.accDescr = accDescrValue(r.take());
        endOfLine();
      case _T.accTitle:
        ast.accTitle = accTitleValue(r.take());
        endOfLine();
      case _T.title:
        ast.title = titleValue(r.take());
        endOfLine();
      case _T.commit:
        r.i++;
        final node = CommitAst();
        for (;;) {
          if (r.accept(_T.id)) {
            node.id = string();
          } else if (r.accept(_T.tag)) {
            node.tags.add(string());
          } else if (r.accept(_T.type)) {
            node.type = commitType();
          } else if (r.accept(_T.msg) || r.kinds[r.i] == _T.string) {
            node.message = string();
          } else {
            break;
          }
        }
        endOfLine();
        ast.statements.add(node);
      case _T.branch:
        r.i++;
        final node = BranchAst(name: name());
        if (r.accept(_T.order)) {
          node.order = int.parse(r.expect(_T.intTok));
        }
        endOfLine();
        ast.statements.add(node);
      case _T.merge:
        r.i++;
        final node = MergeAst(branch: name());
        for (;;) {
          if (r.accept(_T.id)) {
            node.id = string();
          } else if (r.accept(_T.tag)) {
            node.tags.add(string());
          } else if (r.accept(_T.type)) {
            node.type = commitType();
          } else {
            break;
          }
        }
        endOfLine();
        ast.statements.add(node);
      case _T.checkout:
      case _T.switchTok:
        r.i++;
        final node = CheckoutAst(branch: name());
        endOfLine();
        ast.statements.add(node);
      case _T.cherryPick:
        r.i++;
        final node = CherryPickingAst();
        for (;;) {
          if (r.accept(_T.id)) {
            node.id = string();
          } else if (r.accept(_T.tag)) {
            node.tags.add(string());
          } else if (r.accept(_T.parent)) {
            node.parent = string();
          } else {
            break;
          }
        }
        endOfLine();
        ast.statements.add(node);
      default:
        r.fail('a statement, a title, or a line break');
    }
  }
  return ast;
}
