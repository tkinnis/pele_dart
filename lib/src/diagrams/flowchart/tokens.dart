// Upstream: src/diagrams/flowchart/tokens.ts

abstract final class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int acc_title = 2;
  static const int acc_title_value = 3;
  static const int acc_descr = 4;
  static const int acc_descr_value = 5;
  static const int acc_descr_multiline_value = 6;
  static const int SHAPE_DATA = 7;
  static const int CALLBACKNAME = 8;
  static const int CALLBACKARGS = 9;
  static const int MD_STR = 10;
  static const int STR = 11;
  static const int STYLE = 12;
  static const int DEFAULT = 13;
  static const int LINKSTYLE = 14;
  static const int INTERPOLATE = 15;
  static const int CLASSDEF = 16;
  static const int CLASS = 17;
  static const int HREF = 18;
  static const int CLICK = 19;
  static const int GRAPH = 20;
  static const int subgraph = 21;
  static const int end = 22;
  static const int LINK_TARGET = 23;
  static const int NODIR = 24;
  static const int DIR = 25;
  static const int direction_tb = 26;
  static const int direction_bt = 27;
  static const int direction_rl = 28;
  static const int direction_lr = 29;
  static const int direction_td = 30;
  static const int LINK_ID = 31;
  static const int NUM = 32;
  static const int BRKT = 33;
  static const int STYLE_SEPARATOR = 34;
  static const int COLON = 35;
  static const int AMP = 36;
  static const int SEMI = 37;
  static const int COMMA = 38;
  static const int MULT = 39;
  static const int LINK = 40;
  static const int START_LINK = 41;
  static const int EDGE_TEXT = 42;
  static const int ELLIPSE_END = 43;
  static const int TEXT = 44;
  static const int ELLIPSE_START = 45;
  static const int STADIUMEND = 46;
  static const int STADIUMSTART = 47;
  static const int SUBROUTINEEND = 48;
  static const int SUBROUTINESTART = 49;
  static const int VERTEX_WITH_PROPS_START = 50;
  static const int TAGEND = 51;
  static const int CYLINDEREND = 52;
  static const int CYLINDERSTART = 53;
  static const int DOUBLECIRCLEEND = 54;
  static const int DOUBLECIRCLESTART = 55;
  static const int TRAPEND = 56;
  static const int INVTRAPEND = 57;
  static const int TRAPSTART = 58;
  static const int INVTRAPSTART = 59;
  static const int TAGSTART = 60;
  static const int UP = 61;
  static const int SEP = 62;
  static const int DOWN = 63;
  static const int NODE_STRING = 64;
  static const int MINUS = 65;
  static const int UNICODE_TEXT = 66;
  static const int PIPE = 67;
  static const int PE = 68;
  static const int PS = 69;
  static const int SQE = 70;
  static const int SQS = 71;
  static const int DIAMOND_STOP = 72;
  static const int DIAMOND_START = 73;
  static const int NEWLINE = 74;
  static const int SPACE = 75;
  static const int EOF = 76;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'INVALID',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'SHAPE_DATA',
  'CALLBACKNAME',
  'CALLBACKARGS',
  'MD_STR',
  'STR',
  'STYLE',
  'DEFAULT',
  'LINKSTYLE',
  'INTERPOLATE',
  'CLASSDEF',
  'CLASS',
  'HREF',
  'CLICK',
  'GRAPH',
  'subgraph',
  'end',
  'LINK_TARGET',
  'NODIR',
  'DIR',
  'direction_tb',
  'direction_bt',
  'direction_rl',
  'direction_lr',
  'direction_td',
  'LINK_ID',
  'NUM',
  'BRKT',
  'STYLE_SEPARATOR',
  'COLON',
  'AMP',
  'SEMI',
  'COMMA',
  'MULT',
  'LINK',
  'START_LINK',
  'EDGE_TEXT',
  '-)',
  'TEXT',
  '(-',
  'STADIUMEND',
  'STADIUMSTART',
  'SUBROUTINEEND',
  'SUBROUTINESTART',
  'VERTEX_WITH_PROPS_START',
  'TAGEND',
  'CYLINDEREND',
  'CYLINDERSTART',
  'DOUBLECIRCLEEND',
  'DOUBLECIRCLESTART',
  'TRAPEND',
  'INVTRAPEND',
  'TRAPSTART',
  'INVTRAPSTART',
  'TAGSTART',
  'UP',
  'SEP',
  'DOWN',
  'NODE_STRING',
  'MINUS',
  'UNICODE_TEXT',
  'PIPE',
  'PE',
  'PS',
  'SQE',
  'SQS',
  'DIAMOND_STOP',
  'DIAMOND_START',
  'NEWLINE',
  'SPACE',
  'EOF',
];
