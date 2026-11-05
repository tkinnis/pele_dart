// Upstream: src/diagrams/wardley/parser.ts

import '../../util/math_js.dart';
import '../common/acc_descr.dart';
import '../common/tokens.dart';

class _T {
  static const int lbracket = 0;
  static const int comma = 1;
  static const int rbracket = 2;
  static const int at = 3;
  static const int slash = 4;
  static const int lparen = 5;
  static const int rparen = 6;
  static const int minus = 7;
  static const int lbrace = 8;
  static const int rbrace = 9;
  static const int number = 10;
  static const int arrow = 11;
  static const int linkPort = 12;
  static const int linkArrow = 13;
  static const int linkLabel = 14;
  static const int strategy = 15;
  static const int wardley = 16;
  static const int size = 17;
  static const int evolution = 18;
  static const int anchor = 19;
  static const int component = 20;
  static const int label = 21;
  static const int inertia = 22;
  static const int evolve = 23;
  static const int pipeline = 24;
  static const int note = 25;
  static const int annotations = 26;
  static const int annotation = 27;
  static const int accelerator = 28;
  static const int deaccelerator = 29;
  static const int name = 30;
  static const int accDescr = 32;
  static const int accTitle = 33;
  static const int title = 34;
  static const int intTok = 35;
  static const int string = 36;
  static const int id = 37;
  static const int newline = 38;
}

int _digits(String src, int from) {
  var i = from;
  for (var c = charCodeAt(src, i); c >= 48 && c <= 57; c = charCodeAt(src, i)) {
    i++;
  }
  return i;
}

// Answers as WARDLEY_NUMBER's pattern does. The pattern reads a whole run of digits before it
// finds there is no fraction, and would do so again from every digit of a long run.
Scanner _numberScanner() {
  var from = 0;
  var end = 0;
  return (src, p, _) {
    if (p < from || p >= end) {
      from = p;
      end = _digits(src, p);
    }
    if (end == p || charCodeAt(src, end) != 46) return -1;
    final stop = _digits(src, end + 1);
    return stop > end + 1 ? stop : -1;
  };
}

final TokenType _arrow = TokenType(
  name: 'ARROW',
  pattern: RegExp(r'->'),
  first: '-',
);
final TokenType _linkArrow = TokenType(
  name: 'LINK_ARROW',
  pattern: RegExp(r"-->|-\.->|>|\+'[^']*'<>|\+'[^']*'<|\+'[^']*'>"),
  first: '->+',
);
TokenType _word(String name, String text) =>
    TokenType(name: name, pattern: RegExp(text), first: text[0]);

final List<TokenType> WARDLEY_TOKENS = <TokenType>[
  const TokenType(name: '[', pattern: '['),
  const TokenType(name: ',', pattern: ','),
  const TokenType(name: ']', pattern: ']'),
  const TokenType(name: '@', pattern: '@'),
  const TokenType(name: '/', pattern: '/'),
  const TokenType(name: '(', pattern: '('),
  const TokenType(name: ')', pattern: ')'),
  TokenType(
    name: '-',
    pattern: '-',
    longer: <TokenType>[_arrow, _linkArrow, YAML],
  ),
  const TokenType(name: '{', pattern: '{'),
  const TokenType(name: '}', pattern: '}'),
  TokenType(
    name: 'WARDLEY_NUMBER',
    pattern: RegExp(r'[0-9]+\.[0-9]+'),
    first: '0123456789',
    scanner: _numberScanner,
  ),
  _arrow,
  TokenType(name: 'LINK_PORT', pattern: RegExp(r'\+<>|\+>|\+<'), first: '+'),
  _linkArrow,
  TokenType(name: 'LINK_LABEL', pattern: RegExp(r';[^\n\r]+'), first: ';'),
  TokenType(
    name: 'STRATEGY',
    pattern: RegExp(r'build|buy|outsource|market'),
    first: 'bom',
  ),
  _word('KW_WARDLEY', 'wardley-beta'),
  _word('KW_SIZE', 'size'),
  _word('KW_EVOLUTION', 'evolution'),
  _word('KW_ANCHOR', 'anchor'),
  _word('KW_COMPONENT', 'component'),
  _word('KW_LABEL', 'label'),
  _word('KW_INERTIA', 'inertia'),
  _word('KW_EVOLVE', 'evolve'),
  _word('KW_PIPELINE', 'pipeline'),
  _word('KW_NOTE', 'note'),
  _word('KW_ANNOTATIONS', 'annotations'),
  _word('KW_ANNOTATION', 'annotation'),
  _word('KW_ACCELERATOR', 'accelerator'),
  _word('KW_DEACCELERATOR', 'deaccelerator'),
  TokenType(
    name: 'NAME_WITH_SPACES',
    pattern: RegExp(
      r'(?!title\s|accTitle|accDescr)[A-Za-z](?:[A-Za-z0-9_()&]|-(?!>))*(?:[ \t]+[A-Za-z(](?:[A-Za-z0-9_()&]|-(?!>))*)*',
    ),
    first: 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz',
  ),
  TokenType(name: 'WS', pattern: RegExp(r'[ \t]+'), hidden: true, first: '\t '),
  accDescr(),
  ACC_TITLE,
  TITLE,
  TokenType(
    name: 'INT',
    pattern: RegExp(r'0|[1-9][0-9]*(?!\.)'),
    first: '0123456789',
  ),
  STRING,
  TokenType(
    name: 'ID',
    pattern: RegExp(r'[\w]([-\w]*\w)?'),
    first: '_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz',
  ),
  NEWLINE,
  WHITESPACE,
  YAML,
  DIRECTIVE,
  SINGLE_LINE_COMMENT,
];

class LabelAst {
  final String $type = 'Label';
  final bool negX;
  final double offsetX;
  final bool negY;
  final double offsetY;

  const LabelAst({
    required this.negX,
    required this.offsetX,
    required this.negY,
    required this.offsetY,
  });
}

class StageAst {
  final String $type = 'EvolutionStage';
  final String name;
  double? boundary;
  String? secondName;

  StageAst({required this.name, this.boundary, this.secondName});
}

class DecoratorAst {
  final String $type = 'Decorator';
  final String strategy;

  const DecoratorAst({required this.strategy});
}

class ComponentAst {
  final String $type = 'Component';
  final String name;
  double visibility;
  double evolution;
  LabelAst? label;
  DecoratorAst? decorator;
  bool inertia;

  ComponentAst({
    required this.name,
    this.visibility = 0,
    this.evolution = 0,
    this.label,
    this.decorator,
    this.inertia = false,
  });
}

class PipelineComponentAst {
  final String $type = 'PipelineComponent';
  final String name;
  double evolution;
  LabelAst? label;

  PipelineComponentAst({required this.name, this.evolution = 0, this.label});
}

class LinkAst {
  final String $type = 'Link';
  final String from;
  String? fromPort;
  String? arrow;
  String to;
  String? toPort;
  String? linkLabel;

  LinkAst({
    required this.from,
    this.fromPort,
    this.arrow,
    this.to = '',
    this.toPort,
    this.linkLabel,
  });
}

class SizeAst {
  final String $type = 'Size';
  final double width;
  final double height;

  const SizeAst({required this.width, required this.height});
}

class EvolutionAst {
  final String $type = 'Evolution';
  final List<StageAst> stages;

  const EvolutionAst({required this.stages});
}

class AnchorAst {
  final String $type = 'Anchor';
  final String name;
  final double visibility;
  final double evolution;

  const AnchorAst({
    required this.name,
    required this.visibility,
    required this.evolution,
  });
}

class EvolveAst {
  final String $type = 'Evolve';
  final String component;
  final double target;

  const EvolveAst({required this.component, required this.target});
}

class PipelineAst {
  final String $type = 'Pipeline';
  final String parent;
  final List<PipelineComponentAst> components;

  const PipelineAst({required this.parent, required this.components});
}

class NoteAst {
  final String $type = 'Note';
  final String text;
  final double visibility;
  final double evolution;

  const NoteAst({
    required this.text,
    required this.visibility,
    required this.evolution,
  });
}

class AnnotationsBoxAst {
  final String $type = 'Annotations';
  final double x;
  final double y;

  const AnnotationsBoxAst({required this.x, required this.y});
}

class AnnotationAst {
  final String $type = 'Annotation';
  final int number;
  final double x;
  final double y;
  final String text;

  const AnnotationAst({
    required this.number,
    required this.x,
    required this.y,
    required this.text,
  });
}

class ForceAst {
  final String $type;
  final String name;
  final double x;
  final double y;

  const ForceAst({
    required this.$type,
    required this.name,
    required this.x,
    required this.y,
  });
}

class WardleyAst {
  final String $type = 'Wardley';
  String? title;
  String? accTitle;
  String? accDescr;
  SizeAst? size;
  EvolutionAst? evolution;
  final List<AnchorAst> anchors;
  final List<ComponentAst> components;
  final List<LinkAst> links;
  final List<EvolveAst> evolves;
  final List<PipelineAst> pipelines;
  final List<NoteAst> notes;
  final List<AnnotationsBoxAst> annotations;
  final List<AnnotationAst> annotation;
  final List<ForceAst> accelerators;
  final List<ForceAst> deaccelerators;

  WardleyAst({
    this.title,
    this.accTitle,
    this.accDescr,
    this.size,
    this.evolution,
    List<AnchorAst>? anchors,
    List<ComponentAst>? components,
    List<LinkAst>? links,
    List<EvolveAst>? evolves,
    List<PipelineAst>? pipelines,
    List<NoteAst>? notes,
    List<AnnotationsBoxAst>? annotations,
    List<AnnotationAst>? annotation,
    List<ForceAst>? accelerators,
    List<ForceAst>? deaccelerators,
  }) : anchors = anchors ?? <AnchorAst>[],
       components = components ?? <ComponentAst>[],
       links = links ?? <LinkAst>[],
       evolves = evolves ?? <EvolveAst>[],
       pipelines = pipelines ?? <PipelineAst>[],
       notes = notes ?? <NoteAst>[],
       annotations = annotations ?? <AnnotationsBoxAst>[],
       annotation = annotation ?? <AnnotationAst>[],
       accelerators = accelerators ?? <ForceAst>[],
       deaccelerators = deaccelerators ?? <ForceAst>[];
}

WardleyAst parseWardley(String src) {
  final r = Reader(
    tokenize(src, WARDLEY_TOKENS, 'wardley'),
    WARDLEY_TOKENS,
    'wardley',
  );
  final ast = WardleyAst();

  bool at(int kind) => r.kinds[r.i] == kind;
  bool isName() => at(_T.string) || at(_T.id) || at(_T.name);
  String name() {
    if (at(_T.string)) return stringValue(r.take());
    if (at(_T.id) || at(_T.name)) return r.take();
    return r.fail('a name');
  }

  double number() => double.parse(r.expect(_T.number));
  int intVal() => int.parse(r.expect(_T.intTok));
  double intAsDouble() => intVal().toDouble();
  double coordinate() =>
      at(_T.number) ? double.parse(r.take()) : intVal().toDouble();
  void endOfLine() {
    if (at(-1)) return;
    if (!at(_T.newline)) r.fail('a line break or the end of input');
    while (at(_T.newline)) {
      r.i++;
    }
  }

  (double, double) pair(double Function() read) {
    r.expect(_T.lbracket);
    final first = read();
    r.expect(_T.comma);
    final second = read();
    r.expect(_T.rbracket);
    return (first, second);
  }

  LabelAst label() {
    r.expect(_T.label);
    r.expect(_T.lbracket);
    final negX = r.accept(_T.minus);
    final offsetX = intAsDouble();
    r.expect(_T.comma);
    final negY = r.accept(_T.minus);
    final offsetY = intAsDouble();
    r.expect(_T.rbracket);
    return LabelAst(negX: negX, offsetX: offsetX, negY: negY, offsetY: offsetY);
  }

  StageAst stage() {
    final out = StageAst(name: name());
    if (r.accept(_T.at)) out.boundary = number();
    if (r.accept(_T.slash)) out.secondName = name();
    return out;
  }

  while (at(_T.newline)) {
    r.i++;
  }
  r.expect(_T.wardley);
  while (!at(-1)) {
    switch (r.kind) {
      case _T.newline:
        r.i++;
        break;
      case _T.accDescr:
        ast.accDescr = accDescrValue(r.take());
        endOfLine();
        break;
      case _T.accTitle:
        ast.accTitle = accTitleValue(r.take());
        endOfLine();
        break;
      case _T.title:
        ast.title = titleValue(r.take());
        endOfLine();
        break;
      case _T.size:
        r.i++;
        final (width, height) = pair(intAsDouble);
        endOfLine();
        ast.size = SizeAst(width: width, height: height);
        break;
      case _T.evolution:
        r.i++;
        final stages = <StageAst>[stage()];
        r.expect(_T.arrow);
        stages.add(stage());
        while (r.accept(_T.arrow)) {
          stages.add(stage());
        }
        endOfLine();
        ast.evolution = EvolutionAst(stages: stages);
        break;
      case _T.anchor:
        r.i++;
        final anchorName = name();
        final (visibility, evolution) = pair(number);
        endOfLine();
        ast.anchors.add(
          AnchorAst(
            name: anchorName,
            visibility: visibility,
            evolution: evolution,
          ),
        );
        break;
      case _T.component:
        r.i++;
        final component = ComponentAst(name: name());
        final (vis, evo) = pair(number);
        component.visibility = vis;
        component.evolution = evo;
        if (at(_T.label)) component.label = label();
        if (at(_T.lparen) && r.kinds[r.i + 1] == _T.strategy) {
          r.i++;
          component.decorator = DecoratorAst(strategy: r.take());
          r.expect(_T.rparen);
        }
        if (r.accept(_T.inertia)) {
          component.inertia = true;
        } else if (r.accept(_T.lparen)) {
          r.expect(_T.inertia);
          r.expect(_T.rparen);
          component.inertia = true;
        }
        endOfLine();
        ast.components.add(component);
        break;
      case _T.evolve:
        r.i++;
        final comp = name();
        final target = number();
        endOfLine();
        ast.evolves.add(EvolveAst(component: comp, target: target));
        break;
      case _T.pipeline:
        r.i++;
        final parent = name();
        r.expect(_T.lbrace);
        r.expect(_T.newline);
        while (at(_T.newline)) {
          r.i++;
        }
        final components = <PipelineComponentAst>[];
        do {
          r.expect(_T.component);
          final comp = PipelineComponentAst(name: name());
          r.expect(_T.lbracket);
          comp.evolution = number();
          r.expect(_T.rbracket);
          if (at(_T.label)) comp.label = label();
          endOfLine();
          components.add(comp);
        } while (at(_T.component));
        r.expect(_T.rbrace);
        endOfLine();
        ast.pipelines.add(PipelineAst(parent: parent, components: components));
        break;
      case _T.note:
        r.i++;
        final text = stringValue(r.expect(_T.string));
        final (visibility, evolution) = pair(number);
        endOfLine();
        ast.notes.add(
          NoteAst(text: text, visibility: visibility, evolution: evolution),
        );
        break;
      case _T.annotations:
        r.i++;
        final (x, y) = pair(coordinate);
        endOfLine();
        ast.annotations.add(AnnotationsBoxAst(x: x, y: y));
        break;
      case _T.annotation:
        r.i++;
        final n = intVal();
        r.expect(_T.comma);
        final (x, y) = pair(coordinate);
        final text = stringValue(r.expect(_T.string));
        endOfLine();
        ast.annotation.add(AnnotationAst(number: n, x: x, y: y, text: text));
        break;
      case _T.accelerator:
      case _T.deaccelerator:
        final slow = r.kind == _T.deaccelerator;
        r.i++;
        final force = name();
        final (x, y) = pair(number);
        endOfLine();
        if (slow) {
          ast.deaccelerators.add(
            ForceAst($type: 'Deaccelerator', name: force, x: x, y: y),
          );
        } else {
          ast.accelerators.add(
            ForceAst($type: 'Accelerator', name: force, x: x, y: y),
          );
        }
        break;
      default:
        if (!isName()) r.fail('a statement');
        final link = LinkAst(from: name());
        if (at(_T.linkPort)) link.fromPort = r.take();
        if (at(_T.linkArrow) || at(_T.arrow)) link.arrow = r.take();
        link.to = name();
        if (at(_T.linkPort)) link.toPort = r.take();
        if (at(_T.linkLabel)) link.linkLabel = r.take().substring(1).trim();
        endOfLine();
        ast.links.add(link);
    }
  }
  return ast;
}
