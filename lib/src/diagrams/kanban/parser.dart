// Upstream: src/diagrams/kanban/parser.ts

import '../common/outline.dart' as outline;

outline.Tokens tokenize(String src) {
  return outline.tokenize(src, true);
}

void parseKanban(String src, outline.OutlineDb db) {
  outline.parseOutline(src, db, true);
}
