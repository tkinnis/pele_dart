// Upstream: src/diagrams/block/tokens.ts

class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int KEY = 2;
  static const int ID_BLOCK = 3;
  static const int COLUMNS = 4;
  static const int MD_STR = 5;
  static const int STR = 6;
  static const int SPACE_BLOCK = 7;
  static const int DEFAULT = 8;
  static const int LINKSTYLE = 9;
  static const int INTERPOLATE = 10;
  static const int CLASSDEF = 11;
  static const int DEFAULT_CLASSDEF_ID = 12;
  static const int CLASSDEF_ID = 13;
  static const int CLASSDEF_STYLEOPTS = 14;
  static const int CLASS = 15;
  static const int CLASSENTITY_IDS = 16;
  static const int STYLECLASS = 17;
  static const int STYLE = 18;
  static const int STYLE_ENTITY_IDS = 19;
  static const int STYLE_DEFINITION_DATA = 20;
  static const int acc_title = 21;
  static const int acc_title_value = 22;
  static const int acc_descr = 23;
  static const int acc_descr_value = 24;
  static const int acc_descr_multiline_value = 25;
  static const int end = 26;
  static const int NODE_DSTART = 27;
  static const int NODE_DEND = 28;
  static const int BLOCK_ARROW_START = 29;
  static const int BLOCK_ARROW_END = 30;
  static const int DIR = 31;
  static const int NODE_ID = 32;
  static const int LINK = 33;
  static const int START_LINK = 34;
  static const int LINK_LABEL = 35;
  static const int SIZE = 36;
  static const int EOF = 37;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'INVALID',
  'BLOCK_DIAGRAM_KEY',
  'id-block',
  'COLUMNS',
  'MD_STR',
  'STR',
  'SPACE_BLOCK',
  'DEFAULT',
  'LINKSTYLE',
  'INTERPOLATE',
  'classDef',
  'DEFAULT_CLASSDEF_ID',
  'CLASSDEF_ID',
  'CLASSDEF_STYLEOPTS',
  'class',
  'CLASSENTITY_IDS',
  'STYLECLASS',
  'style',
  'STYLE_ENTITY_IDS',
  'STYLE_DEFINITION_DATA',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'end',
  'NODE_DSTART',
  'NODE_DEND',
  'BLOCK_ARROW_START',
  'BLOCK_ARROW_END',
  'DIR',
  'NODE_ID',
  'LINK',
  'START_LINK',
  'LINK_LABEL',
  'SIZE',
  'EOF',
];
