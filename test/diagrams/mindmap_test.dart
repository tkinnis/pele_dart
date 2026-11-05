import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/common/outline.dart';
import 'package:pele_dart/src/diagrams/mindmap/db.dart';
import 'package:pele_dart/src/diagrams/mindmap/index.dart';
import 'package:pele_dart/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('mindmap diagram', () {
    test('parses root, nested branches, node shapes, icons, and classes', () {
      const src = '''
mindmap
  root((Central Idea))
    ::icon(fa fa-star)
    :::primary
    origins[Square Node]
      longhistory(Rounded Node)
      ::icon(fa fa-book)
    research{{Hexagon Node}}
      cloudNode)Cloud Node(
      bangNode))Bang Node((
      plainNode
        :::highlight bold
''';
      final model = mindmap.parse(
        src,
        const <String, Object?>{},
        null,
        0,
        const ParseLimits(maxEdges: 500),
      );
      expect(model.type, equals('mindmap'));
      expect(model.nodes, isNotEmpty);
      final root = model.nodes.first;
      expect(root.isRoot, isTrue);
      expect(root.nodeId, equals('root'));
      expect(root.descr, equals('Central Idea'));
      expect(root.type, equals(NODE_TYPE.CIRCLE));
      expect(root.icon, equals('fa fa-star'));
      expect(root.className, equals('primary'));
      expect(root.children.length, equals(2));

      final origins = root.children[0];
      expect(origins.nodeId, equals('origins'));
      expect(origins.descr, equals('Square Node'));
      expect(origins.type, equals(NODE_TYPE.RECT));
      expect(origins.children.length, equals(1));
      expect(origins.children[0].type, equals(NODE_TYPE.ROUNDED_RECT));
      expect(origins.children[0].icon, equals('fa fa-book'));

      final research = root.children[1];
      expect(research.type, equals(NODE_TYPE.HEXAGON));
      expect(research.children.length, equals(3));
      expect(research.children[0].type, equals(NODE_TYPE.CLOUD));
      expect(research.children[1].type, equals(NODE_TYPE.BANG));
      expect(research.children[2].type, equals(NODE_TYPE.DEFAULT));
      expect(research.children[2].className, equals('highlight bold'));
    });

    test(
      'throws PeleError when multiple roots are defined or mindmap is empty',
      () {
        expect(
          () => mindmap.parse(
            'mindmap\n  RootA\n  RootB',
            const <String, Object?>{},
            null,
            0,
            const ParseLimits(maxEdges: 500),
          ),
          throwsA(
            isA<PeleError>().having(
              (e) => e.message,
              'message',
              contains('There can be only one root'),
            ),
          ),
        );
        expect(() => render('mindmap'), throwsA(isA<PeleError>()));
      },
    );

    test('renders radial layout in cssVariables and flattened modes', () {
      const src = '''
mindmap
  root((Mindmap))
    BranchA[Square]
      ::icon(fa fa-check)
      :::customClass
      LeafA1(Rounded)
      LeafA2))Bang((
    BranchB{{Hexagon}}
      LeafB1)Cloud(
      LeafB2((Circle))
    BranchC
      LeafC1["`Markdown **bold**`"]
''';
      final cssOut = render(
        src,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssOut.type, equals('mindmap'));
      expect(cssOut.width, greaterThan(0));
      expect(cssOut.height, greaterThan(0));
      expect(cssOut.svg, startsWith('<svg'));
      expect(cssOut.svg, contains('class="pele pele-mindmap"'));
      expect(cssOut.svg, contains('aria-roledescription="mindmap"'));
      expect(cssOut.svg, contains('Mindmap'));
      expect(cssOut.svg, contains('Square'));
      expect(cssOut.svg, contains('Hexagon'));
      expect(cssOut.svg, contains('customClass'));
      expect(cssOut.svg, contains('var(--_'));

      final flatOut = render(
        src,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatOut.type, equals('mindmap'));
      expect(flatOut.svg, startsWith('<svg'));
      expect(flatOut.svg, contains('Mindmap'));
      expect(flatOut.svg, isNot(contains('var(--_')));
    });

    test('renders downward outline layout when maxWidth is narrow and handles empty model', () {
      const src = '''
mindmap
  root((Main Topic))
    Topic1[First Subtopic]
      Detail1(Detailed item one)
      Detail2))Bang detail((
    Topic2{{Second Subtopic}}
      Detail3)Cloud detail(
      Detail4
        ::icon(fa fa-bolt)
''';
      final narrowOut = render(src, const RenderOptions(maxWidth: 220));
      expect(narrowOut.type, equals('mindmap'));
      expect(narrowOut.svg, contains('Main Topic'));
      expect(narrowOut.svg, contains('First Subtopic'));

      final emptyOut = mindmap.render(
        MindmapDb(),
        const <String, Object?>{},
        const RenderOptions(),
      );
      expect(emptyOut.svg, startsWith('<svg'));
    });
  });
}
