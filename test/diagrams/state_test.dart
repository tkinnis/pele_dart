import 'package:pele_dart/src/detect.dart';
import 'package:pele_dart/src/diagrams/state/db.dart';
import 'package:pele_dart/src/diagrams/state/index.dart';
import 'package:pele_dart/src/errors.dart';
import 'package:pele_dart/src/preprocess.dart';
import 'package:pele_dart/src/svg/flattener.dart';
import 'package:pele_dart/src/svg/palette.dart';
import 'package:pele_dart/src/text/entities.dart';
import 'package:pele_dart/src/text/icons.dart';
import 'package:pele_dart/src/text/math.dart';
import 'package:pele_dart/src/types.dart';
import 'package:test/test.dart';

StateDb parseStateDiagram(
  String source, [
  RenderOptions options = const RenderOptions(),
]) {
  final pre = preprocess(source);
  final parsed = '${encodeEntities(pre.text)}\n';
  return state.parse(
    parsed,
    pre.config,
    pre.title,
    pre.lineOffset,
    ParseLimits(maxEdges: options.maxEdges ?? 5000),
  );
}

RenderResult renderMermaid(
  String source, [
  RenderOptions options = const RenderOptions(),
]) {
  final pre = preprocess(source);
  final found = detectDiagram(pre.text)!;
  final parsed = '${encodeEntities(pre.text)}\n';
  final model = state.parse(
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
      state.math ? options.math : null,
      () => withIcons<Rendered>(
        icons,
        () => state.render(
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
  group('state diagram', () {
    test('renders basic states, descriptions, start/end, choice, fork, join, notes in cssVariables and flattened modes', () {
      const src = '''
---
title: Order Lifecycle
---
stateDiagram-v2
  accTitle: Order State Machine
  accDescr: Tracks order states from creation to completion
  hide empty description
  scale 350 width

  [*] --> Pending
  Pending : Waiting for payment
  Pending : Retry allowed
  state Check <<choice>>
  state fork_state <<fork>>
  state join_state [[join]]

  Pending --> Check : submit
  Check --> fork_state : approved
  Check --> Cancelled : declined
  fork_state --> Packing
  fork_state --> Billing
  Packing --> join_state
  Billing --> join_state
  join_state --> Shipped
  Shipped --> Shipped : track
  Shipped --> [*]

  note right of Pending : Customer can cancel
  note left of Cancelled
    Refund issued
    automatically
  end note
''';

      final cssRes = renderMermaid(
        src,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssRes.type, 'state');
      expect(cssRes.mermaidType, 'stateDiagram');
      expect(cssRes.width, greaterThan(100));
      expect(cssRes.height, greaterThan(100));
      expect(cssRes.svg, contains('class="pele pele-state"'));
      expect(cssRes.svg, contains('var(--_fg)'));
      expect(cssRes.svg, contains('Order Lifecycle'));
      expect(
        cssRes.svg,
        contains('<title id="pele-title">Order State Machine</title>'),
      );
      expect(
        cssRes.svg,
        contains(
          '<desc id="pele-desc">Tracks order states from creation to completion</desc>',
        ),
      );
      expect(cssRes.svg, contains('pele-state-start'));
      expect(cssRes.svg, contains('pele-state-end'));
      expect(cssRes.svg, contains('pele-state-choice'));
      expect(cssRes.svg, contains('pele-state-fork'));
      expect(cssRes.svg, contains('pele-state-join'));
      expect(cssRes.svg, contains('pele-note'));
      expect(cssRes.svg, contains('pele-state-description'));
      expect(cssRes.svg, contains('Waiting for payment'));
      expect(cssRes.svg, contains('Customer can cancel'));
      expect(cssRes.svg, contains('Refund issued'));

      final flatRes = renderMermaid(
        src,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatRes.type, 'state');
      expect(flatRes.svg, isNot(contains('var(--')));
      expect(flatRes.svg, isNot(contains('color-mix(')));
      expect(flatRes.svg, contains('Order Lifecycle'));
      expect(flatRes.svg, contains('Waiting for payment'));
    });

    test('renders composite states, concurrent regions, and transitions across borders', () {
      const src = '''
stateDiagram
  [*] --> Active
  state "Active Session" as Active {
    direction LR
    [*] --> Running
    Running --> Paused : pause
    --
    [*] --> Monitoring
    Monitoring --> Alert : threshold
  }
  Alert --> Auditing : escalate
  Auditing --> [*]
''';

      final res = renderMermaid(
        src,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(res.mermaidType, 'stateDiagram');
      expect(res.svg, contains('pele-state-composite'));
      expect(res.svg, contains('pele-cluster-label'));
      expect(res.svg, contains('Active Session'));
      expect(res.svg, contains('pele-divider'));
      expect(res.svg, contains('data-id="Running"'));
      expect(res.svg, contains('data-id="Monitoring"'));

      final flat = renderMermaid(
        src,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flat.svg, isNot(contains('var(--')));
    });

    test('supports classDef, class, style, inline ::: styles, links, and directions', () {
      const src = '''
stateDiagram-v2
  direction LR
  accDescr {
    Multiline state
    description
  }
  classDef hot fill:#c00,stroke:#900,color:#fff,font-weight:bold
  classDef cool fill:#e0f2fe,stroke:#0284c7

  state "Landing:Welcome page" as Landing
  Landing:::cool --> Checkout:::hot : buy
  style Checkout stroke-width:2px;
  class Landing cool
  click Landing "https://example.com/landing" "Go to landing"
  click Checkout href "https://example.com/checkout"
''';

      final model = parseStateDiagram(src);
      expect(model.direction, 'LR');
      expect(model.accDescr, 'Multiline state\ndescription');
      expect(model.links.length, 2);

      final res = renderMermaid(
        src,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(res.links.length, 2);
      expect(res.links[0].id, 'Landing');
      expect(res.links[0].href, 'https://example.com/landing');
      expect(res.links[1].id, 'Checkout');
      expect(res.links[1].href, 'https://example.com/checkout');
      expect(res.svg, contains('<title>Go to landing</title>'));
      expect(res.svg, contains('Welcome page'));
      expect(res.svg, isNot(contains('var(--')));

      final turned = renderMermaid(src, const RenderOptions(maxWidth: 160));
      expect(turned.width, lessThanOrEqualTo(res.width));
    });

    test('reports syntax and semantic errors cleanly', () {
      expect(
        () => renderMermaid(
          'stateDiagram-v2\n  state Bad Name {\n    A --> B\n  }',
        ),
        throwsA(
          isA<PeleError>()
              .having((e) => e.code, 'code', 'syntax')
              .having(
                (e) => e.message,
                'message',
                contains('State name must be a single word'),
              ),
        ),
      );
      expect(
        () => renderMermaid(
          'stateDiagram-v2\n  Grp : Group Title\n  Grp : Extra description\n  state Grp {\n    A --> B\n  }',
        ),
        throwsA(
          isA<PeleError>()
              .having((e) => e.code, 'code', 'semantic')
              .having(
                (e) => e.message,
                'message',
                contains('Group nodes can only have label'),
              ),
        ),
      );
      expect(
        () => renderMermaid('stateDiagram-v2\n  state Grp {\n    A --> B'),
        throwsA(isA<PeleError>().having((e) => e.code, 'code', 'syntax')),
      );
    });
  });
}
