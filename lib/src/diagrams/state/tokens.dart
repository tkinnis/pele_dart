// Upstream: src/diagrams/state/tokens.ts

abstract final class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int NL = 2;
  static const int SD = 3;
  static const int DESCR = 4;
  static const int ARROW = 5;
  static const int HIDE_EMPTY = 6;
  static const int scale = 7;
  static const int WIDTH = 8;
  static const int COMPOSIT_STATE = 9;
  static const int STRUCT_START = 10;
  static const int STRUCT_STOP = 11;
  static const int STATE_DESCR = 12;
  static const int AS = 13;
  static const int ID = 14;
  static const int FORK = 15;
  static const int JOIN = 16;
  static const int CHOICE = 17;
  static const int CONCURRENT = 18;
  static const int note = 19;
  static const int NOTE_TEXT = 20;
  static const int acc_title = 21;
  static const int acc_title_value = 22;
  static const int acc_descr = 23;
  static const int acc_descr_value = 24;
  static const int acc_descr_multiline_value = 25;
  static const int CLICK = 26;
  static const int STRING = 27;
  static const int HREF = 28;
  static const int classDef = 29;
  static const int CLASSDEF_ID = 30;
  static const int DEFAULT_CLASSDEF_ID = 31;
  static const int CLASSDEF_STYLEOPTS = 32;
  static const int DEFAULT = 33;
  static const int style = 34;
  static const int STYLE_IDS = 35;
  static const int STYLEDEF_STYLEOPTS = 36;
  static const int classKw = 37;
  static const int CLASSENTITY_IDS = 38;
  static const int STYLECLASS = 39;
  static const int direction_tb = 40;
  static const int direction_bt = 41;
  static const int direction_rl = 42;
  static const int direction_lr = 43;
  static const int EDGE_STATE = 44;
  static const int STYLE_SEPARATOR = 45;
  static const int left_of = 46;
  static const int right_of = 47;
  static const int INVALID = 48;
}

const List<String> tokenNames = <String>[
  r'$end',
  'INVALID',
  'NL',
  'SD',
  'DESCR',
  '-->',
  'HIDE_EMPTY',
  'scale',
  'WIDTH',
  'COMPOSIT_STATE',
  'STRUCT_START',
  'STRUCT_STOP',
  'STATE_DESCR',
  'AS',
  'ID',
  'FORK',
  'JOIN',
  'CHOICE',
  'CONCURRENT',
  'note',
  'NOTE_TEXT',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'CLICK',
  'STRING',
  'HREF',
  'classDef',
  'CLASSDEF_ID',
  'DEFAULT_CLASSDEF_ID',
  'CLASSDEF_STYLEOPTS',
  'DEFAULT',
  'style',
  'STYLE_IDS',
  'STYLEDEF_STYLEOPTS',
  'class',
  'CLASSENTITY_IDS',
  'STYLECLASS',
  'direction_tb',
  'direction_bt',
  'direction_rl',
  'direction_lr',
  'EDGE_STATE',
  'STYLE_SEPARATOR',
  'left_of',
  'right_of',
  'INVALID',
];
