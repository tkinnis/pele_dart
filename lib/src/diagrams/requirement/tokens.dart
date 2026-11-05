// Upstream: src/diagrams/requirement/tokens.ts

abstract final class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int title = 2;
  static const int acc_title = 3;
  static const int acc_title_value = 4;
  static const int acc_descr = 5;
  static const int acc_descr_value = 6;
  static const int acc_descr_multiline_value = 7;
  static const int direction_tb = 8;
  static const int direction_bt = 9;
  static const int direction_rl = 10;
  static const int direction_lr = 11;
  static const int NEWLINE = 12;
  static const int EOF = 13;
  static const int RD = 14;
  static const int STRUCT_START = 15;
  static const int STRUCT_STOP = 16;
  static const int STYLE_SEPARATOR = 17;
  static const int COLONSEP = 18;
  static const int ID = 19;
  static const int TEXT = 20;
  static const int RISK = 21;
  static const int VERIFYMTHD = 22;
  static const int REQUIREMENT = 23;
  static const int FUNCTIONAL_REQUIREMENT = 24;
  static const int INTERFACE_REQUIREMENT = 25;
  static const int PERFORMANCE_REQUIREMENT = 26;
  static const int PHYSICAL_REQUIREMENT = 27;
  static const int DESIGN_CONSTRAINT = 28;
  static const int LOW_RISK = 29;
  static const int MED_RISK = 30;
  static const int HIGH_RISK = 31;
  static const int VERIFY_ANALYSIS = 32;
  static const int VERIFY_DEMONSTRATION = 33;
  static const int VERIFY_INSPECTION = 34;
  static const int VERIFY_TEST = 35;
  static const int ELEMENT = 36;
  static const int CONTAINS = 37;
  static const int COPIES = 38;
  static const int DERIVES = 39;
  static const int SATISFIES = 40;
  static const int VERIFIES = 41;
  static const int REFINES = 42;
  static const int TRACES = 43;
  static const int TYPE = 44;
  static const int DOCREF = 45;
  static const int STYLE = 46;
  static const int CLASSDEF = 47;
  static const int CLASS = 48;
  static const int ALPHA = 49;
  static const int COLON = 50;
  static const int SEMICOLON = 51;
  static const int PERCENT = 52;
  static const int MINUS = 53;
  static const int BRKT = 54;
  static const int END_ARROW_L = 55;
  static const int END_ARROW_R = 56;
  static const int LINE = 57;
  static const int qString = 58;
  static const int unqString = 59;
  static const int COMMA = 60;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'INVALID',
  'title',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'direction_tb',
  'direction_bt',
  'direction_rl',
  'direction_lr',
  'NEWLINE',
  'EOF',
  'RD',
  'STRUCT_START',
  'STRUCT_STOP',
  'STYLE_SEPARATOR',
  'COLONSEP',
  'ID',
  'TEXT',
  'RISK',
  'VERIFYMTHD',
  'REQUIREMENT',
  'FUNCTIONAL_REQUIREMENT',
  'INTERFACE_REQUIREMENT',
  'PERFORMANCE_REQUIREMENT',
  'PHYSICAL_REQUIREMENT',
  'DESIGN_CONSTRAINT',
  'LOW_RISK',
  'MED_RISK',
  'HIGH_RISK',
  'VERIFY_ANALYSIS',
  'VERIFY_DEMONSTRATION',
  'VERIFY_INSPECTION',
  'VERIFY_TEST',
  'ELEMENT',
  'CONTAINS',
  'COPIES',
  'DERIVES',
  'SATISFIES',
  'VERIFIES',
  'REFINES',
  'TRACES',
  'TYPE',
  'DOCREF',
  'STYLE',
  'CLASSDEF',
  'CLASS',
  'ALPHA',
  'COLON',
  'SEMICOLON',
  'PERCENT',
  'MINUS',
  'BRKT',
  'END_ARROW_L',
  'END_ARROW_R',
  'LINE',
  'qString',
  'unqString',
  'COMMA',
];

/// Every keyword is matched without regard to case and must end at a word boundary.
const Map<String, int> KEYWORDS = <String, int>{
  'requirementdiagram': T.RD,
  'id': T.ID,
  'text': T.TEXT,
  'risk': T.RISK,
  'verifymethod': T.VERIFYMTHD,
  'requirement': T.REQUIREMENT,
  'functionalrequirement': T.FUNCTIONAL_REQUIREMENT,
  'interfacerequirement': T.INTERFACE_REQUIREMENT,
  'performancerequirement': T.PERFORMANCE_REQUIREMENT,
  'physicalrequirement': T.PHYSICAL_REQUIREMENT,
  'designconstraint': T.DESIGN_CONSTRAINT,
  'low': T.LOW_RISK,
  'medium': T.MED_RISK,
  'high': T.HIGH_RISK,
  'analysis': T.VERIFY_ANALYSIS,
  'demonstration': T.VERIFY_DEMONSTRATION,
  'inspection': T.VERIFY_INSPECTION,
  'test': T.VERIFY_TEST,
  'element': T.ELEMENT,
  'contains': T.CONTAINS,
  'copies': T.COPIES,
  'derives': T.DERIVES,
  'satisfies': T.SATISFIES,
  'verifies': T.VERIFIES,
  'refines': T.REFINES,
  'traces': T.TRACES,
  'type': T.TYPE,
  'docref': T.DOCREF,
  'style': T.STYLE,
  'classdef': T.CLASSDEF,
  'class': T.CLASS,
};
