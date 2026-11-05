import 'package:pele_dart/src/detect.dart';
import 'package:pele_dart/src/diagrams/flowchart/index.dart';
import 'package:pele_dart/src/errors.dart';
import 'package:pele_dart/src/preprocess.dart';
import 'package:pele_dart/src/svg/flattener.dart';
import 'package:pele_dart/src/svg/palette.dart';
import 'package:pele_dart/src/text/entities.dart';
import 'package:pele_dart/src/text/icons.dart';
import 'package:pele_dart/src/text/math.dart';
import 'package:pele_dart/src/types.dart';
import 'package:test/test.dart';

RenderResult renderMermaid(
  String source, [
  RenderOptions options = const RenderOptions(),
]) {
  final pre = preprocess(source);
  final found = detectDiagram(pre.text)!;
  final parsed = '${encodeEntities(pre.text)}\n';
  final model = flowchart.parse(
    parsed,
    pre.config,
    pre.title,
    pre.lineOffset,
    ParseLimits(maxEdges: options.maxEdges ?? 5000),
  );
  final resolve = options.icons;
  final IconResolver? icons = resolve != null
      ? (String name) => resolve(decodeEntities(name))
      : null;
  final rendered = withPalette<Rendered>(
    palette(found.type, pre.config),
    () => withMath<Rendered>(
      options.math,
      () => withIcons<Rendered>(
        icons,
        () => flowchart.render(
          model,
          pre.config,
          options.copyWith(
            responsive: options.responsive ?? true,
            icons: icons,
          ),
        ),
      ),
    ),
  );
  for (final link in rendered.links) {
    link.id = decodeEntities(link.id);
  }
  final svg = options.outputMode == SvgOutputMode.flattened
      ? flattenPeleSvg(rendered.svg, palette: options.palette)
      : rendered.svg;
  return RenderResult(
    type: found.type,
    mermaidType: found.mermaidType,
    svg: svg,
    width: rendered.width,
    height: rendered.height,
    links: rendered.links,
  );
}

void main() {
  group('Flowchart diagram', () {
    test('renders basic flowchart in cssVariables and flattened modes', () {
      const source = '''
flowchart LR
  A[Start] --> B>Check]
  B -->|Yes| C([Great!])
  C -->|Next| D[Done]
''';
      final cssResult = renderMermaid(
        source,
        const RenderOptions(
          outputMode: SvgOutputMode.cssVariables,
          autoDirection: false,
        ),
      );
      expect(cssResult.type, 'flowchart');
      expect(cssResult.mermaidType, 'flowchart-v2');
      expect(cssResult.width, greaterThan(0));
      expect(cssResult.height, greaterThan(0));
      expect(cssResult.svg, contains('class="pele pele-flowchart"'));
      expect(cssResult.svg, contains('var(--_fg)'));
      expect(cssResult.svg, contains('data-id="A"'));
      expect(cssResult.svg, contains('data-id="B"'));
      expect(cssResult.svg, contains('data-id="C"'));
      expect(cssResult.svg, contains('data-id="D"'));
      expect(cssResult.svg, contains('Yes'));
      expect(cssResult.svg, contains('Next'));

      final flatResult = renderMermaid(
        source,
        const RenderOptions(
          outputMode: SvgOutputMode.flattened,
          palette: PelePalette.light,
          autoDirection: false,
        ),
      );
      expect(flatResult.type, 'flowchart');
      expect(flatResult.svg, isNot(contains('var(--')));
      expect(flatResult.svg, isNot(contains('color-mix(')));
      expect(flatResult.svg, contains('fill="#24292e"'));

      final darkResult = renderMermaid(
        source,
        const RenderOptions(
          outputMode: SvgOutputMode.flattened,
          palette: PelePalette.dark,
          autoDirection: false,
        ),
      );
      expect(darkResult.svg, isNot(contains('var(--')));
      expect(darkResult.svg, contains('fill="#e1e4e8"'));
    });

    test('supports directions TD, TB, BT, LR, RL and symbol directions', () {
      for (final dir in const <String>[
        'TD',
        'TB',
        'BT',
        'LR',
        'RL',
        '>',
        '<',
        '^',
        'v',
      ]) {
        final res = renderMermaid('graph $dir\n  A --> B');
        expect(res.type, 'flowchart');
        expect(res.width, greaterThan(0));
        expect(res.height, greaterThan(0));
      }

      final nodir = renderMermaid('flowchart\n  A --> B');
      expect(nodir.type, 'flowchart');

      final elk = renderMermaid('flowchart-elk LR\n  A --> B');
      expect(elk.type, 'flowchart');

      final tdRes = renderMermaid('flowchart TD\n  FirstNode --> SecondNode');
      final lrRes = renderMermaid(
        'flowchart LR\n  FirstNode --> SecondNode',
        const RenderOptions(autoDirection: false),
      );
      expect(lrRes.width, greaterThan(tdRes.width));
      expect(tdRes.height, greaterThan(lrRes.height));
    });

    test('renders all classic bracket node shapes', () {
      const source = r'''
flowchart TD
  n1[Rectangle] --> n2(Rounded)
  n2 --> n3([Stadium])
  n3 --> n4[[Subroutine]]
  n4 --> n5[(Cylinder)]
  n5 --> n6((Circle))
  n6 --> n7(((Double Circle)))
  n7 --> n8(-Ellipse-)
  n8 --> n9{Diamond}
  n9 --> n10{{Hexagon}}
  n10 --> n11>Odd Shape]
  n11 --> n12[/Trapezoid\]
  n12 --> n13[\Inv Trapezoid/]
  n13 --> n14[/Lean Right/]
  n14 --> n15[\Lean Left\]
''';
      final res = renderMermaid(
        source,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(res.svg, contains('pele-shape-rect'));
      expect(res.svg, contains('pele-shape-rounded'));
      expect(res.svg, contains('pele-shape-stadium'));
      expect(res.svg, contains('pele-shape-fr-rect'));
      expect(res.svg, contains('pele-shape-cyl'));
      expect(res.svg, contains('pele-shape-circle'));
      expect(res.svg, contains('pele-shape-dbl-circ'));
      expect(res.svg, contains('pele-shape-ellipse'));
      expect(res.svg, contains('pele-shape-diam'));
      expect(res.svg, contains('pele-shape-hex'));
      expect(res.svg, contains('pele-shape-odd'));
      expect(res.svg, contains('pele-shape-trap-b'));
      expect(res.svg, contains('pele-shape-trap-t'));
      expect(res.svg, contains('pele-shape-lean-r'));
      expect(res.svg, contains('pele-shape-lean-l'));
    });

    test('renders @{ shape: ... } metadata shapes, icons, and images', () {
      const source = '''
flowchart LR
  A@{ shape: doc, label: "Document" } --> B@{ shape: cloud, label: "Cloud" }
  B --> C@{ shape: person, label: "User" }
  C --> D@{ shape: folder, label: "Files" }
  D --> E@{ shape: bang, label: "Boom" }
  E --> F@{ shape: sm-circ }
  F --> G@{ icon: "fa:fa-database", form: "circle", label: "DB", pos: "t" }
  G --> H@{ img: "https://example.com/icon.png", w: 60, h: 60, constraint: "on", label: "Logo" }
''';
      final res = renderMermaid(
        source,
        RenderOptions(
          outputMode: SvgOutputMode.flattened,
          icons: (name) => '<path d="M0,0L10,10"/>',
        ),
      );
      expect(res.svg, contains('pele-shape-doc'));
      expect(res.svg, contains('pele-shape-cloud'));
      expect(res.svg, contains('pele-shape-person'));
      expect(res.svg, contains('pele-shape-folder'));
      expect(res.svg, contains('pele-shape-bang'));
      expect(res.svg, contains('pele-shape-sm-circ'));
      expect(res.svg, contains('class="pele-icon"'));
      expect(res.svg, contains('<image href="https://example.com/icon.png"'));
      expect(res.svg, contains('preserveAspectRatio="xMidYMid meet"'));
    });

    test(
      'renders edge styles, arrows, labels, multi-links, and self-loops',
      () {
        const source = '''
flowchart TD
  A -->|normal| B
  B == thick ==> C
  C -. dotted .-> D
  D ~~~ E
  E <--> F
  F o--o G
  G x--x H
  H ---|open| I@{ shape: doc }
  I & I2@{ shape: doc } --> J@{ shape: doc } & J2@{ shape: doc }
  J -->|loopback| J
  J e1@== labeled ==> K@{ shape: doc }
  e1@{ animate: true, curve: stepBefore }
''';
        final res = renderMermaid(
          source,
          const RenderOptions(outputMode: SvgOutputMode.flattened),
        );
        expect(res.svg, contains('stroke-width="2.5"'));
        expect(res.svg, contains('stroke-dasharray="3 4"'));
        expect(res.svg, contains('data-id="e1"'));
        expect(res.svg, contains('loopback'));
        expect(res.svg, contains('labeled'));
        expect(res.svg, isNot(contains('var(--')));
      },
    );

    test(
      'renders nested subgraphs, direction statements, and collapsed subgraphs',
      () {
        const source = '''
flowchart TB
  subgraph Outer [Outer Group]
    direction LR
    A[One] --> B[Two]
    subgraph Inner [Inner Group]
      direction TB
      C[Three] --> D[Four]
    end
    B --> C
  end
  subgraph CollapsedGroup [Collapsed Module]
    E[Hidden 1] --> F[Hidden 2]
  end
  CollapsedGroup@{ view: collapsed }
  D --> E
''';
        final res = renderMermaid(
          source,
          const RenderOptions(outputMode: SvgOutputMode.flattened),
        );
        expect(res.svg, contains('class="pele-clusters"'));
        expect(res.svg, contains('Outer Group'));
        expect(res.svg, contains('Inner Group'));
        expect(res.svg, contains('Collapsed Module'));
        expect(res.svg, contains('pele-shape-collapsedGroup'));
        expect(res.svg, isNot(contains('Hidden 1')));
        expect(res.svg, isNot(contains('Hidden 2')));
      },
    );

    test('applies classDef, class, style, linkStyle, click, and accessibility metadata', () {
      const source = '''
---
title: Styled Flowchart
---
flowchart TD
  accTitle: My Accessible Flowchart
  accDescr {
    A multi-line accessible description.
  }
  classDef highlight fill:#2563eb,stroke:#1d4ed8,color:#ffffff,font-weight:bold
  classDef noteClass fill:#fef3c7,stroke:#d97706
  A[Primary]:::highlight --> B[Secondary]
  B --> C[NoteName]
  class B noteClass
  class C internal-link
  style B stroke-width:2px,stroke-dasharray:5 5
  linkStyle 0 stroke:#dc2626,stroke-width:3px
  linkStyle default interpolate linear
  click A "https://example.com/docs" "Read docs" _blank
  click B call myCallback("arg1") "Callback tip"
''';
      final res = renderMermaid(
        source,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(res.svg, contains('Styled Flowchart'));
      expect(
        res.svg,
        contains('<title id="pele-title">My Accessible Flowchart</title>'),
      );
      expect(
        res.svg,
        contains(
          '<desc id="pele-desc">A multi-line accessible description.</desc>',
        ),
      );
      expect(res.svg, contains('fill="#2563eb"'));
      expect(res.svg, contains('stroke="#dc2626"'));
      expect(res.svg, contains('<title>Read docs</title>'));
      expect(res.svg, contains('href="https://example.com/docs"'));
      expect(res.svg, contains('target="_blank"'));
      expect(res.svg, contains('class="internal-link"'));
      expect(
        res.links,
        containsAll(<LinkInfo>[
          LinkInfo(id: 'A', href: 'https://example.com/docs', internal: false),
          LinkInfo(id: 'C', href: 'NoteName', internal: true),
        ]),
      );
    });

    test('reports semantic and syntax errors accurately', () {
      expect(
        () => renderMermaid('flowchart TD\n  A@{ shape: UnknownShape }'),
        throwsA(isA<PeleError>().having((e) => e.code, 'code', 'semantic')),
      );
      expect(
        () =>
            renderMermaid('flowchart TD\n  A --> B\n  linkStyle 5 stroke:#f00'),
        throwsA(isA<PeleError>().having((e) => e.code, 'code', 'semantic')),
      );
      expect(
        () => renderMermaid(
          'flowchart TD\n  A --> B\n  B --> C',
          const RenderOptions(maxEdges: 1),
        ),
        throwsA(isA<PeleError>().having((e) => e.code, 'code', 'limit')),
      );
    });
  });
}
