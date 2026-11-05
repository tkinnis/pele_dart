import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/sankey/db.dart';
import 'package:pele_dart/src/diagrams/sankey/layout.dart';
import 'package:test/test.dart';

SankeyDb _build(List<(String, String, double)> rows) {
  final db = SankeyDb();
  for (final (source, target, value) in rows) {
    db.addLink(db.findOrCreateNode(source), db.findOrCreateNode(target), value);
  }
  return db;
}

LayoutOptions _layoutOptions([
  Alignment alignment = 'justify',
  double nodePadding = 12,
  double labelHeight = 0,
]) => LayoutOptions(
  width: 600,
  height: 400,
  nodeWidth: 10,
  nodePadding: nodePadding,
  labelHeight: labelHeight,
  alignment: alignment,
);

Map<String, int> _layers(SankeyDb db, Alignment alignment) {
  final layout = layoutSankey(db, _layoutOptions(alignment));
  return <String, int>{
    for (var i = 0; i < db.nodes.length; i++)
      db.nodes[i].id: layout.nodes[i].layer,
  };
}

const List<(String, String, double)> _shape = <(String, String, double)>[
  ('a', 'b', 4),
  ('b', 'c', 3),
  ('c', 'd', 3),
  ('x', 'd', 2),
  ('a', 'y', 1),
];

const String _basic = 'sankey\na,b,5\na,c,3\nb,d,4\nc,d,1.239\n';

String _configured(String sankey, [String body = _basic]) {
  final indented = sankey.split('\n').map((l) => '    $l').join('\n');
  return '---\nconfig:\n  sankey:\n$indented\n---\n$body';
}

String _attr(String svg, String id, String name) {
  return RegExp('class="pele-sankey-node" data-id="$id"[^>]* $name="([^"]*)"')
      .firstMatch(svg)!
      .group(1)!;
}

void main() {
  const cssOptions = RenderOptions(outputMode: SvgOutputMode.cssVariables);
  const flatOptions = RenderOptions(outputMode: SvgOutputMode.flattened);

  group('sankey layout', () {
    test('honours left, justify, right, and center alignments', () {
      expect(_layers(_build(_shape), 'left'), {
        'a': 0,
        'b': 1,
        'c': 2,
        'd': 3,
        'x': 0,
        'y': 1,
      });
      expect(_layers(_build(_shape), 'justify'), {
        'a': 0,
        'b': 1,
        'c': 2,
        'd': 3,
        'x': 0,
        'y': 3,
      });
      expect(_layers(_build(_shape), 'right'), {
        'a': 0,
        'b': 1,
        'c': 2,
        'd': 3,
        'x': 2,
        'y': 3,
      });
      expect(_layers(_build(_shape), 'center'), {
        'a': 0,
        'b': 1,
        'c': 2,
        'd': 3,
        'x': 2,
        'y': 1,
      });
    });

    test('sizes nodes and bands proportionally and rejects cycles', () {
      final db = _build([('a', 'b', 30), ('a', 'c', 10), ('b', 'd', 30)]);
      final layout = layoutSankey(db, _layoutOptions());
      expect(layout.nodes[0].value, 40);
      expect(layout.nodes[0].height, closeTo(388, 1e-6));
      expect(layout.nodes[1].height / layout.nodes[2].height, closeTo(3, 1e-6));
      expect(
        layout.links[0].thickness / layout.links[1].thickness,
        closeTo(3, 1e-6),
      );

      expect(
        () => layoutSankey(_build([('a', 'a', 1)]), _layoutOptions()),
        throwsA(isA<PeleError>()),
      );
      expect(
        () => layoutSankey(
          _build([('a', 'b', 1), ('b', 'a', 1)]),
          _layoutOptions(),
        ),
        throwsA(
          isA<PeleError>()
              .having((e) => e.code, 'code', 'semantic')
              .having((e) => e.message, 'message', contains('circular links')),
        ),
      );
    });
  });

  group('sankey rendering', () {
    test('renders bars, labels, and bands in both cssVariables and flattened modes', () {
      final res = render(_basic, cssOptions);
      expect(res.type, 'sankey');
      expect(supports('sankey\na,b,1'), isTrue);
      expect(supports('sankey-beta\na,b,1'), isTrue);
      expect([res.width, res.height], [616, 416]);
      expect(RegExp('class="pele-sankey-node"').allMatches(res.svg).length, 4);
      expect(RegExp('class="pele-sankey-link"').allMatches(res.svg).length, 4);
      expect(RegExp('class="pele-label"').allMatches(res.svg).length, 4);
      expect(res.svg, contains('data-id="a-&gt;b"'));
      expect(res.svg, contains('<title>a → b: 5</title>'));
      expect(
        res.svg,
        contains(
          '>a <tspan class="pele-sankey-value" fill="var(--_m)">8</tspan><',
        ),
      );
      expect(res.svg, contains('>5.24</tspan>'));
      expect(_attr(res.svg, 'a', 'fill'), 'var(--pele-series-1,#4c78a8)');

      final flat = render(_basic, flatOptions);
      expect(flat.type, 'sankey');
      expect([flat.width, flat.height], [616, 416]);
      expect(flat.svg, isNot(contains('var(--')));
      expect(flat.svg, isNot(contains('color-mix(')));
      expect(flat.svg, contains('<title>a → b: 5</title>'));
      expect(flat.svg, contains('>5.24</tspan>'));
    });

    test('honours config options, gradients with idPrefix, prefix/suffix, and outlined labels', () {
      final sized = render(_configured('width: 300\nheight: 150'), cssOptions);
      expect([sized.width, sized.height], [316, 166]);

      final money = render(
        _configured('prefix: "\$"\nsuffix: " M"\nlabelStyle: outlined'),
        cssOptions,
      ).svg;
      expect(money, contains('>\$8 M</tspan>'));
      expect(money, contains('<title>a → b: \$5 M</title>'));
      expect(money, contains('stroke="var(--_bg)"'));

      final hidden = render(_configured('showValues: false'), cssOptions).svg;
      expect(hidden, isNot(contains('pele-sankey-value')));
      expect(hidden, contains('>a</text>'));

      final grad = render(
        _basic,
        const RenderOptions(
          outputMode: SvgOutputMode.cssVariables,
          idPrefix: 'p1',
        ),
      ).svg;
      expect(RegExp('<linearGradient ').allMatches(grad).length, 4);
      expect(grad, contains('fill="url(#p1-sankey-'));
    });

    test('parses CSV escaping, Unicode names, numeric prefixes, and rejects invalid inputs', () {
      final model = parse(
        'sankey\n"Heating, ""homes""",Agricultural \'waste\',1\n  Lighting & appliances - commercial  , Over generation / exports ,2\n',
      ) as SankeyModel;
      expect(model.nodes.map((n) => n.id).toList(), [
        'Heating, "homes"',
        "Agricultural 'waste'",
        'Lighting & appliances - commercial',
        'Over generation / exports',
      ]);

      final unicodeSvg = render(
        'sankey-beta\n"Доход, ""чистый""",☀️,50%\n☀️,🏠, 2e1 kWh\n',
        flatOptions,
      ).svg;
      expect(unicodeSvg, contains('Доход, &quot;чистый&quot;'));
      expect(unicodeSvg, contains('<title>☀️ → 🏠: 20</title>'));

      for (final bad in [
        'sankey\n',
        'sankey\na,b\n',
        'sankey\na,b,1,2\n',
        'sankey\na,,1\n',
        'sankey\na,b,abc\n',
        'sankey\na,b,Infinity\n',
        'sankey\na#65534;,b,1\n',
      ]) {
        expect(() => render(bad, cssOptions), throwsA(isA<PeleError>()));
      }
    });
  });
}
