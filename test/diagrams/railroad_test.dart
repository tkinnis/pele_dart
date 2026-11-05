import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/railroad/types.dart';
import 'package:test/test.dart';

RailroadModel _model(String src) => parse(src) as RailroadModel;

RailroadNode _def(String keyword, String body) =>
    _model('$keyword\n$body').rules[0].definition;
RailroadNode _ir(String expr) => _def('railroad-beta', 'r = $expr ;');
RailroadNode _ebnf(String expr) => _def('railroad-ebnf-beta', 'r = $expr ;');
RailroadNode _abnf(String expr) => _def('railroad-abnf-beta', 'r = $expr ;');
RailroadNode _peg(String expr) => _def('railroad-peg-beta', 'R <- $expr ;');

RailroadNode _t(String v) => RailroadNode.terminal(v);
RailroadNode _n(String name) => RailroadNode.nonterminal(name);
RailroadNode _s(String text) => RailroadNode.special(text);
RailroadNode _seq(List<RailroadNode> els) => RailroadNode.sequence(els);
RailroadNode _alt(List<RailroadNode> alts) => RailroadNode.choice(alts);
RailroadNode _opt(RailroadNode el) => RailroadNode.optional(el);
RailroadNode _rep(
  RailroadNode el,
  double min, [
  double max = double.infinity,
]) => RailroadNode.repetition(el, min, max);

void main() {
  const cssOptions = RenderOptions(outputMode: SvgOutputMode.cssVariables);
  const flatOptions = RenderOptions(outputMode: SvgOutputMode.flattened);

  group('railroad model across all four notations', () {
    test('builds constructor notation (railroad-beta) node for node', () {
      expect(_ir('terminal("a")'), _t('a'));
      expect(_ir("nonterminal('b')"), _n('b'));
      expect(_ir('special("any character")'), _s('any character'));
      expect(
        _ir('sequence(terminal("a"), nonterminal("b"))'),
        _seq([_t('a'), _n('b')]),
      );
      expect(
        _ir('choice(terminal("a"), nonterminal("b"), special("c"))'),
        _alt([_t('a'), _n('b'), _s('c')]),
      );
      expect(_ir('optional(terminal("a"))'), _opt(_t('a')));
      expect(_ir('oneOrMore(terminal("a"))'), _rep(_t('a'), 1));
      expect(_ir('zeroOrMore(terminal("a"))'), _rep(_t('a'), 0));
      expect(_ir('sequence(choice(sequence(terminal("a"))))'), _t('a'));
    });

    test('parses EBNF, ABNF, and PEG notations accurately', () {
      expect(_ebnf('a b , c'), _seq([_n('a'), _n('b'), _n('c')]));
      expect(
        _ebnf('a | "b" c'),
        _alt([
          _n('a'),
          _seq([_t('b'), _n('c')]),
        ]),
      );
      expect(_ebnf('[ a ]'), _opt(_n('a')));
      expect(_ebnf('{ a | b }'), _rep(_alt([_n('a'), _n('b')]), 0));
      expect(_ebnf('?  any character  ?'), _s('any character'));
      expect(_ebnf('a - b'), _seq([_n('a'), _t('-'), _n('b')]));
      expect(_ebnf('a? b?'), _seq([_n('a'), _s('b')]));

      expect(_abnf('*a'), _rep(_n('a'), 0));
      expect(_abnf('1*a'), _rep(_n('a'), 1));
      expect(_abnf('2*4a'), _rep(_n('a'), 2, 4));
      expect(_abnf('*4a'), _rep(_n('a'), 0, 4));
      expect(_abnf('3a'), _rep(_n('a'), 3, 3));
      expect(_abnf('0*1a'), _opt(_n('a')));
      expect(
        _abnf('${'9' * 400}a'),
        _rep(_n('a'), double.infinity, double.infinity),
      );
      expect(
        _abnf('%x41 %d65.66 %b1000001 %x30-39'),
        _seq([_t('%x41'), _t('%d65.66'), _t('%b1000001'), _t('%x30-39')]),
      );

      expect(
        _peg('a? b* c+'),
        _seq([_opt(_n('a')), _rep(_n('b'), 0), _rep(_n('c'), 1)]),
      );
      expect(_peg('.'), _s('.'));
      expect(_peg('&a'), _s('&a'));
      expect(_peg('!"x"'), _s('!"x"'));
      expect(_peg('!( a b )'), _s('!(...)'));
    });

    test('reads titles, frontmatter fallback, accessibility, and rejects invalid syntax', () {
      final quoted = _model(
        'railroad-ebnf-beta\ntitle   "A \\"quoted\\"\\ttitle"   \naccTitle:   Acc   title\naccDescr: One   line\nr = a ;',
      );
      expect(quoted.title, 'A "quoted"\ttitle');
      expect(quoted.accTitle, 'Acc title');
      expect(quoted.accDescr, 'One line');

      expect(
        _model('---\ntitle: Front\n---\nrailroad-ebnf-beta\ntitle\nr = a ;')
            .title,
        'Front',
      );
      expect(
        _model('---\ntitle: Front\n---\nrailroad-ebnf-beta\ntitle Own\nr = a ;')
            .title,
        'Own',
      );

      for (final bad in [
        'railroad-ebnf-beta\nr = ;',
        'railroad-ebnf-beta\nr = a',
        'railroad-ebnf-beta\nr = [ a ) ;',
        'railroad-beta\nr = sequence() ;',
        'railroad-abnf-beta\nr = 2* ;',
        'railroad-peg-beta\nR <- ;',
        'railroad-peg-beta\nR <- !&a ;',
      ]) {
        expect(() => parse(bad), throwsA(isA<PeleError>()));
      }
    });
  });

  group('railroad rendering', () {
    test('renders all four notations identically and supports cssVariables and flattened modes', () {
      const sources = [
        'railroad-beta\nr = terminal("a") ;',
        'railroad-ebnf-beta\nr = "a" ;',
        'railroad-abnf-beta\nr = "a" ;',
        'railroad-peg-beta\nr <- "a" ;',
      ];
      final svgs = <String>{};
      for (final src in sources) {
        expect(detectType(src), 'railroad');
        expect(supports(src), isTrue);
        final res = render(src, cssOptions);
        expect(res.type, 'railroad');
        expect(res.svg, contains('class="pele pele-railroad"'));
        expect(res.svg, contains('class="pele-node pele-terminal"'));
        svgs.add(res.svg);
      }
      expect(svgs.length, 1);

      const complex = '''railroad-ebnf-beta
title JSON Value Grammar
accTitle: JSON Value
accDescr: Syntax diagram for JSON values
value = "null" | "true" | "false" | number | string | array | object ;
array = "[" [ value ( "," value )* ] "]" ;
specialRule = ? any unicode char ? - "x" ;''';

      final cssRes = render(complex, cssOptions);
      expect(cssRes.type, 'railroad');
      expect(cssRes.svg, contains('var(--_fg)'));
      expect(cssRes.svg, contains('<title id="pele-title">JSON Value</title>'));
      expect(cssRes.svg, contains('>JSON Value Grammar<'));
      expect(cssRes.svg, contains('class="pele-node pele-special"'));
      expect(cssRes.svg, contains('class="pele-node pele-nonterminal"'));

      final flatRes = render(complex, flatOptions);
      expect(flatRes.type, 'railroad');
      expect(flatRes.svg, isNot(contains('var(--')));
      expect(flatRes.svg, isNot(contains('color-mix(')));
      expect(flatRes.svg, contains('>JSON Value Grammar<'));
      expect(flatRes.svg, contains('>array<'));
    });

    test('renders ABNF repeat counts, literal text escaping, and railroad config options', () {
      String abnfSvg(String rule) =>
          render('railroad-abnf-beta\n$rule', cssOptions).svg;
      expect(abnfSvg('r = 3a ;'), contains('>3×</text>'));
      expect(abnfSvg('r = 2*4a ;'), contains('>2–4×</text>'));
      expect(abnfSvg('r = 2*a ;'), contains('>≥2×</text>'));
      expect(abnfSvg('r = *5a ;'), contains('>≤5×</text>'));
      expect(abnfSvg('r = ${'9' * 400}a ;'), contains('>∞×</text>'));

      final literalSvg = render(
        'railroad-beta\nr = sequence(terminal("<br>"), terminal("*a*"), terminal("#35;"), terminal("&lt;"), terminal(" "), terminal("a  b"), terminal("\\n\\t"), nonterminal("fa:fa-user")) ;',
        cssOptions,
      ).svg;
      expect(literalSvg, contains('>&lt;br&gt;</text>'));
      expect(literalSvg, contains('>*a*</text>'));
      expect(literalSvg, contains('>#</text>'));
      expect(literalSvg, contains('>&amp;lt;</text>'));
      expect(literalSvg, contains('>␣</text>'));
      expect(
        literalSvg,
        contains(' xml:space="preserve" font-family="var(--_fm)">a  b</text>'),
      );
      expect(literalSvg, contains(r'>\n\t</text>'));
      expect(literalSvg, contains('>fa:fa-user</text>'));

      final noMarkers = render(
        '---\nconfig:\n  railroad:\n    showMarkers: false\n    arcRadius: 20\n    strokeWidth: 2\n---\nrailroad-ebnf-beta\nr = a ( b | c )* [ d ] ;',
        flatOptions,
      );
      expect(noMarkers.svg, isNot(contains('<circle')));
      expect(noMarkers.svg, contains('a20,20 0 0 1 20,20'));
      expect(noMarkers.svg, contains('stroke-width="2"'));
      expect(noMarkers.svg, isNot(contains('var(--')));
    });
  });
}
