// Upstream: src/diagrams/mindmap/parser.ts

import '../common/outline.dart' as outline;

export '../common/outline.dart' show OutlineDb, Tokens;

outline.Tokens tokenize(String src) {
  return outline.tokenize(src, false);
}

void parseMindmap(String src, outline.OutlineDb db) {
  outline.parseOutline(src, db, false);
}
