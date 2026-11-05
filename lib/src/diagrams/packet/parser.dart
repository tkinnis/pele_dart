// Upstream: src/diagrams/packet/parser.ts

import '../common/tokens.dart';

class _T {
  static const int packetBeta = 0;
  static const int packet = 1;
  static const int dash = 2;
  static const int plus = 3;
  static const int colon = 4;
  static const int accDescr = 5;
  static const int accTitle = 6;
  static const int title = 7;
  static const int intTok = 8;
  static const int stringTok = 9;
  static const int newline = 10;
}

final List<TokenType> PACKET_TOKENS = <TokenType>[
  const TokenType(name: 'packet-beta', pattern: 'packet-beta'),
  keyword('packet'),
  // A front matter block also starts with dashes, so Langium lets it win over a dash.
  TokenType(name: '-', pattern: '-', longer: <TokenType>[YAML]),
  const TokenType(name: '+', pattern: '+'),
  const TokenType(name: ':', pattern: ':'),
  ACC_DESCR,
  ACC_TITLE,
  TITLE,
  TokenType(name: 'INT', pattern: RegExp(r'0|[1-9][0-9]*(?!\.)')),
  STRING,
  NEWLINE,
  WHITESPACE,
  YAML,
  DIRECTIVE,
  SINGLE_LINE_COMMENT,
];

class PacketBlockAst {
  final String $type = 'PacketBlock';
  int? start;
  int? end;
  int? bits;
  String label;

  PacketBlockAst({this.start, this.end, this.bits, required this.label});
}

class PacketAst {
  final String $type = 'Packet';
  String? title;
  String? accTitle;
  String? accDescr;
  final List<PacketBlockAst> blocks;

  PacketAst({
    this.title,
    this.accTitle,
    this.accDescr,
    List<PacketBlockAst>? blocks,
  }) : blocks = blocks ?? <PacketBlockAst>[];
}

int _parseInt(String s) => int.tryParse(s) ?? 0x1fffffffffffff;

PacketAst parsePacket(String src) {
  final r = Reader(
    tokenize(src, PACKET_TOKENS, 'packet'),
    PACKET_TOKENS,
    'packet',
  );
  final ast = PacketAst();

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
  if (!r.accept(_T.packetBeta)) r.expect(_T.packet);
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
      case _T.intTok:
      case _T.plus:
        final block = PacketBlockAst(label: '');
        if (r.accept(_T.plus)) {
          block.bits = _parseInt(r.expect(_T.intTok));
        } else {
          block.start = _parseInt(r.take());
          if (r.accept(_T.dash)) {
            block.end = _parseInt(r.expect(_T.intTok));
          }
        }
        r.expect(_T.colon);
        block.label = stringValue(r.expect(_T.stringTok));
        ast.blocks.add(block);
        endOfLine();
      default:
        r.fail('a field, a title, or a line break');
    }
  }
  return ast;
}
