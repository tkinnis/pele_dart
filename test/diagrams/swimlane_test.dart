import 'package:pele_dart/src/detect.dart';
import 'package:pele_dart/src/diagrams/swimlane/index.dart';
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
  final model = swimlane.parse(
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
        () => swimlane.render(
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
  group('Swimlane diagram', () {
    test(
      'renders swimlane-beta with lanes in cssVariables and flattened modes',
      () {
        const source = '''
---
title: Order Fulfillment Swimlanes
---
swimlane-beta TD
  subgraph Customer
    A[Place Order] --> B[Receive Parcel]
  end
  subgraph Warehouse
    C[Pick Items] --> D[Pack Box]
  end
  subgraph Courier
    E[Deliver Parcel]
  end
  A -->|Order Created| C
  D -->|Ready| E
  E --> B
''';
        final cssRes = renderMermaid(
          source,
          const RenderOptions(outputMode: SvgOutputMode.cssVariables),
        );
        expect(cssRes.type, 'swimlane');
        expect(cssRes.mermaidType, 'swimlane');
        expect(cssRes.width, greaterThan(0));
        expect(cssRes.height, greaterThan(0));
        expect(cssRes.svg, contains('class="pele pele-swimlane"'));
        expect(cssRes.svg, contains('pele-lane'));
        expect(cssRes.svg, contains('Customer'));
        expect(cssRes.svg, contains('Warehouse'));
        expect(cssRes.svg, contains('Courier'));
        expect(cssRes.svg, contains('Order Created'));
        expect(cssRes.svg, contains('var(--_fg)'));

        final flatRes = renderMermaid(
          source,
          const RenderOptions(
            outputMode: SvgOutputMode.flattened,
            palette: PelePalette.light,
          ),
        );
        expect(flatRes.type, 'swimlane');
        expect(flatRes.svg, isNot(contains('var(--')));
        expect(flatRes.svg, isNot(contains('color-mix(')));
        expect(flatRes.svg, contains('Order Fulfillment Swimlanes'));
        expect(flatRes.svg, contains('pele-lane'));

        final darkRes = renderMermaid(
          source,
          const RenderOptions(
            outputMode: SvgOutputMode.flattened,
            palette: PelePalette.dark,
          ),
        );
        expect(darkRes.svg, isNot(contains('var(--')));
        expect(darkRes.svg, contains('fill="#e1e4e8"'));
      },
    );

    test('supports LR, RL, BT, and TD directions with rotated headers for sideways lanes', () {
      const lrSource = '''
swimlane-beta LR
  subgraph Frontend
    A[Login Form] --> B[Dashboard]
  end
  subgraph Backend
    C[Verify Token]
  end
  A --> C
  C --> B
''';
      final lrRes = renderMermaid(
        lrSource,
        const RenderOptions(
          outputMode: SvgOutputMode.flattened,
          autoDirection: false,
        ),
      );
      expect(lrRes.svg, contains('rotate(-90 '));
      expect(lrRes.svg, contains('Frontend'));
      expect(lrRes.svg, contains('Backend'));

      const rlSource = '''
swimlane-beta RL
  subgraph LaneA
    A --> B
  end
  subgraph LaneB
    C
  end
  B --> C
''';
      final rlRes = renderMermaid(
        rlSource,
        const RenderOptions(autoDirection: false),
      );
      expect(rlRes.svg, contains('rotate(-90 '));

      const btSource = '''
swimlane-beta BT
  subgraph LaneA
    A --> B
  end
  subgraph LaneB
    C
  end
  B --> C
''';
      final btRes = renderMermaid(btSource);
      expect(btRes.svg, isNot(contains('rotate(-90 ')));
    });

    test('places loose nodes outside subgraphs into default unnamed lane', () {
      const source = '''
swimlane-beta TD
  Start([Start]) --> A[Task in Lane]
  subgraph Ops [Operations]
    A --> B{Approved?}
  end
  B -->|No| End([Abort])
''';
      final res = renderMermaid(
        source,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(res.svg, contains('data-id="__swimlane_default__"'));
      expect(res.svg, contains('data-id="Ops"'));
      expect(res.svg, contains('Start'));
      expect(res.svg, contains('Abort'));
    });

    test('supports lane styling, node shapes, edge styles, and tight maxWidth layout', () {
      const source = '''
swimlane-beta TD
  classDef urgent fill:#fee2e2,stroke:#dc2626,color:#991b1b
  subgraph Alpha [Alpha Team]
    A([Kickoff]) --> B{{Review}}
  end
  subgraph Beta [Beta Team]
    C[(Store)]:::urgent --> D[Complete]
  end
  style Alpha fill:#dbeafe,stroke:#2563eb
  B == Approved ==> C
  linkStyle 1 stroke:#16a34a,stroke-width:2px
''';
      final res = renderMermaid(
        source,
        const RenderOptions(outputMode: SvgOutputMode.flattened, maxWidth: 320),
      );
      expect(res.svg, contains('fill="#dbeafe"'));
      expect(res.svg, contains('fill="#fee2e2"'));
      expect(res.svg, contains('stroke="#16a34a"'));
      expect(res.svg, contains('Approved'));
      expect(res.svg, isNot(contains('var(--')));
    });
  });
}
