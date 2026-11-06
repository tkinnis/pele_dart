import 'dart:math' as math;

import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/usecase/index.dart';
import 'package:test/test.dart';

const RenderOptions _cssOptions = RenderOptions(
  measurer: metricsMeasurer,
  outputMode: SvgOutputMode.cssVariables,
);

const RenderOptions _flatOptions = RenderOptions(
  measurer: metricsMeasurer,
  outputMode: SvgOutputMode.flattened,
);

String _svgOf(String src) =>
    renderMermaid('usecase-beta\n$src', options: _cssOptions);

int _count(String svg, String needle) => svg.split(needle).length - 1;

({double x, double y}) _at(String svg, String id) {
  final m = RegExp(
    '<g class="pele-node [^"]*" data-id="${RegExp.escape(id)}" transform="translate\\(([-\\d.]+),([-\\d.]+)\\)"',
  ).firstMatch(svg);
  if (m == null) {
    throw StateError('no node $id');
  }
  return (x: double.parse(m.group(1)!), y: double.parse(m.group(2)!));
}

String _nodeGroup(String svg, String id) {
  final start = svg.indexOf('data-id="$id" transform=');
  if (start == -1) {
    throw StateError('no node $id');
  }
  final from = svg.lastIndexOf('<g class="pele-node', start);
  final next = svg.indexOf('<g class="pele-node', start + 1);
  return svg.substring(from, next == -1 ? svg.length : next);
}

({double x, double y, double rx, double ry}) _ellipse(String svg, String id) {
  final m = RegExp(r'<ellipse rx="([\d.]+)" ry="([\d.]+)"')
      .firstMatch(_nodeGroup(svg, id));
  if (m == null) {
    throw StateError('no ellipse in $id');
  }
  final pos = _at(svg, id);
  return (
    x: pos.x,
    y: pos.y,
    rx: double.parse(m.group(1)!),
    ry: double.parse(m.group(2)!),
  );
}

List<({double x, double y, double w, double h})> _boundary(
  String svg,
  String id,
) {
  final tag = svg.indexOf('data-id="$id">');
  final from = svg.lastIndexOf('<g class="pele-cluster', tag);
  final to = svg.indexOf('</g>', tag);
  final group = svg.substring(from, to);
  final re = RegExp(
    r'<rect[^>]*? x="([-\d.]+)" y="([-\d.]+)" width="([\d.]+)" height="([\d.]+)"',
  );
  return <({double x, double y, double w, double h})>[
    for (final m in re.allMatches(group))
      (
        x: double.parse(m.group(1)!),
        y: double.parse(m.group(2)!),
        w: double.parse(m.group(3)!),
        h: double.parse(m.group(4)!),
      ),
  ];
}

List<({String id, String classes, String d, String body})> _edges(String svg) {
  final re = RegExp(
    r'<g class="pele-edge ([^"]*)" data-id="([^"]*)"[^>]*><path d="([^"]+)"([^>]*)\/>(.*?)<\/g>',
  );
  return <({String id, String classes, String d, String body})>[
    for (final m in re.allMatches(svg))
      (
        classes: m.group(1)!,
        id: m.group(2)!,
        d: m.group(3)!,
        body: '${m.group(4)!}${m.group(5)!}',
      ),
  ];
}

(double, double, double, double) _ends(String d) {
  final nums = <double>[
    for (final m in RegExp(r'-?\d+(?:\.\d+)?').allMatches(d))
      double.parse(m.group(0)!),
  ];
  return (nums[0], nums[1], nums[nums.length - 2], nums[nums.length - 1]);
}

void main() {
  group('use case diagram rendering', () {
    test('is detected, supported and typed in both cssVariables and flattened modes', () {
      const src = 'usecase-beta\nactor User\nUser --> Login';
      expect(detectType(src), 'usecase');
      expect(supports(src), isTrue);

      final result = render(src, _cssOptions);
      expect(result.type, 'usecase');
      expect(
        result.svg,
        startsWith(
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele pele-usecase"',
        ),
      );
      expect(
        result.svg,
        contains(
          'viewBox="0 0 ${result.width.toInt()} ${result.height.toInt()}"',
        ),
      );
      expect(result.links, isEmpty);
      expect(result.svg, contains('var(--_fg)'));

      final flatSvg = renderMermaid(src, options: _flatOptions);
      expect(
        flatSvg,
        startsWith(
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele pele-usecase"',
        ),
      );
      expect(flatSvg, isNot(contains('var(--')));
      expect(flatSvg, isNot(contains('color-mix(')));
      expect(flatSvg, contains('>User</text>'));
      expect(flatSvg, contains('>Login</text>'));

      final model = parse(src) as UsecaseModel;
      expect(model.type, 'usecase');
      expect(model.actors.keys.toList(), <String>['User']);
      expect(model.useCases.keys.toList(), <String>['Login']);
      expect(model.statements.map((s) => s.kind).toList(), <String>[
        'node',
        'edge',
      ]);
    });

    test('runs left to right unless told otherwise', () {
      const chain = 'actor A\nA --> B\nB --> C';
      final wide = render('usecase-beta\n$chain', _cssOptions);
      expect(wide.width, greaterThan(wide.height));
      expect(_at(wide.svg, 'A').x, lessThan(_at(wide.svg, 'B').x));

      final tall = render('usecase-beta\ndirection TB\n$chain', _cssOptions);
      expect(tall.height, greaterThan(tall.width));
      expect(_at(tall.svg, 'A').y, lessThan(_at(tall.svg, 'B').y));
      expect(
        render('usecase-beta\ndirection TD\n$chain', _cssOptions).svg,
        tall.svg,
      );

      final up = _svgOf('direction BT\n$chain');
      expect(_at(up, 'A').y, greaterThan(_at(up, 'B').y));

      final back = _svgOf('direction RL\n$chain');
      expect(_at(back, 'A').x, greaterThan(_at(back, 'B').x));
    });

    test('draws each kind of actor as a figure with its name below', () {
      final svg = _svgOf(
        'actor N("Normal one")\nactor H@{ type: hollow }\nactor W@{ type: awesome }\nactor I@{ icon: "fa:user" }',
      );
      final normal = _nodeGroup(svg, 'N');
      expect(
        normal,
        contains(
          'class="pele-node pele-actor usecase-actor usecase-actor-normal"',
        ),
      );
      expect(normal, contains('<circle cy="-21" r="9"'));
      expect(normal, contains('M0,-12V10M-14,-3H14M0,10L-12,30M0,10L12,30'));
      expect(normal, contains('>Normal one</text>'));

      final figureY = double.parse(
        RegExp(r'pele-actor-figure" transform="translate\(0,([-\d.]+)\)')
            .firstMatch(normal)!
            .group(1)!,
      );
      final labelY = double.parse(
        RegExp(r'<text class="pele-label" x="0" y="([-\d.]+)"')
            .firstMatch(normal)!
            .group(1)!,
      );
      expect(labelY, greaterThan(figureY + 30));

      final hollow = _nodeGroup(svg, 'H');
      expect(hollow, contains('usecase-actor-hollow'));
      expect(_count(hollow, 'fill="var(--_bg)"'), 2);

      final awesome = _nodeGroup(svg, 'W');
      expect(awesome, contains('fill="var(--_b)"'));
      expect(awesome, isNot(contains('<circle')));

      final icon = _nodeGroup(svg, 'I');
      expect(icon, contains('<svg class="pele-icon" data-icon="fa:user"'));
      expect(icon, contains('<rect x="-22" y="-26" width="44" height="44"'));
    });

    test('fills an icon actor from the icon resolver', () {
      final svg = renderMermaid(
        'usecase-beta\nactor I@{ icon: "fa:user" }',
        options: RenderOptions(
          measurer: metricsMeasurer,
          outputMode: SvgOutputMode.cssVariables,
          icons: (name) => name == 'fa:user' ? '<path d="M1,1"/>' : null,
        ),
      );
      expect(svg, contains('data-icon="fa:user"'));
      expect(svg, contains('stroke-linejoin="round"><path d="M1,1"/></svg>'));
    });

    test('marks business actors and business use cases with a slash', () {
      final svg = _svgOf(
        'actor A@{ business: true }\nactor B@{ type: hollow, business: true }\nU(Use)@{ business: true }\nV(Plain)',
      );
      expect(_count(_nodeGroup(svg, 'A'), 'class="pele-business"'), 1);
      expect(_count(_nodeGroup(svg, 'B'), 'class="pele-business"'), 1);
      expect(_count(_nodeGroup(svg, 'U'), 'class="pele-business"'), 1);
      expect(_count(_nodeGroup(svg, 'V'), 'class="pele-business"'), 0);

      final uEllipse = _ellipse(svg, 'U');
      final d = RegExp(r'class="pele-business" d="([^"]+)"')
          .firstMatch(_nodeGroup(svg, 'U'))!
          .group(1)!;
      final (x1, y1, x2, y2) = _ends(d);
      for (final (x, y) in <(double, double)>[(x1, y1), (x2, y2)]) {
        expect(
          math.pow(x / uEllipse.rx, 2) + math.pow(y / uEllipse.ry, 2),
          closeTo(1.0, 0.1),
        );
      }
      expect(y1, greaterThan(0));
      expect(y2, lessThan(0));
    });

    test(
      'draws use cases as ovals, and as boxes when written with brackets',
      () {
        final svg = _svgOf(
          'Login("Sign in")\nReport[Generate report]\n"Reset password"',
        );
        final oval = _nodeGroup(svg, 'Login');
        expect(
          oval,
          contains(
            'class="pele-node pele-usecase usecase-element usecase-ellipse"',
          ),
        );
        expect(_count(oval, '<ellipse'), 1);
        expect(oval, contains('>Sign in</text>'));

        final box = _nodeGroup(svg, 'Report');
        expect(box, contains('usecase-rect'));
        expect(_count(box, '<rect'), 1);
        expect(_count(box, '<ellipse'), 0);
        expect(
          _nodeGroup(svg, 'Reset_password'),
          contains('>Reset password</text>'),
        );

        final loginEllipse = _ellipse(svg, 'Login');
        expect(
          loginEllipse.rx * 2,
          greaterThan(metricsMeasurer.width('Sign in', 16, 0) + 30),
        );
      },
    );

    test('shows a stereotype above the name of a use case and between figure and name of an actor', () {
      final svg = _svgOf('actor A <<Human>>\nU(Use) <<Core>>');
      double yOf(String group, String cls) => double.parse(
        RegExp('<text class="$cls"[^>]* y="([-\\d.]+)"')
            .firstMatch(group)!
            .group(1)!,
      );

      final uc = _nodeGroup(svg, 'U');
      expect(uc, contains('>«Core»</text>'));
      expect(yOf(uc, 'pele-stereotype'), lessThan(yOf(uc, 'pele-label')));

      final actor = _nodeGroup(svg, 'A');
      expect(actor, contains('>«Human»</text>'));
      expect(yOf(actor, 'pele-stereotype'), lessThan(yOf(actor, 'pele-label')));
      expect(yOf(actor, 'pele-stereotype'), greaterThan(0));
    });

    test('draws a boundary around its members and leaves the rest outside', () {
      final svg = _svgOf(
        'actor User\nsystemBoundary Shop["The shop"]\n  Browse\n  actor Clerk\nend\nUser --> Browse',
      );
      final box = _boundary(svg, 'Shop').first;
      expect(
        svg,
        contains(
          '<g class="pele-cluster pele-boundary system-boundary system-boundary-rect" data-id="Shop">',
        ),
      );
      expect(svg, contains('>The shop</text>'));

      bool inside(String id) {
        final p = _at(svg, id);
        return p.x > box.x &&
            p.x < box.x + box.w &&
            p.y > box.y &&
            p.y < box.y + box.h;
      }

      expect(inside('Browse'), isTrue);
      expect(inside('Clerk'), isTrue);
      expect(inside('User'), isFalse);
      expect(_at(svg, 'User').x, lessThan(box.x));
    });

    test('draws a boundary fill the author sets at full opacity', () {
      final svg = _svgOf(
        'systemBoundary S\n  U\nend\nsystemBoundary T\n  V\nend\nstyle S fill:#fee',
      );
      String body(String id) {
        final tail = svg.substring(svg.indexOf('data-id="$id">'));
        return RegExp(r'<rect [^>]*>')
            .allMatches(tail)
            .map((m) => m.group(0)!)
            .firstWhere((r) => r.contains('fill="var(--_a)"'));
      }

      expect(body('S'), isNot(contains('fill-opacity')));
      expect(body('T'), contains('fill-opacity="0.5"'));
    });

    test('picks a contrasting text color on fills a style sets', () {
      final svg = _svgOf(
        'actor A <<Human>>\nU(Use) <<Core>>\nW(Own)\nX(Plain)\njson J@{ "k": "v" }\nsystemBoundary S\n  V\nend\nstyle U fill:#1f3a5f\nstyle A fill:#1f3a5f\nstyle W fill:#1f3a5f,color:#eee\nstyle J fill:navy\nstyle S fill:#FFF9C4',
      );
      String node(String id) =>
          RegExp('data-id="$id"[^>]*>(.*?)</g>(?:<g|</g>)')
              .firstMatch(svg)!
              .group(1)!;

      expect(
        node('U'),
        matches(
          RegExp(
            r'<text class="pele-stereotype"[^>]* fill="var\(--pele-fg-on-dark,#fff\)"',
          ),
        ),
      );
      expect(
        node('U'),
        matches(
          RegExp(
            r'<text class="pele-label" fill="var\(--pele-fg-on-dark,#fff\)"[^>]*>Use<',
          ),
        ),
      );
      expect(
        svg,
        matches(
          RegExp(
            r'data-id="A"[^>]*>.*?<text class="pele-stereotype"[^>]* fill="var\(--_m\)"',
          ),
        ),
      );
      expect(
        svg,
        matches(
          RegExp(r'data-id="A"[^>]*>.*?<text class="pele-label" x=[^>]*>A<'),
        ),
      );
      expect(node('W'), isNot(contains('--pele-fg-on')));
      expect(
        node('J'),
        matches(
          RegExp(
            r'<text class="pele-json-key" fill="var\(--pele-fg-on-dark,#fff\)"',
          ),
        ),
      );
      expect(
        node('J'),
        matches(
          RegExp(
            r'<text class="pele-json-value" fill="var\(--pele-fg-on-dark,#fff\)"',
          ),
        ),
      );
      expect(
        svg,
        matches(
          RegExp(
            r'data-id="S">.*?<text class="pele-cluster-label" fill="var\(--pele-fg-on-light,#1f1f1f\)"',
          ),
        ),
      );
      expect(node('X'), isNot(contains('--pele-fg-on')));
    });

    test('cases edges that cross a boundary fill a style sets and inks those inside it', () {
      const src =
          'actor User\nsystemBoundary S\n  Pay\n  Ship\nend\nPay --> Ship\nUser --> Pay\nUser --> Other\nstyle S fill:#BBDEFB';
      final svg = _svgOf(src);
      final casings = RegExp(r'<g class="pele-casings"[^>]*>(.*?)<\/g>')
          .firstMatch(svg)!
          .group(1)!;
      final edgeMatches = RegExp(
        r'class="pele-edge [^"]*" data-id="[^"]+"([^>]*)><path d="([^"]+)"',
      ).allMatches(svg).map((m) => <String>[m.group(1)!, m.group(2)!]).toList();
      expect(edgeMatches, hasLength(3));
      expect(
        edgeMatches
            .map((e) => casings.contains('<path d="${e[1]}"/>'))
            .toList(),
        <bool>[false, true, false],
      );
      expect(edgeMatches.map((e) => e[0]).toList(), <String>[
        ' stroke="var(--pele-fg-on-light,#1f1f1f)"',
        '',
        '',
      ]);
      expect(
        _svgOf(src.replaceFirst('\nstyle S fill:#BBDEFB', '')),
        isNot(matches(RegExp(r'pele-casings|stroke="var\(--pele-fg-on'))),
      );
      final hollow = _svgOf(
        'systemBoundary S\n  Pay\n  Ship\nend\nPay --|> Ship\nstyle S fill:black',
      );
      expect(
        hollow,
        matches(
          RegExp(
            r'class="pele-marker"[^>]* fill="black" stroke="var\(--pele-fg-on-dark,#fff\)"',
          ),
        ),
      );
    });

    test('gives a package boundary a tab that holds its title', () {
      final svg = _svgOf(
        'systemBoundary P["Payments"]@{ type: package }\n  Pay\nend',
      );
      final rects = _boundary(svg, 'P');
      final tab = rects[0];
      final body = rects[1];
      expect(svg, contains('system-boundary-package'));
      expect(svg, contains('class="pele-boundary-tab"'));
      expect(tab.x, body.x);
      expect(tab.y + tab.h, closeTo(body.y, 0.1));
      expect(tab.w, lessThan(body.w));

      final title = RegExp(
        r'<text class="pele-cluster-label"[^>]* x="([-\d.]+)" y="([-\d.]+)"',
      ).firstMatch(svg)!;
      expect(double.parse(title.group(1)!), greaterThan(tab.x));
      expect(double.parse(title.group(1)!), lessThan(tab.x + tab.w));
      expect(double.parse(title.group(2)!), lessThan(body.y));
      expect(_at(svg, 'Pay').y, greaterThan(body.y));
    });

    test('draws the marker each association asks for', () {
      final svg = _svgOf(
        'A a@--> B\nA b@<-- B\nA c@-- B\nA d@--o B\nA e@o-- B\nA f@--x B\nA g@x-- B',
      );
      final byId = <String, String>{for (final e in _edges(svg)) e.id: e.body};
      List<String> kinds(String id) => <String>[
        for (final m in RegExp(
          r'<(path|circle) class="pele-marker"',
        ).allMatches(byId[id]!))
          m.group(1)!,
      ];

      expect(kinds('a'), <String>['path']);
      expect(kinds('b'), <String>['path']);
      expect(kinds('c'), isEmpty);
      expect(kinds('d'), <String>['circle']);
      expect(kinds('e'), <String>['circle']);
      expect(kinds('f'), <String>['path']);
      expect(kinds('g'), <String>['path']);
      expect(byId['a'], contains('stroke="none"'));
      expect(byId['f'], isNot(contains('stroke="none"')));
      for (final edge in _edges(svg)) {
        expect(edge.body, isNot(contains('stroke-dasharray')));
      }
    });

    test('draws include and extend dashed, with an arrow and their name in guillemets', () {
      final svg = _svgOf('A i@..> : include B\nC e@..> : EXTEND D');
      final list = _edges(svg);
      final include = list[0];
      final extend = list[1];
      expect(include.classes, 'pele-include');
      expect(extend.classes, 'pele-extend');
      for (final edge in <({String id, String classes, String d, String body})>[
        include,
        extend,
      ]) {
        expect(edge.body, contains('stroke-dasharray="5 4"'));
        expect(_count(edge.body, 'class="pele-marker"'), 1);
      }
      expect(svg, contains('>«include»</text>'));
      expect(svg, contains('>«extend»</text>'));
      expect(_count(svg, 'class="pele-edge-label"'), 2);
    });

    test('draws a generalization as a solid line with a hollow triangle', () {
      final svg = _svgOf('actor Admin\nactor Person\nAdmin --|> Person');
      final edge = _edges(svg).first;
      expect(edge.classes, 'pele-generalization');
      expect(edge.body, isNot(contains('stroke-dasharray')));
      expect(
        edge.body,
        matches(
          RegExp(
            r'<path class="pele-marker" d="M[-\d.]+,[-\d.]+L[-\d.]+,[-\d.]+L[-\d.]+,[-\d.]+Z" fill="var\(--_bg\)" stroke="var\(--_l\)"',
          ),
        ),
      );
      final (_, _, ex, _) = _ends(edge.d);
      final tip = double.parse(
        RegExp(r'class="pele-marker" d="M([-\d.]+),')
            .firstMatch(edge.body)!
            .group(1)!,
      );
      expect(tip - ex, closeTo(12, 0.5));
    });

    test('draws a relationship from a use case to itself as a loop with its label beside it', () {
      for (final dir in const <String>['LR', 'TB']) {
        final svg = _svgOf('direction $dir\nLogin loop@..> : include Login');
        final edge = _edges(svg).first;
        expect(edge.d, matches(RegExp(r'^M[-\d.,]+C[-\d., ]+$')));
        final el = _ellipse(svg, 'Login');
        final label = RegExp(
          r'<g class="pele-edge-label" data-id="loop"><rect x="([-\d.]+)" y="([-\d.]+)"',
        ).firstMatch(svg)!;
        if (dir == 'LR') {
          expect(double.parse(label.group(2)!), greaterThan(el.y + el.ry));
        } else {
          expect(double.parse(label.group(1)!), greaterThan(el.x + el.rx));
        }
        expect(svg, isNot(contains('NaN')));
      }
    });

    test('attaches a note to its target with a dotted line and no marker', () {
      final svg = _svgOf(
        'actor User\nnote for User "Starts the workflow"\nnote for Login "`Needs a **session**`"\nUser --> Login',
      );
      expect(_count(svg, 'class="pele-node pele-note usecase-note"'), 2);
      expect(svg, contains('>Starts the workflow</text>'));
      expect(svg, contains('<tspan font-weight="var(--_w)">session</tspan>'));
      final connectors = _edges(svg)
          .where((e) => e.classes == 'pele-note')
          .toList();
      expect(connectors.map((e) => e.id).toList(), <String>[
        'note-0-edge',
        'note-1-edge',
      ]);
      for (final connector in connectors) {
        expect(connector.body, contains('stroke-dasharray="2 3"'));
        expect(connector.body, isNot(contains('pele-marker')));
      }
    });

    test('draws a JSON node as a table of its leaves in written order', () {
      final svg = _svgOf(
        'json Payload@{\n  "2": "second",\n  "1": "first",\n  "colors": ["Red", "Green"],\n  "address": { "city": "Oslo" },\n  "none": null,\n  "empty": {}\n}',
      );
      final table = _nodeGroup(svg, 'Payload');
      expect(table, contains('class="pele-node pele-json usecase-json-table"'));
      expect(
        table,
        matches(
          RegExp(
            r'<text class="pele-label" font-weight="var\(--_hw\)"[^>]*><tspan x="0" y="-95.9">Payload<\/tspan>',
          ),
        ),
      );
      final keys = <String>[
        for (final m in RegExp(
          r'<text class="pele-json-key"[^>]*>([^<]*)<\/text>',
        ).allMatches(table))
          m.group(1)!,
      ];
      final values = <String>[
        for (final m in RegExp(
          r'<text class="pele-json-value"[^>]*>([^<]*)<\/text>',
        ).allMatches(table))
          m.group(1)!,
      ];
      expect(keys, <String>[
        '2',
        '1',
        'colors',
        'address.city',
        'none',
        'empty',
      ]);
      expect(values, <String>[
        'second',
        'first',
        'Red',
        'Green',
        'Oslo',
        'null',
        '{}',
      ]);
    });

    test('shows plain labels as written and formats markdown labels', () {
      final svg = _svgOf(
        'A("*n* <b>x</b> \\n &amp;")\nQ("a #quot;q#quot; #40;b#41;")\nB("`**bold** and *italic*`")\nC(*literal*)',
      );
      expect(
        _nodeGroup(svg, 'A'),
        contains('>*n* &lt;b&gt;x&lt;/b&gt; \\n &amp;amp;</text>'),
      );
      expect(_nodeGroup(svg, 'Q'), contains('>a &quot;q&quot; (b)</text>'));
      final formatted = _nodeGroup(svg, 'B');
      expect(formatted, contains(' font-weight="var(--_w)">bold</tspan>'));
      expect(formatted, contains('<tspan font-style="italic">italic</tspan>'));
      expect(_nodeGroup(svg, 'C'), contains('>*literal*</text>'));
    });

    test('applies classes and styles to nodes, boundaries and explicit edges in both modes', () {
      const body =
          'actor A:::hot\nU(Use)\nsystemBoundary S\n  V\nend\nA e@--> U\nclassDef hot fill:#fee,stroke:#c33,color:#900\nclassDef default stroke-width:2px\nclass U,S,e hot\nstyle U stroke:#06c\nstyle e stroke-width:4px';
      final svg = _svgOf(body);
      final actor = _nodeGroup(svg, 'A');
      expect(actor, contains('usecase-actor-normal hot"'));
      expect(
        actor,
        contains('style="stroke-width:2px;fill:#fee;stroke:#c33;"'),
      );
      expect(actor, contains('style="fill:#900;"'));
      expect(
        _nodeGroup(svg, 'U'),
        contains(
          '<ellipse rx="44" ry="26" fill="var(--_s)" stroke="var(--_b)" style="stroke-width:2px;fill:#fee;stroke:#06c;"/>',
        ),
      );
      expect(
        svg,
        matches(
          RegExp(
            r'<g class="pele-cluster pele-boundary system-boundary system-boundary-rect hot" data-id="S"><rect[^>]* style="rx:var\(--_r\);stroke-width:2px;fill:#fee;stroke:#c33;"',
          ),
        ),
      );
      expect(
        svg,
        contains(
          '<g class="pele-edge pele-association hot" data-id="e" style="stroke-width:4px;stroke:#c33;">',
        ),
      );
      expect(_edges(svg)[0].body, contains('fill="#c33" stroke="none"'));

      final flatSvg = renderMermaid(
        'usecase-beta\n$body',
        options: _flatOptions,
      );
      expect(flatSvg, isNot(contains('var(--')));
      expect(flatSvg, contains('rx="4"'));
    });

    test('keeps the dashes of an animated relationship, without motion', () {
      final svg = _svgOf(
        'A e@--> B\ne@{ animation: slow }\nA f@--> B\nf@{ animate: false }',
      );
      final list = _edges(svg);
      expect(list[0].classes, 'pele-association edge-animation-slow');
      expect(list[0].body, contains('stroke-dasharray="9 5"'));
      expect(list[1].body, isNot(contains('stroke-dasharray')));
    });

    test('draws the front matter title and the accessible names', () {
      final svg = renderMermaid(
        '---\ntitle: Ordering\n---\nusecase-beta\naccTitle: Online ordering\naccDescr {\n  A customer orders.\n   Staff review.\n}\nactor A',
        options: _cssOptions,
      );
      expect(
        svg,
        contains('<text class="pele-title" font-weight="var(--_tw)"'),
      );
      expect(svg, contains('>Ordering</tspan>'));
      expect(svg, contains('<title id="pele-title">Online ordering</title>'));
      expect(
        svg,
        contains(
          '<desc id="pele-desc">A customer orders.\nStaff review.</desc>',
        ),
      );
    });

    test(
      'puts an actor that is pointed at on the far side of the boundary',
      () {
        final svg = _svgOf(
          'actor User\nactor Bank\nsystemBoundary Shop\n  Pay\nend\nUser --> Pay\nPay --> Bank',
        );
        final box = _boundary(svg, 'Shop').first;
        expect(_at(svg, 'User').x, lessThan(box.x));
        expect(_at(svg, 'Bank').x, greaterThan(box.x + box.w));
      },
    );

    test(
      'puts a forward marker at the target and a backward one at the source',
      () {
        final svg = _svgOf('A a@--> B\nC b@<-- D');
        double tip(String id) {
          final body = _edges(svg).firstWhere((e) => e.id == id).body;
          return double.parse(
            RegExp(r'class="pele-marker" d="M([-\d.]+),')
                .firstMatch(body)!
                .group(1)!,
          );
        }

        expect(
          (tip('a') - _at(svg, 'B').x).abs(),
          lessThan((tip('a') - _at(svg, 'A').x).abs()),
        );
        expect(
          (tip('b') - _at(svg, 'C').x).abs(),
          lessThan((tip('b') - _at(svg, 'D').x).abs()),
        );
      },
    );

    test('labels an association and keeps the label off the nodes', () {
      final svg = _svgOf('actor User\nUser -- "starts a session" --> Login');
      expect(svg, contains('>starts a session</text>'));
      final m = RegExp(
        r'<g class="pele-edge-label" data-id="edge-0"><rect x="([-\d.]+)" y="[-\d.]+" width="([\d.]+)"',
      ).firstMatch(svg)!;
      final left = double.parse(m.group(1)!);
      final right = left + double.parse(m.group(2)!);
      final login = _ellipse(svg, 'Login');
      expect(left, greaterThan(_at(svg, 'User').x + 20));
      expect(right, lessThan(login.x - login.rx));
    });

    test('ends relationships on the outline of an oval and beside the figure of an actor', () {
      final svg = _svgOf(
        'actor User\nUser --> Login\nUser --> Logout\nOther -- Login',
      );
      for (final edge in _edges(svg)) {
        final (sx, sy, ex, ey) = _ends(edge.d);
        final target = edge.id == 'edge-1' ? 'Logout' : 'Login';
        final el = _ellipse(svg, target);
        final reach = edge.id == 'edge-2' ? 0.0 : 7.0;
        final onOutline =
            math.pow((ex + reach - el.x) / el.rx, 2) +
            math.pow((ey - el.y) / el.ry, 2);
        expect(onOutline, greaterThan(0.85));
        expect(onOutline, lessThan(1.15));
        if (edge.id != 'edge-2') {
          final user = _at(svg, 'User');
          expect(sx - user.x, closeTo(23, 0.5));
          expect(sy, lessThan(user.y));
        }
      }
    });

    test('spreads the relationships that meet on one side of a use case', () {
      final svg = _svgOf(
        'actor A\nactor B\nactor C\nA --> U\nB --> U\nC --> U',
      );
      final ys = _edges(svg).map((e) => _ends(e.d).$4).toList();
      expect(ys.map((y) => y.round()).toSet().length, 3);
      final sorted = List<double>.of(ys)..sort();
      expect(sorted[1] - sorted[0], greaterThan(6));
    });

    test('gives longer operators more ranks', () {
      final near = _svgOf('A --> B');
      final far = _svgOf('A ----> B');
      expect(
        _at(far, 'B').x - _at(far, 'A').x,
        greaterThan(_at(near, 'B').x - _at(near, 'A').x + 100),
      );
    });

    test('breaks a markdown label where the source breaks', () {
      final svg = _svgOf('A("`first\nsecond`")');
      final label = _nodeGroup(svg, 'A');
      expect(_count(label, '<tspan'), 2);
      expect(label, contains('>first</tspan>'));
      expect(label, contains('>second</tspan>'));
    });

    test('draws nothing but the frame for a diagram with no statements', () {
      final result = render('usecase-beta', _cssOptions);
      expect(result.svg, contains('<g class="pele-nodes"></g>'));
      expect(result.width, greaterThan(0));
    });

    test('parseOrderedJson preserves key order and validates root', () {
      final res = parseOrderedJson(
        '{"10":"ten","2":"two","1":"one","entry":{"old":1},"entry":{"b":2,"a":1}}',
        () => (1, 1),
      );
      expect(res.propertyOrder[''], <String>['10', '2', '1', 'entry']);
      expect(res.propertyOrder['/entry'], <String>['b', 'a']);
      expect(
        () => parseOrderedJson('[1, 2]', () => (5, 3)),
        throwsA(
          isA<PeleError>()
              .having((e) => e.line, 'line', 5)
              .having((e) => e.column, 'column', 3),
        ),
      );
    });

    test('reports syntax, lexer and semantic errors as Mermaid words them', () {
      String message(String src) {
        try {
          render(src, _cssOptions);
        } on PeleError catch (error) {
          return '${error.code}: ${error.message}';
        }
        return 'no error';
      }

      expect(
        message('usecase-beta\nactor A actor B'),
        "syntax: Error parsing usecase diagram: Expecting: one of these possible Token sequences:\n  1. [NEWLINE]\n  2. [EOF]\nbut found: 'actor' at line 2, column 9 [21,26)",
      );
      expect(
        message('usecase-beta\nsystemBoundary S\nA --> B\nend'),
        "syntax: Error parsing usecase diagram: Expecting: one of these possible Token sequences:\n  1. [NEWLINE]\n  2. [EOF]\nbut found: '-->' at line 3, column 3 [32,35)",
      );
      expect(
        message('usecase-beta\nsystemBoundary S\nA'),
        "syntax: Error parsing usecase diagram: Expecting token of type --> END <-- but found --> '' <-- at line 4, column 1 [32,32)",
      );
      expect(
        message('usecase-beta\nA "b'),
        'syntax: Error lexing usecase diagram: unexpected character: ->"<- at offset: 15, skipped 1 characters. at line 2, column 3 [15,16)',
      );
      expect(
        message('usecase-beta\nnote for Ghost "x"'),
        "semantic: Note target 'Ghost' is unresolved at line 2, column 10 [22,27)",
      );
      expect(
        message('usecase-beta\njson P@{"a":}'),
        matches(RegExp(r'^syntax: Invalid JSON: .* \(line 2, column \d+\)$')),
      );

      PeleError? jsonErr;
      try {
        render('usecase-beta\njson P@{"a":"#35;", "b":}', _cssOptions);
      } on PeleError catch (e) {
        jsonErr = e;
      }
      expect(jsonErr, isNotNull);
      expect(jsonErr!.line, 2);
      expect(jsonErr.column, 25);
      expect(jsonErr.message, isNot(matches(RegExp(r'[ﬂ°¶ß]'))));

      PeleError? located;
      try {
        render('usecase-beta\nactor A\nA --> B\nstyle Z fill:red', _cssOptions);
      } on PeleError catch (e) {
        located = e;
      }
      expect(located, isNotNull);
      expect(located!.code, 'semantic');
      expect(located.type, 'usecase');
      expect(located.line, 4);
      expect(located.column, 7);
    });
  });
}
