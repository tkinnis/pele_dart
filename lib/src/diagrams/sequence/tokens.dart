// Upstream: src/diagrams/sequence/tokens.ts

abstract final class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int INVALID = 2;
  static const int NEWLINE = 3;
  static const int SD = 4;
  static const int create = 5;
  static const int box = 6;
  static const int restOfLine = 7;
  static const int end = 8;
  static const int autonumber = 9;
  static const int NUM = 10;
  static const int off = 11;
  static const int activate = 12;
  static const int deactivate = 13;
  static const int title = 14;
  static const int legacy_title = 15;
  static const int acc_title = 16;
  static const int acc_title_value = 17;
  static const int acc_descr = 18;
  static const int acc_descr_value = 19;
  static const int acc_descr_multiline_value = 20;
  static const int loop = 21;
  static const int rect = 22;
  static const int opt = 23;
  static const int alt = 24;
  static const int par = 25;
  static const int par_over = 26;
  static const int critical = 27;
  static const int break_ = 28;
  static const int option = 29;
  static const int and = 30;
  static const int else_ = 31;
  static const int participant = 32;
  static const int AS = 33;
  static const int participant_actor = 34;
  static const int destroy = 35;
  static const int note = 36;
  static const int over = 37;
  static const int links = 38;
  static const int link = 39;
  static const int properties = 40;
  static const int details = 41;
  static const int COMMA = 42;
  static const int left_of = 43;
  static const int right_of = 44;
  static const int PLUS = 45;
  static const int MINUS = 46;
  static const int CENTRAL = 47;
  static const int ACTOR = 48;
  static const int CONFIG_START = 49;
  static const int CONFIG_CONTENT = 50;
  static const int CONFIG_END = 51;
  static const int TXT = 52;
  static const int SOLID_OPEN_ARROW = 53;
  static const int DOTTED_OPEN_ARROW = 54;
  static const int SOLID_ARROW = 55;
  static const int BIDIRECTIONAL_SOLID_ARROW = 56;
  static const int DOTTED_ARROW = 57;
  static const int BIDIRECTIONAL_DOTTED_ARROW = 58;
  static const int SOLID_CROSS = 59;
  static const int DOTTED_CROSS = 60;
  static const int SOLID_POINT = 61;
  static const int DOTTED_POINT = 62;
  static const int SOLID_ARROW_TOP = 63;
  static const int SOLID_ARROW_BOTTOM = 64;
  static const int STICK_ARROW_TOP = 65;
  static const int STICK_ARROW_BOTTOM = 66;
  static const int SOLID_ARROW_TOP_DOTTED = 67;
  static const int SOLID_ARROW_BOTTOM_DOTTED = 68;
  static const int STICK_ARROW_TOP_DOTTED = 69;
  static const int STICK_ARROW_BOTTOM_DOTTED = 70;
  static const int SOLID_ARROW_TOP_REVERSE = 71;
  static const int SOLID_ARROW_BOTTOM_REVERSE = 72;
  static const int STICK_ARROW_TOP_REVERSE = 73;
  static const int STICK_ARROW_BOTTOM_REVERSE = 74;
  static const int SOLID_ARROW_TOP_REVERSE_DOTTED = 75;
  static const int SOLID_ARROW_BOTTOM_REVERSE_DOTTED = 76;
  static const int STICK_ARROW_TOP_REVERSE_DOTTED = 77;
  static const int STICK_ARROW_BOTTOM_REVERSE_DOTTED = 78;
}

/// Names as Mermaid's grammar spells them, for error messages and for comparison with its parser.
const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'INVALID',
  'INVALID',
  'NEWLINE',
  'SD',
  'create',
  'box',
  'restOfLine',
  'end',
  'autonumber',
  'NUM',
  'off',
  'activate',
  'deactivate',
  'title',
  'legacy_title',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'loop',
  'rect',
  'opt',
  'alt',
  'par',
  'par_over',
  'critical',
  'break',
  'option',
  'and',
  'else',
  'participant',
  'AS',
  'participant_actor',
  'destroy',
  'note',
  'over',
  'links',
  'link',
  'properties',
  'details',
  ',',
  'left_of',
  'right_of',
  '+',
  '-',
  '()',
  'ACTOR',
  'CONFIG_START',
  'CONFIG_CONTENT',
  'CONFIG_END',
  'TXT',
  'SOLID_OPEN_ARROW',
  'DOTTED_OPEN_ARROW',
  'SOLID_ARROW',
  'BIDIRECTIONAL_SOLID_ARROW',
  'DOTTED_ARROW',
  'BIDIRECTIONAL_DOTTED_ARROW',
  'SOLID_CROSS',
  'DOTTED_CROSS',
  'SOLID_POINT',
  'DOTTED_POINT',
  'SOLID_ARROW_TOP',
  'SOLID_ARROW_BOTTOM',
  'STICK_ARROW_TOP',
  'STICK_ARROW_BOTTOM',
  'SOLID_ARROW_TOP_DOTTED',
  'SOLID_ARROW_BOTTOM_DOTTED',
  'STICK_ARROW_TOP_DOTTED',
  'STICK_ARROW_BOTTOM_DOTTED',
  'SOLID_ARROW_TOP_REVERSE',
  'SOLID_ARROW_BOTTOM_REVERSE',
  'STICK_ARROW_TOP_REVERSE',
  'STICK_ARROW_BOTTOM_REVERSE',
  'SOLID_ARROW_TOP_REVERSE_DOTTED',
  'SOLID_ARROW_BOTTOM_REVERSE_DOTTED',
  'STICK_ARROW_TOP_REVERSE_DOTTED',
  'STICK_ARROW_BOTTOM_REVERSE_DOTTED',
];
