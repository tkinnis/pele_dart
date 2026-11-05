// Upstream: src/diagrams/c4/tokens.ts

abstract final class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int direction_tb = 2;
  static const int direction_bt = 3;
  static const int direction_rl = 4;
  static const int direction_lr = 5;
  static const int title = 6;
  static const int accDescription = 7;
  static const int acc_title = 8;
  static const int acc_title_value = 9;
  static const int acc_descr = 10;
  static const int acc_descr_value = 11;
  static const int acc_descr_multiline_value = 12;
  static const int NEWLINE = 13;
  static const int C4_CONTEXT = 14;
  static const int C4_CONTAINER = 15;
  static const int C4_COMPONENT = 16;
  static const int C4_DYNAMIC = 17;
  static const int C4_DEPLOYMENT = 18;
  static const int PERSON = 19;
  static const int PERSON_EXT = 20;
  static const int SYSTEM = 21;
  static const int SYSTEM_DB = 22;
  static const int SYSTEM_QUEUE = 23;
  static const int SYSTEM_EXT = 24;
  static const int SYSTEM_EXT_DB = 25;
  static const int SYSTEM_EXT_QUEUE = 26;
  static const int CONTAINER = 27;
  static const int CONTAINER_DB = 28;
  static const int CONTAINER_QUEUE = 29;
  static const int CONTAINER_EXT = 30;
  static const int CONTAINER_EXT_DB = 31;
  static const int CONTAINER_EXT_QUEUE = 32;
  static const int COMPONENT = 33;
  static const int COMPONENT_DB = 34;
  static const int COMPONENT_QUEUE = 35;
  static const int COMPONENT_EXT = 36;
  static const int COMPONENT_EXT_DB = 37;
  static const int COMPONENT_EXT_QUEUE = 38;
  static const int ENTERPRISE_BOUNDARY = 39;
  static const int SYSTEM_BOUNDARY = 40;
  static const int BOUNDARY = 41;
  static const int CONTAINER_BOUNDARY = 42;
  static const int NODE = 43;
  static const int NODE_L = 44;
  static const int NODE_R = 45;
  static const int REL = 46;
  static const int BIREL = 47;
  static const int REL_U = 48;
  static const int REL_D = 49;
  static const int REL_L = 50;
  static const int REL_R = 51;
  static const int REL_B = 52;
  static const int REL_INDEX = 53;
  static const int UPDATE_EL_STYLE = 54;
  static const int UPDATE_REL_STYLE = 55;
  static const int UPDATE_LAYOUT_CONFIG = 56;
  static const int EOF_IN_STRUCT = 57;
  static const int ATTRIBUTE_EMPTY = 58;
  static const int STR = 59;
  static const int STR_KEY = 60;
  static const int STR_VALUE = 61;
  static const int LBRACE = 62;
  static const int RBRACE = 63;
  static const int EOF = 64;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'INVALID',
  'direction_tb',
  'direction_bt',
  'direction_rl',
  'direction_lr',
  'title',
  'accDescription',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'NEWLINE',
  'C4_CONTEXT',
  'C4_CONTAINER',
  'C4_COMPONENT',
  'C4_DYNAMIC',
  'C4_DEPLOYMENT',
  'PERSON',
  'PERSON_EXT',
  'SYSTEM',
  'SYSTEM_DB',
  'SYSTEM_QUEUE',
  'SYSTEM_EXT',
  'SYSTEM_EXT_DB',
  'SYSTEM_EXT_QUEUE',
  'CONTAINER',
  'CONTAINER_DB',
  'CONTAINER_QUEUE',
  'CONTAINER_EXT',
  'CONTAINER_EXT_DB',
  'CONTAINER_EXT_QUEUE',
  'COMPONENT',
  'COMPONENT_DB',
  'COMPONENT_QUEUE',
  'COMPONENT_EXT',
  'COMPONENT_EXT_DB',
  'COMPONENT_EXT_QUEUE',
  'ENTERPRISE_BOUNDARY',
  'SYSTEM_BOUNDARY',
  'BOUNDARY',
  'CONTAINER_BOUNDARY',
  'NODE',
  'NODE_L',
  'NODE_R',
  'REL',
  'BIREL',
  'REL_U',
  'REL_D',
  'REL_L',
  'REL_R',
  'REL_B',
  'REL_INDEX',
  'UPDATE_EL_STYLE',
  'UPDATE_REL_STYLE',
  'UPDATE_LAYOUT_CONFIG',
  'EOF_IN_STRUCT',
  'ATTRIBUTE_EMPTY',
  'STR',
  'STR_KEY',
  'STR_VALUE',
  'LBRACE',
  'RBRACE',
  'EOF',
];
