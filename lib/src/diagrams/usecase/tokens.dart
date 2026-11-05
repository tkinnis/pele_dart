// Upstream: src/diagrams/usecase/tokens.ts

// Mermaid's token types, in an order that makes its token categories ranges:
// WORD is USECASE to IDENTIFIER, and LABEL_TEXT is USECASE to LABEL_SYMBOL.
abstract final class T {
  static const int EOF = 0;
  static const int USECASE = 1;
  static const int ACTOR = 2;
  static const int SYSTEM_BOUNDARY = 3;
  static const int END = 4;
  static const int DIRECTION = 5;
  static const int TD = 6;
  static const int TB = 7;
  static const int BT = 8;
  static const int LR = 9;
  static const int RL = 10;
  static const int NOTE = 11;
  static const int FOR = 12;
  static const int JSON = 13;
  static const int CLASS_DEF = 14;
  static const int CLASS = 15;
  static const int STYLE = 16;
  static const int INCLUDE = 17;
  static const int EXTEND = 18;
  static const int TRUE = 19;
  static const int FALSE = 20;
  static const int IDENTIFIER = 21;
  static const int NUMBER = 22;
  static const int AT = 23;
  static const int COMMA = 24;
  static const int COLON = 25;
  static const int HASH_COLOR = 26;
  static const int CSS_IDENTIFIER = 27;
  static const int CSS_ESCAPED_COMMA = 28;
  static const int DASH = 29;
  static const int DOT = 30;
  static const int PERCENT = 31;
  static const int CSS_PUNCTUATION = 32;
  static const int LABEL_PUNCTUATION = 33;
  static const int LABEL_SYMBOL = 34;
  static const int PLAIN_STRING = 35;
  static const int MARKDOWN_STRING = 36;
  static const int UNCLOSED_MARKDOWN_STRING = 37;
  static const int COMMENT = 38;
  static const int NEWLINE = 39;
  static const int ACC_DESCR_BLOCK = 40;
  static const int ACC_TITLE_LINE = 41;
  static const int ACC_DESCR_LINE = 42;
  static const int JSON_DECLARATION_START = 43;
  static const int JSON_OBJECT_LITERAL = 44;
  static const int UNCLOSED_JSON_OBJECT_LITERAL = 45;
  static const int GENERALIZATION = 46;
  static const int DEPENDENCY_ARROW = 47;
  static const int STEREOTYPE_START = 48;
  static const int STEREOTYPE_END = 49;
  static const int STEREOTYPE_TEXT = 50;
  static const int UNCLOSED_STEREOTYPE_TEXT = 51;
  static const int CLASS_SEPARATOR = 52;
  static const int FORWARD_SOLID = 53;
  static const int BACKWARD_SOLID = 54;
  static const int FORWARD_CIRCLE = 55;
  static const int BACKWARD_CIRCLE = 56;
  static const int FORWARD_CROSS = 57;
  static const int BACKWARD_CROSS = 58;
  static const int MARKERLESS_SOLID = 59;
  static const int METADATA_START = 60;
  static const int LBRACE = 61;
  static const int RBRACE = 62;
  static const int LBRACKET = 63;
  static const int RBRACKET = 64;
  static const int LPAREN = 65;
  static const int RPAREN = 66;
}

final List<String> TOKEN_NAMES = 'EOF USECASE ACTOR SYSTEM_BOUNDARY END DIRECTION TD TB BT LR RL NOTE FOR JSON CLASS_DEF CLASS STYLE INCLUDE EXTEND TRUE FALSE IDENTIFIER NUMBER AT COMMA COLON HASH_COLOR CSS_IDENTIFIER CSS_ESCAPED_COMMA DASH DOT PERCENT CSS_PUNCTUATION LABEL_PUNCTUATION LABEL_SYMBOL PLAIN_STRING MARKDOWN_STRING UNCLOSED_MARKDOWN_STRING COMMENT NEWLINE ACC_DESCR_BLOCK ACC_TITLE_LINE ACC_DESCR_LINE JSON_DECLARATION_START JSON_OBJECT_LITERAL UNCLOSED_JSON_OBJECT_LITERAL GENERALIZATION DEPENDENCY_ARROW STEREOTYPE_START STEREOTYPE_END STEREOTYPE_TEXT UNCLOSED_STEREOTYPE_TEXT CLASS_SEPARATOR FORWARD_SOLID BACKWARD_SOLID FORWARD_CIRCLE BACKWARD_CIRCLE FORWARD_CROSS BACKWARD_CROSS MARKERLESS_SOLID METADATA_START LBRACE RBRACE LBRACKET RBRACKET LPAREN RPAREN'
    .split(' ');
