// Upstream: src/diagrams/xychart/tokens.ts

class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int NEWLINE = 2;
  static const int title = 3;
  static const int acc_title = 4;
  static const int acc_title_value = 5;
  static const int acc_descr = 6;
  static const int acc_descr_value = 7;
  static const int acc_descr_multiline_value = 8;
  static const int XYCHART = 9;
  static const int CHART_ORIENTATION = 10;
  static const int X_AXIS = 11;
  static const int Y_AXIS = 12;
  static const int ARROW_DELIMITER = 13;
  static const int LINE = 14;
  static const int BAR = 15;
  static const int NUMBER_WITH_DECIMAL = 16;
  static const int SQUARE_BRACES_START = 17;
  static const int SQUARE_BRACES_END = 18;
  static const int STR = 19;
  static const int ALPHA = 20;
  static const int COLON = 21;
  static const int PLUS = 22;
  static const int COMMA = 23;
  static const int EQUALS = 24;
  static const int MULT = 25;
  static const int BRKT = 26;
  static const int UNDERSCORE = 27;
  static const int DOT = 28;
  static const int AMP = 29;
  static const int MINUS = 30;
  static const int NUM = 31;
  static const int SEMI = 32;
  static const int EOF = 33;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'INVALID',
  'NEWLINE',
  'title',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'XYCHART',
  'CHART_ORIENTATION',
  'X_AXIS',
  'Y_AXIS',
  'ARROW_DELIMITER',
  'LINE',
  'BAR',
  'NUMBER_WITH_DECIMAL',
  'SQUARE_BRACES_START',
  'SQUARE_BRACES_END',
  'STR',
  'ALPHA',
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
  'SEMI',
  'EOF',
];
