// Upstream: src/diagrams/er/tokens.ts

abstract final class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int ER_DIAGRAM = 2;
  static const int EOF = 3;
  static const int NEWLINE = 4;
  static const int COLON = 5;
  static const int STYLE_SEPARATOR = 6;
  static const int BLOCK_START = 7;
  static const int BLOCK_STOP = 8;
  static const int SQS = 9;
  static const int SQE = 10;
  static const int acc_title = 11;
  static const int acc_title_value = 12;
  static const int acc_descr = 13;
  static const int acc_descr_value = 14;
  static const int acc_descr_multiline_value = 15;
  static const int END_KW = 16;
  static const int SUBGRAPH = 17;
  static const int direction_tb = 18;
  static const int direction_bt = 19;
  static const int direction_rl = 20;
  static const int direction_lr = 21;
  static const int CLASSDEF = 22;
  static const int UNICODE_TEXT = 23;
  static const int STYLE_TEXT = 24;
  static const int COMMA = 25;
  static const int CLASS = 26;
  static const int STYLE = 27;
  static const int SEMI = 28;
  static const int NUM = 29;
  static const int BRKT = 30;
  static const int ENTITY_NAME = 31;
  static const int DECIMAL_NUM = 32;
  static const int ENTITY_ONE = 33;
  static const int ATTRIBUTE_WORD = 34;
  static const int ATTRIBUTE_KEY = 35;
  static const int COMMENT = 36;
  static const int ZERO_OR_ONE = 37;
  static const int ZERO_OR_MORE = 38;
  static const int ONE_OR_MORE = 39;
  static const int ONLY_ONE = 40;
  static const int MD_PARENT = 41;
  static const int NON_IDENTIFYING = 42;
  static const int IDENTIFYING = 43;
  static const int WORD = 44;
  // A character no rule names; the grammar gives it meaning only as `?` and `,` inside a block.
  static const int CHAR = 45;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'INVALID',
  'ER_DIAGRAM',
  'EOF',
  'NEWLINE',
  'COLON',
  'STYLE_SEPARATOR',
  'BLOCK_START',
  'BLOCK_STOP',
  'SQS',
  'SQE',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'END',
  'SUBGRAPH',
  'direction_tb',
  'direction_bt',
  'direction_rl',
  'direction_lr',
  'CLASSDEF',
  'UNICODE_TEXT',
  'STYLE_TEXT',
  'COMMA',
  'CLASS',
  'STYLE',
  'SEMI',
  'NUM',
  'BRKT',
  'ENTITY_NAME',
  'DECIMAL_NUM',
  'ENTITY_ONE',
  'ATTRIBUTE_WORD',
  'ATTRIBUTE_KEY',
  'COMMENT',
  'ZERO_OR_ONE',
  'ZERO_OR_MORE',
  'ONE_OR_MORE',
  'ONLY_ONE',
  'MD_PARENT',
  'NON_IDENTIFYING',
  'IDENTIFYING',
  'WORD',
  'CHAR',
];
