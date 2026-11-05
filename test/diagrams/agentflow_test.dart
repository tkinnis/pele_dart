import 'dart:convert';
import 'dart:math' as math;

import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/agentflow/index.dart';
import 'package:pele_dart/src/text/measurer.dart';
import 'package:test/test.dart';

const RenderOptions _cssOptions = RenderOptions(
  measurer: metricsMeasurer,
  outputMode: SvgOutputMode.cssVariables,
);

const RenderOptions _flatOptions = RenderOptions(
  measurer: metricsMeasurer,
  outputMode: SvgOutputMode.flattened,
);

String _svgOf(String src) => renderMermaid(src, options: _cssOptions);

int _count(String svg, String needle) => svg.split(needle).length - 1;

AgentflowModel _modelOf(String src) => parse(src) as AgentflowModel;

String _series(int n) => 'var(--pele-series-$n,';

({String classes, double x, double y, String body}) _node(
  String svg,
  String id,
) {
  final m = RegExp(
    '<g class="(pele-node[^"]*)" data-id="${RegExp.escape(id)}" transform="translate\\(([-\\d.]+),([-\\d.]+)\\)">(.*?)</g>',
  ).firstMatch(svg);
  if (m == null) throw StateError('no node $id in $svg');
  return (
    classes: m.group(1)!,
    x: double.parse(m.group(2)!),
    y: double.parse(m.group(3)!),
    body: m.group(4)!,
  );
}

({double x, double y, double w, double h, String rect}) _frame(
  String svg,
  String id,
) {
  final m = RegExp(
    '<g class="pele-cluster pele-flow[^"]*" data-id="${RegExp.escape(id)}">(<rect x="([-\\d.]+)" y="([-\\d.]+)" width="([\\d.]+)" height="([\\d.]+)"[^>]*/>)',
  ).firstMatch(svg);
  if (m == null) throw StateError('no flow $id in $svg');
  return (
    x: double.parse(m.group(2)!),
    y: double.parse(m.group(3)!),
    w: double.parse(m.group(4)!),
    h: double.parse(m.group(5)!),
    rect: m.group(1)!,
  );
}

List<({String classes, String id, String body})> _edges(String svg) {
  return RegExp(
        r'<g class="(pele-edge [^"]*)" data-id="([^"]*)"[^>]*>(.*?)</g>',
      )
      .allMatches(svg)
      .map((m) => (classes: m.group(1)!, id: m.group(2)!, body: m.group(3)!))
      .toList();
}

bool _inside(
  ({String classes, double x, double y, String body}) n,
  ({double x, double y, double w, double h, String rect}) f,
) => n.x > f.x && n.x < f.x + f.w && n.y > f.y && n.y < f.y + f.h;

void main() {
  group('agentflow rendering', () {
    test('is detected, supported and typed in cssVariables and flattened modes', () {
      const src = 'agentflow-beta TB\n  a["A"] --> b["B"]';
      expect(detectType(src), 'agentflow');
      expect(supports(src), isTrue);

      final cssSvg = renderMermaid(src, options: _cssOptions);
      expect(
        cssSvg,
        startsWith(
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele pele-agentflow"',
        ),
      );
      expect(cssSvg, contains('var(--pele-series-'));

      final flatSvg = renderMermaid(src, options: _flatOptions);
      expect(
        flatSvg,
        startsWith(
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele pele-agentflow"',
        ),
      );
      expect(flatSvg, isNot(contains('var(--')));
      expect(flatSvg, isNot(contains('color-mix(')));
      expect(flatSvg, contains('data-id="a"'));
      expect(flatSvg, contains('data-id="b"'));

      final result = render(src, _cssOptions);
      expect(result.type, 'agentflow');
      expect(
        result.svg,
        contains(
          'viewBox="0 0 ${result.width.toInt()} ${result.height.toInt()}"',
        ),
      );
      final model = _modelOf(src);
      expect(model.type, 'agentflow');
      expect(model.nodes.keys.toList(), <String>['a', 'b']);
    });

    test('lays out along the declared direction', () {
      final tall = render('agentflow-beta TB\n  a --> b --> c', _cssOptions);
      final wide = render('agentflow-beta LR\n  a --> b --> c', _cssOptions);
      expect(tall.height, greaterThan(tall.width));
      expect(wide.width, greaterThan(wide.height));
      final up = _svgOf('agentflow-beta BT\n  a --> b');
      expect(_node(up, 'a').y, greaterThan(_node(up, 'b').y));
      final back = _svgOf('agentflow-beta RL\n  a --> b');
      expect(_node(back, 'a').x, greaterThan(_node(back, 'b').x));
      final none = _svgOf('agentflow-beta\n  a --> b');
      expect(_node(none, 'b').y, greaterThan(_node(none, 'a').y));
    });

    test('draws each of the six shapes, and a connector, in the color of its kind', () {
      const src =
          'agentflow-beta LR\n  t["T"]@{ shape: task }\n  o["O"]@{ shape: tool }\n  i["I"]@{ shape: input }\n  d["D"]@{ shape: decision }\n  r["R"]@{ shape: refdoc }\n  c["C"]@{ shape: action }\n  connector k["K"]\n  plain';
      final svg = _svgOf(src);
      final expected = <(String, String, String, int)>[
        ('o', 'fr-rect', 'tool', 1),
        ('t', 'rounded', 'task', 2),
        ('plain', 'rounded', 'task', 2),
        ('d', 'diam', 'decision', 3),
        ('i', 'lean-r', 'input', 4),
        ('r', 'lin-doc', 'refdoc', 5),
        ('k', 'rounded', 'connector', 6),
        ('c', 'hex', 'action', 7),
      ];
      for (final (id, shape, kind, slot) in expected) {
        final n = _node(svg, id);
        expect(n.classes, 'pele-node pele-shape-$shape pele-kind-$kind');
        expect(n.body, contains('fill="${_series(slot)}'));
        expect(n.body, contains('stroke="${_series(slot)}'));
        expect(n.body, contains('fill-opacity="0.14"'));
      }
      expect(_node(svg, 'd').body, contains('<polygon'));
      expect(_node(svg, 'o').body, matches(RegExp(r'<rect[^>]*\/><path')));

      final flatSvg = renderMermaid(src, options: _flatOptions);
      expect(flatSvg, isNot(contains('var(--')));
      for (final (id, shape, kind, _) in expected) {
        expect(
          _node(flatSvg, id).classes,
          'pele-node pele-shape-$shape pele-kind-$kind',
        );
      }
    });

    test('writes the bracket shapes agentflow removed as plain tasks and reports them', () {
      const src =
          'agentflow-beta TB\n  a((circle)) --> b([stadium]) --> c[(db)] --> d>odd] --> e(round)';
      final svg = _svgOf(src);
      for (final id in <String>['a', 'b', 'c', 'd', 'e']) {
        expect(
          _node(svg, id).classes,
          'pele-node pele-shape-rounded pele-kind-task',
        );
      }
      final model = _modelOf(src);
      expect(
        model.diagnostics
            .map((d) => <String?>[d.id, d.severity, d.nodeId])
            .toList(),
        <List<String?>>[
          <String?>['SHAPE_REMOVED', 'error', 'a'],
          <String?>['SHAPE_REMOVED', 'error', 'b'],
          <String?>['SHAPE_REMOVED', 'error', 'c'],
          <String?>['SHAPE_REMOVED', 'error', 'd'],
        ],
      );
      expect(
        model.diagnostics[0].message,
        'shape "circle" was removed in v0.8.1, using "roundedRect"',
      );
      expect(model.diagnostics[0].position?.startLine, 2);
      expect(model.diagnostics[0].position?.startColumn, 2);
      expect(model.diagnostics[0].position?.endLine, 2);
    });

    test(
      'warns about a shape outside the catalogue and still draws the node',
      () {
        const src =
            'agentflow-beta TB\n  a["A"]\n  a@{ shape: "triangle" }\n  a --> b';
        final model = _modelOf(src);
        expect(model.diagnostics.length, 1);
        final d = model.diagnostics[0];
        expect(d.id, 'SHAPE_UNSUPPORTED');
        expect(d.severity, 'warning');
        expect(
          d.message,
          'shape "triangle" is not supported, using "roundedRect"',
        );
        expect(d.nodeId, 'a');
        expect(
          d.position,
          ElementPosition(
            startLine: 2,
            startColumn: 2,
            endLine: 2,
            endColumn: 8,
            startIndex: 0,
            endIndex: 0,
          ),
        );
        expect(_node(_svgOf(src), 'a').classes, contains('pele-shape-rounded'));
        // Rendering the same model again does not report it twice.
        render(model, _cssOptions);
        expect(model.diagnostics.length, 1);
      },
    );

    test('draws the three edge kinds differently', () {
      const src =
          'agentflow-beta TB\n  a --> b\n  a --x c\n  a -.- d\n  a -- "why" --> e';
      final svg = _svgOf(src);
      final all = _edges(svg);
      expect(all.map((e) => e.classes).toList(), <String>[
        'pele-edge pele-edge-sequence',
        'pele-edge pele-edge-failure',
        'pele-edge pele-edge-reference',
        'pele-edge pele-edge-sequence',
      ]);
      expect(
        all[0].body,
        matches(
          RegExp(
            r'<path d="[^"]+"\/><path class="pele-marker" d="[^"]+Z" fill=',
          ),
        ),
      );
      expect(
        all[1].body,
        matches(
          RegExp(
            r'<path d="[^"]+"\/><path class="pele-marker" d="M[^Z"]+"\/>$',
          ),
        ),
      );
      expect(
        all[2].body,
        matches(RegExp(r'^<path d="[^"]+" stroke-dasharray="3 4"\/>$')),
      );
      expect(svg, contains('<g class="pele-edge-label" data-id="L_a_e_0">'));
      expect(svg, contains('>why</text>'));

      final flatSvg = renderMermaid(src, options: _flatOptions);
      expect(flatSvg, isNot(contains('var(--')));
      expect(flatSvg, contains('>why</text>'));
    });

    test('fans an edge out over every pair that an ampersand names', () {
      final svg = _svgOf('agentflow-beta TB\n  a & b --> c & d');
      expect(_edges(svg).map((e) => e.id).toList(), <String>[
        'L_a_c_0',
        'L_a_d_0',
        'L_b_c_0',
        'L_b_d_0',
      ]);
    });

    test('draws a self-loop beside its node', () {
      final svg = _svgOf('agentflow-beta TB\n  a["Alpha"]\n  a --> a');
      final all = _edges(svg);
      expect(all.length, 1);
      expect(all[0].body, matches(RegExp(r'<path d="M[-\d.]+,[-\d.]+C')));
    });

    test('frames a flow around its members, with its title', () {
      const src =
          'agentflow-beta TB\n  flow team["Content Team"]\n    a["A"] --> b["B"]\n  end\n  c["C"]\n  b --> c';
      final svg = _svgOf(src);
      final team = _frame(svg, 'team');
      expect(_inside(_node(svg, 'a'), team), isTrue);
      expect(_inside(_node(svg, 'b'), team), isTrue);
      expect(_inside(_node(svg, 'c'), team), isFalse);
      expect(
        svg,
        matches(
          RegExp(r'<text class="pele-cluster-label"[^>]*>Content Team<\/text>'),
        ),
      );
      expect(team.rect, contains('stroke="${_series(8)}'));
      expect(team.rect, contains('fill-opacity="0.06"'));

      final flatSvg = renderMermaid(src, options: _flatOptions);
      expect(flatSvg, isNot(contains('var(--')));
      expect(flatSvg, contains('Content Team'));
      expect(flatSvg, contains('rx="6"'));
    });

    test(
      'nests flows, and gives a flow without a bracketed title no title',
      () {
        final svg = _svgOf(
          'agentflow-beta TB\n  flow outer["Outer"]\n    flow inner\n      a --> b\n    end\n    c\n  end',
        );
        final outer = _frame(svg, 'outer');
        final inner = _frame(svg, 'inner');
        expect(inner.x, greaterThan(outer.x));
        expect(inner.y, greaterThan(outer.y));
        expect(inner.x + inner.w, lessThan(outer.x + outer.w));
        expect(inner.y + inner.h, lessThan(outer.y + outer.h));
        expect(_inside(_node(svg, 'a'), inner), isTrue);
        expect(_inside(_node(svg, 'c'), inner), isFalse);
        expect(_inside(_node(svg, 'c'), outer), isTrue);
        expect(_count(svg, 'class="pele-cluster-label"'), 1);
      },
    );

    test('lays a flow out in its own direction', () {
      final svg = _svgOf(
        'agentflow-beta TB\n  flow f["F"]\n    direction LR\n    a --> b\n  end\n  f --> c',
      );
      expect(_node(svg, 'b').x, greaterThan(_node(svg, 'a').x));
      expect((_node(svg, 'a').y - _node(svg, 'b').y).abs(), lessThan(1));
      expect(_node(svg, 'c').y, greaterThan(_node(svg, 'b').y));
    });

    test("ignores a flow's direction when its nodes link outside it", () {
      const flows =
          'agentflow-beta LR\nflow S\n direction TB\n s1\n s2\nend\nflow P\n direction TB\n p1\n p2\nend\n';
      const links = 's1 --> p2\ns2 --> p1\n';
      expect(
        _svgOf(flows + links),
        _svgOf(flows.replaceAll(' direction TB\n', '') + links),
      );
    });

    test('keeps a global node out of the flows that mention it', () {
      const src =
          'agentflow-beta TB\n  global\n    corpus["Shared"]@{ shape: refdoc }\n  end\n  flow one["One"]\n    a -.- corpus\n  end\n  flow two["Two"]\n    b -.- corpus\n  end';
      final svg = _svgOf(src);
      final corpusNode = _node(svg, 'corpus');
      expect(_inside(corpusNode, _frame(svg, 'one')), isFalse);
      expect(_inside(corpusNode, _frame(svg, 'two')), isFalse);
      expect(_count(svg, 'pele-cluster pele-flow'), 2);
      expect(
        _modelOf(src).subgraphs.map((s) => s.nodes).toList(),
        <List<String>>[
          <String>['a'],
          <String>['b'],
        ],
      );
    });

    test('folds a collapsed flow into one node and reconnects its edges', () {
      const src =
          'agentflow-beta TB\n  in["In"] --> v\n  flow p["Processing"]\n    v["Validate"] --> e["Enrich"]\n  end\n  p@{ view: "collapsed" }\n  e --> out["Out"]';
      final svg = _svgOf(src);
      final p = _node(svg, 'p');
      expect(p.classes, 'pele-node pele-shape-collapsed');
      expect(p.body, contains('>Processing</text>'));
      expect(p.body, contains('class="pele-collapsed-mark"'));
      expect(p.body, contains('stroke="${_series(8)}'));
      expect(svg, isNot(contains('data-id="v"')));
      expect(svg, isNot(contains('pele-cluster')));
      expect(_edges(svg).map((e) => e.id).toList(), <String>[
        'L_in_v_0',
        'L_e_out_0',
      ]);
      expect(_node(svg, 'p').y, greaterThan(_node(svg, 'in').y));
      expect(_node(svg, 'out').y, greaterThan(_node(svg, 'p').y));
    });

    test('numbers containers in the order they were written', () {
      final svg = _svgOf(
        'agentflow-beta TB\n  flow one\n    flow two\n      a\n    end\n  end\n  flow three\n    b\n  end\n  three@{ view: collapsed }',
      );
      expect(_frame(svg, 'one').rect, contains('stroke="${_series(8)}'));
      expect(_frame(svg, 'two').rect, contains('stroke="${_series(8)}'));
      expect(_node(svg, 'three').body, contains('stroke="${_series(8)}'));
    });

    test('draws a container that two flows fight over once, and reports the dropped nesting', () {
      const src =
          'agentflow-beta TB\n  flow A["Flow A"]\n    a1 --> B\n  end\n  flow B["Flow B"]\n    b1 --> A\n  end';
      final svg = _svgOf(src);
      expect(_count(svg, 'data-id="A"'), 1);
      expect(_count(svg, 'data-id="B"'), 1);
      final diagnostics = _modelOf(src).diagnostics;
      expect(diagnostics.length, 1);
      expect(diagnostics[0].id, 'CONTAINMENT_VIOLATION');
      expect(diagnostics[0].severity, 'warning');
      expect(diagnostics[0].nodeId, 'B');
      expect(
        diagnostics[0].message,
        'Container "A" cannot contain "B" because "B" already contains it. The nesting that would close the loop is dropped.',
      );
    });

    test(
      'runs an edge between a node and its own flow to the border of the flow',
      () {
        List<double> ends(String d) =>
            RegExp(r'-?\d+(?:\.\d+)?')
                .allMatches(d)
                .map((m) => double.parse(m.group(0)!))
                .toList();
        final svg = _svgOf(
          'agentflow-beta TB\n  flow f["My Flow"]\n    a["Task A"] --> b["Task B"]\n    b --> f\n    f --> a\n  end',
        );
        final f = _frame(svg, 'f');
        final heldEdges = _edges(svg)
            .sublist(1)
            .map(
              (e) => ends(
                RegExp(r'<path d="([^"]+)"').firstMatch(e.body)!.group(1)!,
              ),
            )
            .toList();
        final out = heldEdges[0];
        final back = heldEdges[1];
        expect(out[0], _node(svg, 'b').x);
        expect(out[1], _node(svg, 'b').y + 24);
        expect(out[3], greaterThan(out[1]));
        expect(out[3], lessThan(f.y + f.h));
        expect(back[1], f.y);
        expect(back[3], lessThan(_node(svg, 'a').y - 24));

        final blocked = _svgOf(
          'agentflow-beta TB\n  flow f["My Flow"]\n    a["Task A"] --> b["Task B"]\n    a --> f\n  end',
        );
        final side = ends(
          RegExp(r'<path d="([^"]+)"')
              .firstMatch(_edges(blocked)[1].body)!
              .group(1)!,
        );
        expect(side[1], _node(blocked, 'a').y);
        expect(side[3], side[1]);
        expect(side[2], lessThan(side[0]));
      },
    );

    test('draws a front matter title above the diagram', () {
      final plain = render('agentflow-beta TB\n  a --> b', _cssOptions);
      final titled = render(
        '---\ntitle: Release pipeline\n---\nagentflow-beta TB\n  a --> b',
        _cssOptions,
      );
      expect(
        titled.svg,
        matches(
          RegExp(
            r'<text class="pele-title" font-weight="var\(--_tw\)"[^>]*>(?:<tspan[^>]*>)?Release pipeline',
          ),
        ),
      );
      expect(titled.height, greaterThan(plain.height));
    });

    test('writes the accessible title and description', () {
      final svg = _svgOf(
        'agentflow-beta TB\n  accTitle: Review flow\n  accDescr: How a change is reviewed\n  a --> b',
      );
      expect(svg, contains('<title id="pele-title">Review flow</title>'));
      expect(
        svg,
        contains('<desc id="pele-desc">How a change is reviewed</desc>'),
      );
    });

    test('applies classes, styles and link styles', () {
      final svg = _svgOf(
        'agentflow-beta TB\n  classDef hot fill:#fdd,stroke:#c00,color:#900\n  a["A"]:::hot --> b["B"]\n  style b stroke-width:3px\n  linkStyle 0 stroke:#0a0',
      );
      final a = _node(svg, 'a');
      expect(a.classes, 'pele-node pele-shape-rounded pele-kind-task hot');
      expect(a.body, contains('style="fill:#fdd;stroke:#c00;"'));
      expect(a.body, isNot(contains('fill-opacity')));
      expect(a.body, contains('style="fill:#900;"'));
      expect(_node(svg, 'b').body, contains('fill-opacity="0.14"'));
      expect(_node(svg, 'b').body, contains('style="stroke-width:3px;"'));
      expect(
        svg,
        matches(
          RegExp(
            r'<g class="pele-edge pele-edge-sequence" data-id="L_a_b_0" style="stroke:#0a0;">',
          ),
        ),
      );
    });

    test('picks a contrasting label color on fills a style sets', () {
      const src =
          'agentflow-beta TB\n  flow f["Flow"]\n    a["A"] --> b["B"]\n  end\n  flow p["Packed"]\n    c["C"]\n  end\n  p@{ view: "collapsed" }\n  b --> d["D"]\n  style f fill:#FFF9C4\n  style a fill:#1f3a5f\n  style b fill:#1f3a5f,color:#eee\n  style p fill:navy';
      final svg = _svgOf(src);
      expect(
        svg,
        matches(
          RegExp(
            r'data-id="f">.*?<text class="pele-cluster-label" fill="var\(--pele-fg-on-light,#1f1f1f\)"',
          ),
        ),
      );
      expect(
        _node(svg, 'a').body,
        contains('<text class="pele-label" fill="var(--pele-fg-on-dark,#fff)"'),
      );
      expect(_node(svg, 'b').body, isNot(contains('--pele-fg-on')));
      expect(
        _node(svg, 'p').body,
        contains('<text class="pele-label" fill="var(--pele-fg-on-dark,#fff)"'),
      );
      expect(_node(svg, 'd').body, isNot(contains('--pele-fg-on')));

      final flatSvg = renderMermaid(src, options: _flatOptions);
      expect(flatSvg, isNot(contains('var(--')));
      expect(_node(flatSvg, 'a').body, contains('fill="#fff"'));
    });

    test('cases edges that cross a flow fill a style sets and inks those inside it', () {
      const src =
          'agentflow-beta TB\n  flow f["Flow"]\n    a["A"] --> b["B"]\n  end\n  b --> c["C"]\n  c --> d["D"]\n  style f fill:#FFF9C4';
      final svg = _svgOf(src);
      final casings = RegExp(r'<g class="pele-casings"[^>]*>(.*?)</g>')
          .firstMatch(svg)!
          .group(1)!;
      final edgeMatches =
          RegExp(
                r'class="pele-edge [^"]*" data-id="[^"]+"([^>]*)><path d="([^"]+)"',
              )
              .allMatches(svg)
              .map((m) => (attrs: m.group(1)!, d: m.group(2)!))
              .toList();
      expect(edgeMatches.length, 3);
      expect(
        edgeMatches.map((e) => casings.contains('<path d="${e.d}"/>')).toList(),
        <bool>[false, true, false],
      );
      expect(edgeMatches.map((e) => e.attrs).toList(), <String>[
        ' stroke="var(--pele-fg-on-light,#1f1f1f)"',
        '',
        '',
      ]);
      expect(
        _svgOf(src.replaceFirst('\n  style f fill:#FFF9C4', '')),
        isNot(matches(RegExp(r'pele-casings|stroke="var\(--pele-fg-on'))),
      );

      final held = _svgOf(
        'agentflow-beta TB\n  flow f[Flow]\n    a[A]\n  end\n  f --> a\n  style f fill:white',
      );
      expect(
        held,
        matches(
          RegExp(
            r'data-id="L_f_a_0" stroke="var\(--pele-fg-on-light,#1f1f1f\)"',
          ),
        ),
      );
      expect(held, isNot(contains('pele-casings')));
    });

    test('links a clicked node and never writes a callback', () {
      final res = render(
        'agentflow-beta TB\n  a --> b\n  click a href "https://example.com/x" "Open it" _blank\n  click b call doIt()',
        _cssOptions,
      );
      expect(
        _node(res.svg, 'a').body,
        matches(
          RegExp(
            r'^<a href="https:\/\/example\.com\/x" target="_blank" rel="noopener"><title>Open it<\/title>',
          ),
        ),
      );
      expect(res.links, <LinkInfo>[
        LinkInfo(id: 'a', href: 'https://example.com/x', internal: false),
      ]);
      expect(_node(res.svg, 'b').classes, contains('clickable'));
      expect(res.svg, isNot(contains('doIt')));
    });

    test('wraps long labels and honors spacing options', () {
      final long = _svgOf(
        'agentflow-beta TB\n  a["A fairly,} long,} label,} that,} has,} to,} wrap,} over,} several,} lines,} to,} fit."]',
      );
      expect(_count(_node(long, 'a').body, '<tspan'), greaterThan(1));
      const src = 'agentflow-beta TB\n  a --> b';
      const wide =
          '---\nconfig:\n  agentflow:\n    rankSpacing: 150\n---\n$src';
      expect(
        render(wide, _cssOptions).height,
        greaterThan(render(src, _cssOptions).height + 80),
      );
    });

    test('gives nodes with short labels a common width, except a decision', () {
      double width(String svg, String id) => double.parse(
        RegExp(r'<rect[^>]* width="([\d.]+)"')
            .firstMatch(_node(svg, id).body)!
            .group(1)!,
      );
      const src =
          'agentflow-beta TB\n  a["A"] --> b["Beta"]@{ shape: tool }\n  b --> d{"ok?"}';
      final svg = _svgOf(src);
      expect(width(svg, 'a'), 156);
      expect(width(svg, 'b'), greaterThan(156));
      expect(width(svg, 'b'), lessThan(180));
      final points = RegExp(r'points="([^"]+)"')
          .firstMatch(_node(svg, 'd').body)!
          .group(1)!
          .split(RegExp(r'[ ,]'))
          .map(double.parse)
          .toList();
      var maxX = 0.0;
      for (var i = 0; i < points.length; i += 2) {
        maxX = math.max<double>(maxX, points[i]);
      }
      expect(maxX * 2, lessThan(156));
      final narrow = _svgOf(
        '---\nconfig:\n  agentflow:\n    minNodeWidth: 10\n---\n$src',
      );
      expect(width(narrow, 'a'), lessThan(60));
    });

    test('reads metadata without drawing it', () {
      const src =
          'agentflow-beta TB\n  a["A"]@{ shape: tool, params: "city :: String", retry: 2 }\n  a e1@--> b\n  e1@{ instruction: "hand off" }';
      final svg = _svgOf(src);
      expect(svg, isNot(contains('String')));
      expect(svg, isNot(contains('hand off')));
      final model = _modelOf(src);
      expect(model.nodes['a']?.metadata, <String, Object?>{
        'shape': 'subroutine',
        'params': 'city :: String',
        'retry': 2,
      });
      expect(model.edges[0].metadata, <String, Object?>{
        'instruction': 'hand off',
      });
      final semVertex = model.semanticModel().vertices[0];
      expect(semVertex.id, 'a');
      expect(semVertex.label, 'A');
      expect(semVertex.shape, 'subroutine');
      expect(semVertex.vertexKind, 'tool');
      expect(semVertex.metadata, <String, Object?>{
        'params': 'city :: String',
        'retry': 2,
      });
    });

    test(
      'skips an edge to the id Mermaid reserves and creates no node for',
      () {
        final svg = _svgOf('agentflow-beta TB\n  connectors["Mine"] --> b');
        expect(svg, isNot(contains('data-id="connectors"')));
        expect(_edges(svg), isEmpty);
        expect(_node(svg, 'b').classes, contains('pele-kind-task'));
      },
    );

    test('reports positions in the lines of the original source', () {
      const src =
          '---\nconfig:\n  agentflow:\n    nodeSpacing: 40\n---\nagentflow-beta TB\n  %% a comment that occupies a line\n  alpha["Alpha"]\n  beta["Beta"]\n  alpha --> beta';
      final model = _modelOf(src);
      final alpha = model.mappings.firstWhere((m) => m.id == 'alpha');
      expect(
        alpha,
        ElementMapping(
          id: 'alpha',
          type: 'vertex',
          position: ElementPosition(
            startLine: 8,
            startColumn: 2,
            endLine: 8,
            endColumn: 16,
            startIndex: 0,
            endIndex: 0,
          ),
        ),
      );
      final edgeMapping = model.mappings.firstWhere((m) => m.type == 'edge');
      expect(edgeMapping.position.startLine, 10);
      expect(edgeMapping.position.endLine, 10);
      expect(render(src, _cssOptions).svg, contains('data-id="alpha"'));

      expect(
        () => render(
          '---\ntitle: T\n---\nagentflow-beta TB\n  a@{ shape: rounded }  \n  b -.-> c',
          _cssOptions,
        ),
        throwsA(
          isA<PeleError>()
              .having((e) => e.line, 'line', 6)
              .having((e) => e.column, 'column', 8),
        ),
      );

      const metadata =
          '%%{init:\n{}\n}%%\nagentflow-beta\na["#35;"] --> b@{shape: ';
      expect(
        () => parse('${metadata}bad}'),
        throwsA(
          isA<PeleError>()
              .having((e) => e.code, 'code', 'semantic')
              .having((e) => e.line, 'line', 5)
              .having((e) => e.column, 'column', 16),
        ),
      );
      expect(
        () => parse('$metadata[bad}'),
        throwsA(
          isA<PeleError>()
              .having((e) => e.code, 'code', 'syntax')
              .having((e) => e.line, 'line', 5)
              .having((e) => e.column, 'column', 16)
              .having((e) => e.message, 'message', endsWith('(5:16)')),
        ),
      );
    });

    test('maps a flow from its keyword to its end, and a metadata block as an attachment', () {
      final model = _modelOf(
        'agentflow-beta TB\n  flow f["F"]\n    a["A"]\n  end\n  f@{ view: collapsed }\n  connector k["K"]',
      );
      expect(
        model.mappings
            .map(
              (m) => <Object>[
                m.id,
                m.type,
                m.position.startLine,
                m.position.endLine,
              ],
            )
            .toList(),
        <List<Object>>[
          <Object>['a', 'vertex', 3, 3],
          <Object>['f', 'subgraph', 2, 4],
          <Object>['f', 'attachment', 5, 5],
          <Object>['k', 'connector', 6, 7],
        ],
      );
    });

    test('reads comments wherever Mermaid does', () {
      const src =
          '%% before the keyword\nagentflow-beta TB %% after the direction\n  a[Plain %% not part of the label\nlabel] --> b %% after a statement\n  %% a line of its own\n  b --> c';
      final model = _modelOf(src);
      expect(model.nodes['a']?.text, 'Plain \nlabel');
      expect(model.edges.length, 2);
      expect(_svgOf(src), isNot(contains('not part')));
    });

    test('rejects what the grammar rejects, with the line', () {
      PeleError fails(String src) {
        try {
          render(src, _cssOptions);
        } on PeleError catch (error) {
          return error;
        }
        fail('expected a failure');
      }

      final open = fails(
        'agentflow-beta TB\n  flow orphan["Orphan"]\n    a --> b',
      );
      final trailing = fails(
        'agentflow-beta TB\n  flow f["F"]\n    a --> b\n\n%% trailing\n',
      );
      expect(trailing.line, 3);
      expect(trailing.column, 12);
      expect(open.code, 'syntax');
      expect(open.message, matches(RegExp(r'^Parse error on line \d+:')));
      expect(open.message, contains("Expecting 'end', got '\$end'"));
      expect(
        fails('agentflow-beta TB\n  a[50% off]').message,
        startsWith('Lexical error on line 2'),
      );
      expect(
        fails('agentflow-beta TB\n  a ==> b').message,
        startsWith('Lexical error on line 2'),
      );
      expect(
        fails('agentflow-beta TB\n  a -.-> b').message,
        startsWith('Parse error on line 2'),
      );
      expect(
        fails('agentflow-beta TB\n  subgraph s\n  a\n  end').message,
        startsWith('Parse error on line 2'),
      );
      expect(
        fails('agentflow-beta TB\n  a@{ label: a^b }').message,
        startsWith('Lexical error on line 2'),
      );
    });

    test(
      'rejects an unknown shape and unreadable metadata, pointing at the block',
      () {
        PeleError fails(String src) {
          try {
            parse(src);
          } on PeleError catch (error) {
            return error;
          }
          fail('expected a failure');
        }

        final shape = fails(
          '---\ntitle: T\n---\nagentflow-beta TB\n  a["A"]@{ shape: Rounded }',
        );
        expect(shape.code, 'semantic');
        expect(
          shape.message,
          'No such shape: Rounded. Shape names should be lowercase.',
        );
        expect(<int>[shape.line, shape.column], <int>[5, 9]);
        expect(
          fails('agentflow-beta TB\n  a@{ shape: nope }').message,
          'No such shape: nope.',
        );
        expect(
          fails('agentflow-beta TB\n  a@{ shape: 123 }').message,
          'No such shape: 123.',
        );

        final yaml = fails(
          'agentflow-beta TB\n  b["B"]\n  a["A"]@{\n\tshape: rounded\n  }',
        );
        expect(yaml.code, 'syntax');
        expect(
          yaml.message,
          matches(RegExp(r'^Metadata of "a" is not valid YAML\. .* \(3:9\)$')),
        );
        expect(<int>[yaml.line, yaml.column], <int>[3, 9]);
      },
    );

    test('accepts trailing commas in a multi-line metadata block', () {
      final model = _modelOf(
        'agentflow-beta TB\n  connector gh["GitHub"]@{\n    protocol: "mcp",\n    tools: ["read",\n      "write"],\n  }',
      );
      expect(model.connectors['gh']?.metadata, <String, Object?>{
        'protocol': 'mcp',
        'tools': <Object?>['read', 'write'],
      });
    });

    test('strips prototype-shaped keys from metadata at every depth', () {
      final model = _modelOf(
        'agentflow-beta TB\n  a@{\n    __proto__:\n      polluted: true\n    params:\n      - constructor: x\n        name: first\n    kept: 1\n  }',
      );
      expect(
        jsonEncode(model.nodes['a']?.metadata),
        '{"params":[{"name":"first"}],"kept":1}',
      );
    });

    test('escapes hostile text and blocks unsafe links', () {
      const h = 'agentflow-beta TB\n';
      final svg = renderMermaid(
        '$h  a["<img src=x onerror=alert(1)>"] -- "</text><script>alert(1)</script>" --> b["a&b"]\n  flow f["<svg onload=alert(1)>"]\n   c\n  end',
        options: _flatOptions,
      );
      expect(svg, isNot(contains('<img')));
      expect(svg, isNot(contains('<script')));
      expect(svg, isNot(contains('<svg onload')));
      expect(svg, contains('a&amp;b'));

      for (final url in <String>[
        'javascript:alert(1)',
        ' JaVaScRiPt:alert(1)',
        'data:text/html,<script>alert(1)</script>',
        'vbscript:x',
      ]) {
        final res = render('$h  a\n  click a href "$url"', _flatOptions);
        expect(
          res.svg,
          isNot(
            matches(
              RegExp(
                r'href="(?:\s*javascript|data|vbscript)',
                caseSensitive: false,
              ),
            ),
          ),
        );
      }

      final internal = render(
        '$h  a["javascript:alert(1)"]:::internal-link',
        _cssOptions,
      );
      expect(
        internal.svg,
        contains('<a class="internal-link" data-href="javascript:alert(1)">'),
      );
      expect(internal.links, <LinkInfo>[
        LinkInfo(id: 'a', href: 'javascript:alert(1)', internal: true),
      ]);
    });
  });
}
