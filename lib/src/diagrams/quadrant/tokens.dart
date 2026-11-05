// Upstream: src/diagrams/quadrant/tokens.ts

abstract final class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int NEWLINE = 2;
  static const int title = 3;
  static const int title_value = 4;
  static const int acc_title = 5;
  static const int acc_title_value = 6;
  static const int acc_descr = 7;
  static const int acc_descr_value = 8;
  static const int acc_descr_multiline_value = 9;
  static const int X_AXIS = 10;
  static const int Y_AXIS = 11;
  static const int DELIMITER = 12;
  static const int QUADRANT_1 = 13;
  static const int QUADRANT_2 = 14;
  static const int QUADRANT_3 = 15;
  static const int QUADRANT_4 = 16;
  static const int CLASSDEF = 17;
  static const int MD_STR = 18;
  static const int STR = 19;
  static const int class_name = 20;
  static const int point_start = 21;
  static const int point_x = 22;
  static const int point_y = 23;
  static const int QUADRANT = 24;
  static const int ALPHA = 25;
  static const int UNICODE_TEXT = 26;
  static const int COLON = 27;
  static const int PLUS = 28;
  static const int COMMA = 29;
  static const int EQUALS = 30;
  static const int MULT = 31;
  static const int BRKT = 32;
  static const int UNDERSCORE = 33;
  static const int DOT = 34;
  static const int AMP = 35;
  static const int MINUS = 36;
  static const int NUM = 37;
  static const int SPACE = 38;
  static const int SEMI = 39;
  static const int PUNCTUATION = 40;
  static const int EOF = 41;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'INVALID',
  'NEWLINE',
  'title',
  'title_value',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'X-AXIS',
  'Y-AXIS',
  'AXIS-TEXT-DELIMITER',
  'QUADRANT_1',
  'QUADRANT_2',
  'QUADRANT_3',
  'QUADRANT_4',
  'CLASSDEF',
  'MD_STR',
  'STR',
  'class_name',
  'point_start',
  'point_x',
  'point_y',
  'QUADRANT',
  'ALPHA',
  'UNICODE_TEXT',
  'COLON',
  'PLUS',
  'COMMA',
  'EQUALS',
  'MULT',
  'BRKT',
  'UNDERSCORE',
  'DOT',
  'AMP',
  'MINUS',
  'NUM',
  'SPACE',
  'SEMI',
  'PUNCTUATION',
  'EOF',
];
