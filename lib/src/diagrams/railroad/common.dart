// Upstream: src/diagrams/railroad/common.ts

import '../../util/chars.dart' as chars;
import '../../util/math_js.dart';
import '../common/tokens.dart'
    show
        DIRECTIVE,
        Reader,
        SINGLE_LINE_COMMENT,
        Scanner,
        TokenType,
        YAML,
        accDescrValue,
        accTitleValue,
        keyword,
        titleValue,
        tokenize;
import 'types.dart';

// What the four railroad grammars share: the title and accessibility tokens (which, unlike
// the ones in Mermaid's common grammar, do not take leading blanks), the hidden tokens, the
// statements before the first rule, string values, and the walk from a syntax tree to the rule model.

bool isSpace(int c) => chars.isSpace(c);

// The braced form scans to the next closing brace. Once none is found, none exists further on
// either, so later braced descriptions fail without scanning again.
Scanner _accDescrScanner() {
  var unclosed = 1 << 30;
  return (src, at, _) {
    if (!src.startsWith('accDescr', at)) return -1;
    final n = src.length;
    var i = at + 8;
    while (i < n && (charCodeAt(src, i) == 32 || charCodeAt(src, i) == 9)) {
      i++;
    }
    if (charCodeAt(src, i) == 58) {
      for (i++; i < n; i++) {
        final c = charCodeAt(src, i);
        if (c == 10 || c == 13 || (c == 37 && charCodeAt(src, i + 1) == 37)) {
          break;
        }
      }
      return i;
    }
    while (i < n && isSpace(charCodeAt(src, i))) {
      i++;
    }
    if (charCodeAt(src, i) != 123 || i >= unclosed) return -1;
    final close = src.indexOf('}', i + 1);
    if (close == -1) {
      unclosed = i;
      return -1;
    }
    return close + 1;
  };
}

const String LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

// `rest` matches a name suffix so `title` does not split longer names.
TokenType title(String rest) {
  return TokenType(
    name: 'TITLE',
    pattern: RegExp(
      'title(?:[\\t ][^\\n\\r]*?(?=%%)|[\\t ][^\\n\\r]*|(?!$rest))',
    ),
    first: 't',
  );
}

final TokenType ACC_TITLE = TokenType(
  name: 'ACC_TITLE',
  pattern: RegExp(r'accTitle[\t ]*:(?:[^\n\r]*?(?=%%)|[^\n\r]*)'),
  first: 'a',
);

final TokenType ACC_DESCR = TokenType(
  name: 'ACC_DESCR',
  pattern: RegExp(
    r'accDescr(?:[\t ]*:([^\n\r]*?(?=%%)|[^\n\r]*)|\s*\{([^}]*)\})',
  ),
  first: 'a',
  scanner: _accDescrScanner,
);

TokenType literal(String name, [List<TokenType>? longer]) {
  return TokenType(name: name, pattern: name, longer: longer);
}

// The diagram's keyword. A name that starts with it and goes on is a name.
TokenType opening(String word, TokenType name) {
  final kw = keyword(word);
  return TokenType(
    name: kw.name,
    pattern: kw.pattern,
    first: kw.first,
    longer: <TokenType>[name],
  );
}

TokenType identifier(String name) {
  return TokenType(
    name: name,
    pattern: RegExp(r'[A-Z_a-z][\w-]*'),
    first: '${LETTERS}_',
  );
}

TokenType quoted(String name) {
  return TokenType(
    name: name,
    pattern: RegExp(
      r'"([^"\\]|\\.)*"|'
      "'"
      r"([^'\\]|\\.)*'",
    ),
    first: '"\'',
  );
}

// Whitespace, front matter, directive, and `%%` comment, in the order every railroad grammar lists them.
List<TokenType> hiddenTokens(String prefix) {
  return <TokenType>[
    TokenType(
      name: '${prefix}_WHITESPACE',
      pattern: RegExp(r'[\t \r\n]+'),
      hidden: true,
      first: '\t \r\n',
    ),
    TokenType(
      name: '${prefix}_YAML',
      pattern: YAML.pattern,
      hidden: true,
      opener: YAML.opener,
      first: '-',
    ),
    TokenType(
      name: '${prefix}_DIRECTIVE',
      pattern: DIRECTIVE.pattern,
      hidden: true,
      opener: DIRECTIVE.opener,
      first: '\t %',
    ),
    TokenType(
      name: '${prefix}_SINGLE_LINE_COMMENT',
      pattern: SINGLE_LINE_COMMENT.pattern,
      hidden: true,
      first: '\t %',
    ),
  ];
}

// Mermaid's railroad value converters know three escapes; any other escaped character stands for itself.
String unescape(String text) {
  if (!text.contains(r'\')) return text.substring(1, text.length - 1);
  final end = text.length - 1;
  final out = StringBuffer();
  for (var i = 1; i < end; i++) {
    var c = text[i];
    if (c == r'\' && i + 1 < end) {
      c = text[++i];
      out.write(c == 'n' ? '\n' : (c == 'r' ? '\r' : (c == 't' ? '\t' : c)));
    } else {
      out.write(c);
    }
  }
  return out.toString();
}

abstract interface class RuleNode<Part> {
  String get name;
  Part get definition;
}

class Grammar<Rule> {
  Grammar({
    required this.$type,
    required this.rules,
    this.title,
    this.accTitle,
    this.accDescr,
  });

  final String $type;
  String? title;
  String? accTitle;
  String? accDescr;
  final List<Rule> rules;
}

// Parses the keyword, then any titles and accessibility statements, then rules to the end of the text.
// Every table starts with its keyword and has TITLE, ACC_TITLE, and ACC_DESCR in a row from `meta`.
Grammar<Rule> parseGrammar<Rule>(
  String src,
  List<TokenType> types,
  String $type,
  int meta,
  String Function(String text) unquote,
  Rule Function(Reader r) rule,
) {
  final r = Reader(tokenize(src, types, 'railroad'), types, 'railroad');
  final ast = Grammar<Rule>($type: $type, rules: <Rule>[]);
  r.expect(0);
  for (;;) {
    final kind = r.kind;
    if (kind == meta) {
      final t = titleValue(r.take());
      final quote = charAtOrNull(t, 0);
      ast.title =
          t.length >= 2 && (quote == '"' || quote == "'") && t.endsWith(quote!)
          ? unquote(t)
          : t;
    } else if (kind == meta + 1) {
      ast.accTitle = accTitleValue(r.take());
    } else if (kind == meta + 2) {
      ast.accDescr = accDescrValue(r.take());
    } else {
      break;
    }
  }
  while (r.kind != -1) {
    ast.rules.add(rule(r));
  }
  return ast;
}

const List<Never> NONE = <Never>[];

List<T> parts<T>(T node) {
  return (node as HasParts<T>).nodeParts;
}

RailroadNode terminal(String value) => RailroadNode.terminal(value);
RailroadNode nonterminal(String name) => RailroadNode.nonterminal(name);
RailroadNode special(String text) => RailroadNode.special(text);
RailroadNode optional(RailroadNode element) => RailroadNode.optional(element);
RailroadNode repetition(
  RailroadNode element,
  double min, [
  double max = double.infinity,
]) => RailroadNode.repetition(element, min, max);

// A sequence or a choice of one is that one, in every notation.
RailroadNode sequence(List<RailroadNode> elements) {
  return elements.length == 1 ? elements[0] : RailroadNode.sequence(elements);
}

RailroadNode choice(List<RailroadNode> alternatives) {
  return alternatives.length == 1
      ? alternatives[0]
      : RailroadNode.choice(alternatives);
}

// Turns each rule's syntax tree into the common model, given how one node is built from its parts.
List<RailroadRule> toRules<Part>(
  Grammar<RuleNode<Part>> ast,
  RailroadNode Function(Part part, List<RailroadNode> kids) build,
) {
  return <RailroadRule>[
    for (final rule in ast.rules)
      RailroadRule(
        name: rule.name,
        definition: fold<Part, RailroadNode>(rule.definition, parts, build),
      ),
  ];
}

// Rebuilds a tree bottom-up without recursion, so that nesting depth is bounded by memory, not by the stack.
R fold<T, R>(
  T root,
  List<T> Function(T node) children,
  R Function(T node, List<R> results) build,
) {
  final nodes = <T>[root];
  final lists = <List<T>>[children(root)];
  final done = <List<R>>[<R>[]];
  for (;;) {
    final top = nodes.length - 1;
    final results = done[top];
    if (results.length < lists[top].length) {
      final child = lists[top][results.length];
      nodes.add(child);
      lists.add(children(child));
      done.add(<R>[]);
    } else {
      final value = build(nodes[top], results);
      if (top == 0) return value;
      nodes.removeLast();
      lists.removeLast();
      done.removeLast();
      done[top - 1].add(value);
    }
  }
}
