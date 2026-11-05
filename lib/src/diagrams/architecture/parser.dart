// Upstream: src/diagrams/architecture/parser.ts

import '../common/tokens.dart';

abstract final class _T {
  static const int header = 0;
  static const int junction = 1;
  static const int service = 2;
  static const int column = 3;
  static const int group = 4;
  static const int align = 5;
  static const int row = 6;
  static const int dashes = 7;
  static const int inKw = 8;
  static const int colon = 9;
  static const int dash = 10;
  static const int direction = 11;
  static const int arrowGroup = 12;
  static const int into = 13;
  static const int accDescr = 14;
  static const int accTitle = 15;
  static const int title = 16;
  static const int string = 17;
  static const int id = 18;
  static const int newline = 19;
  // 20: whitespace, 21: yaml, 22: directive, 23: comment (hidden tokens)
  static const int icon = 24;
  static const int label = 25;
}

final TokenType _id = TokenType(
  name: 'ID',
  pattern: RegExp(r'[\w]([-\w]*\w)?'),
);

TokenType _word(String text) {
  return TokenType(name: text, pattern: text, longer: <TokenType>[_id]);
}

// The direction letters come before identifiers and have no longer alternative, so Mermaid
// reads an id that starts with L, R, T or B as a direction followed by the rest.
final List<TokenType> ARCHITECTURE_TOKENS = <TokenType>[
  _word('architecture-beta'),
  _word('junction'),
  _word('service'),
  _word('column'),
  _word('group'),
  _word('align'),
  _word('row'),
  TokenType(name: '--', pattern: '--', longer: <TokenType>[YAML]),
  _word('in'),
  const TokenType(name: ':', pattern: ':'),
  TokenType(name: '-', pattern: '-', longer: <TokenType>[YAML]),
  TokenType(name: 'ARROW_DIRECTION', pattern: RegExp(r'L|R|T|B')),
  TokenType(name: 'ARROW_GROUP', pattern: RegExp(r'\{group\}')),
  TokenType(name: 'ARROW_INTO', pattern: RegExp(r'<|>')),
  ACC_DESCR,
  ACC_TITLE,
  titleBefore(r'[-\w]*\w'),
  STRING,
  _id,
  NEWLINE,
  WHITESPACE,
  YAML,
  DIRECTIVE,
  SINGLE_LINE_COMMENT,
  TokenType(name: 'ARCH_ICON', pattern: RegExp(r'\([\w-:]+\)')),
  TokenType(
    name: 'ARCH_TITLE',
    pattern: RegExp(
      r'''\[(?:"([^"\\]|\\.)*"|'([^'\\]|\\.)*'|[^\[\]\r\n]+)\]''',
    ),
  ),
];

/// `'L' | 'R' | 'T' | 'B'`
typedef Side = String;

class GroupAst {
  GroupAst({required this.id, this.icon, this.title, this.inGroup});

  final String $type = 'Group';
  final String id;
  String? icon;
  String? title;
  // Upstream property: `in`
  String? inGroup;
}

class ServiceAst {
  ServiceAst({
    required this.id,
    this.icon,
    this.iconText,
    this.title,
    this.inGroup,
  });

  final String $type = 'Service';
  final String id;
  String? icon;
  String? iconText;
  String? title;
  // Upstream property: `in`
  String? inGroup;
}

class JunctionAst {
  JunctionAst({required this.id, this.inGroup});

  final String $type = 'Junction';
  final String id;
  // Upstream property: `in`
  String? inGroup;
}

class EdgeAst {
  const EdgeAst({
    required this.lhsId,
    required this.lhsGroup,
    required this.lhsDir,
    required this.lhsInto,
    this.title,
    required this.rhsInto,
    required this.rhsDir,
    required this.rhsId,
    required this.rhsGroup,
  });

  final String $type = 'Edge';
  final String lhsId;
  final bool lhsGroup;
  final Side lhsDir;
  final bool lhsInto;
  final String? title;
  final bool rhsInto;
  final Side rhsDir;
  final String rhsId;
  final bool rhsGroup;
}

class AlignmentAst {
  const AlignmentAst({required this.direction, required this.members});

  final String $type = 'Alignment';
  final String direction;
  final List<String> members;
}

class ArchitectureAst {
  ArchitectureAst({
    this.title,
    this.accTitle,
    this.accDescr,
    List<GroupAst>? groups,
    List<ServiceAst>? services,
    List<JunctionAst>? junctions,
    List<EdgeAst>? edges,
    List<AlignmentAst>? alignments,
  }) : groups = groups ?? <GroupAst>[],
       services = services ?? <ServiceAst>[],
       junctions = junctions ?? <JunctionAst>[],
       edges = edges ?? <EdgeAst>[],
       alignments = alignments ?? <AlignmentAst>[];

  final String $type = 'Architecture';
  String? title;
  String? accTitle;
  String? accDescr;
  final List<GroupAst> groups;
  final List<ServiceAst> services;
  final List<JunctionAst> junctions;
  final List<EdgeAst> edges;
  final List<AlignmentAst> alignments;
}

// Mermaid's ArchitectureValueConverter for ARCH_TITLE.
String _labelValue(String text) {
  var result = text.substring(1, text.length - 1).trim();
  if ((result.startsWith('"') && result.endsWith('"')) ||
      (result.startsWith("'") && result.endsWith("'"))) {
    result = result
        .substring(1, result.length - 1)
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'");
  }
  return result.trim();
}

ArchitectureAst parseArchitecture(String src) {
  final r = Reader(
    tokenize(src, ARCHITECTURE_TOKENS, 'architecture'),
    ARCHITECTURE_TOKENS,
    'architecture',
  );
  final ast = ArchitectureAst();

  bool isKind(int kind) => r.kinds[r.i] == kind;
  void endOfLine() {
    if (r.kind == -1) return;
    if (r.kind != _T.newline) r.fail('a line break or the end of input');
    while (r.kind == _T.newline) {
      r.i++;
    }
  }

  while (r.kind == _T.newline) {
    r.i++;
  }
  r.expect(_T.header);
  while (r.kind != -1) {
    switch (r.kind) {
      case _T.newline:
        r.i++;
        continue;
      case _T.accDescr:
        ast.accDescr = accDescrValue(r.take());
      case _T.accTitle:
        ast.accTitle = accTitleValue(r.take());
      case _T.title:
        ast.title = titleValue(r.take());
      case _T.group:
        r.i++;
        final group = GroupAst(id: r.expect(_T.id));
        if (isKind(_T.icon)) {
          final raw = r.take();
          group.icon = raw.substring(1, raw.length - 1);
        }
        if (isKind(_T.label)) group.title = _labelValue(r.take());
        if (r.accept(_T.inKw)) group.inGroup = r.expect(_T.id);
        ast.groups.add(group);
      case _T.service:
        r.i++;
        final service = ServiceAst(id: r.expect(_T.id));
        if (isKind(_T.string)) {
          service.iconText = stringValue(r.take());
        } else if (isKind(_T.icon)) {
          final raw = r.take();
          service.icon = raw.substring(1, raw.length - 1);
        }
        if (isKind(_T.label)) service.title = _labelValue(r.take());
        if (r.accept(_T.inKw)) service.inGroup = r.expect(_T.id);
        ast.services.add(service);
      case _T.junction:
        r.i++;
        final junction = JunctionAst(id: r.expect(_T.id));
        if (r.accept(_T.inKw)) junction.inGroup = r.expect(_T.id);
        ast.junctions.add(junction);
      case _T.id:
        final lhsId = r.take();
        final lhsGroup = r.accept(_T.arrowGroup);
        r.expect(_T.colon);
        final lhsDir = r.expect(_T.direction);
        final lhsInto = r.accept(_T.into);
        String? title;
        if (!r.accept(_T.dashes)) {
          if (!isKind(_T.dash)) r.fail("'--' or '-'");
          r.i++;
          title = _labelValue(r.expect(_T.label));
          r.expect(_T.dash);
        }
        final rhsInto = r.accept(_T.into);
        final rhsDir = r.expect(_T.direction);
        r.expect(_T.colon);
        final rhsId = r.expect(_T.id);
        final rhsGroup = r.accept(_T.arrowGroup);
        ast.edges.add(
          EdgeAst(
            lhsId: lhsId,
            lhsGroup: lhsGroup,
            lhsDir: lhsDir,
            lhsInto: lhsInto,
            title: title,
            rhsInto: rhsInto,
            rhsDir: rhsDir,
            rhsId: rhsId,
            rhsGroup: rhsGroup,
          ),
        );
      case _T.align:
        r.i++;
        if (!isKind(_T.row) && !isKind(_T.column)) {
          r.fail("'row' or 'column'");
        }
        final direction = r.take();
        final members = <String>[r.expect(_T.id), r.expect(_T.id)];
        while (isKind(_T.id)) {
          members.add(r.take());
        }
        ast.alignments.add(
          AlignmentAst(direction: direction, members: members),
        );
      default:
        r.fail(
          'a group, a service, a junction, an edge, an alignment, a title, or a line break',
        );
    }
    endOfLine();
  }
  return ast;
}
