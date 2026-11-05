// Upstream: src/diagrams/class/tokens.ts

class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int CLASS_DIAGRAM = 2;
  static const int NEWLINE = 3;
  static const int EOF = 4;
  static const int SQS = 5;
  static const int STR = 6;
  static const int SQE = 7;
  static const int DOT = 8;
  static const int GENERICTYPE = 9;
  static const int LABEL = 10;
  static const int acc_title = 11;
  static const int acc_title_value = 12;
  static const int acc_descr = 13;
  static const int acc_descr_value = 14;
  static const int acc_descr_multiline_value = 15;
  static const int STRUCT_START = 16;
  static const int STRUCT_STOP = 17;
  static const int NAMESPACE = 18;
  static const int STYLE_SEPARATOR = 19;
  static const int ANNOTATION_START = 20;
  static const int ANNOTATION_END = 21;
  static const int CLASS = 22;
  static const int MEMBER = 23;
  static const int NOTE_FOR = 24;
  static const int NOTE = 25;
  static const int CLASSDEF = 26;
  static const int ALPHA = 27;
  static const int COMMA = 28;
  static const int direction_tb = 29;
  static const int direction_bt = 30;
  static const int direction_rl = 31;
  static const int direction_lr = 32;
  static const int AGGREGATION = 33;
  static const int EXTENSION = 34;
  static const int COMPOSITION = 35;
  static const int DEPENDENCY = 36;
  static const int LOLLIPOP = 37;
  static const int LINE = 38;
  static const int DOTTED_LINE = 39;
  static const int CALLBACK = 40;
  static const int LINK = 41;
  static const int LINK_TARGET = 42;
  static const int CLICK = 43;
  static const int CALLBACK_NAME = 44;
  static const int CALLBACK_ARGS = 45;
  static const int HREF = 46;
  static const int STYLE = 47;
  static const int CSSCLASS = 48;
  static const int COLON = 49;
  static const int BRKT = 50;
  static const int PCT = 51;
  static const int MINUS = 52;
  static const int UNICODE_TEXT = 53;
  static const int BQUOTE_STR = 54;
  static const int EDGE_STATE = 55;
  static const int EOF_IN_STRUCT = 56;
  static const int OPEN_IN_STRUCT = 57;
  static const int PLUS = 58;
  static const int EQUALS = 59;
  static const int PUNCTUATION = 60;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'INVALID',
  'CLASS_DIAGRAM',
  'NEWLINE',
  'EOF',
  'SQS',
  'STR',
  'SQE',
  'DOT',
  'GENERICTYPE',
  'LABEL',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'STRUCT_START',
  'STRUCT_STOP',
  'NAMESPACE',
  'STYLE_SEPARATOR',
  'ANNOTATION_START',
  'ANNOTATION_END',
  'CLASS',
  'MEMBER',
  'NOTE_FOR',
  'NOTE',
  'CLASSDEF',
  'ALPHA',
  'COMMA',
  'direction_tb',
  'direction_bt',
  'direction_rl',
  'direction_lr',
  'AGGREGATION',
  'EXTENSION',
  'COMPOSITION',
  'DEPENDENCY',
  'LOLLIPOP',
  'LINE',
  'DOTTED_LINE',
  'CALLBACK',
  'LINK',
  'LINK_TARGET',
  'CLICK',
  'CALLBACK_NAME',
  'CALLBACK_ARGS',
  'HREF',
  'STYLE',
  'CSSCLASS',
  'COLON',
  'BRKT',
  'PCT',
  'MINUS',
  'UNICODE_TEXT',
  'BQUOTE_STR',
  'EDGE_STATE',
  'EOF_IN_STRUCT',
  'OPEN_IN_STRUCT',
  'PLUS',
  'EQUALS',
  'PUNCTUATION',
];
