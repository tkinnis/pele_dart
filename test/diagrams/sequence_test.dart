import 'package:pele_dart/src/detect.dart';
import 'package:pele_dart/src/diagrams/sequence/db.dart';
import 'package:pele_dart/src/diagrams/sequence/index.dart';
import 'package:pele_dart/src/diagrams/sequence/types.dart';
import 'package:pele_dart/src/errors.dart';
import 'package:pele_dart/src/preprocess.dart';
import 'package:pele_dart/src/svg/flattener.dart';
import 'package:pele_dart/src/svg/palette.dart';
import 'package:pele_dart/src/text/entities.dart';
import 'package:pele_dart/src/text/icons.dart';
import 'package:pele_dart/src/text/math.dart';
import 'package:pele_dart/src/text/measurer.dart';
import 'package:pele_dart/src/types.dart';
import 'package:test/test.dart';

const RenderOptions _cssOptions = RenderOptions(
  measurer: metricsMeasurer,
  outputMode: SvgOutputMode.cssVariables,
);

const RenderOptions _flatOptions = RenderOptions(
  measurer: metricsMeasurer,
  outputMode: SvgOutputMode.flattened,
);

(String, int) Function(int at) _inSource(String text) {
  List<List<Edit>>? steps;
  var source = '';
  return (int at) {
    if (steps == null) {
      steps = <List<Edit>>[];
      final pre = preprocess(text, steps);
      encodeEntities(cleanupComments(pre.withComments, steps), steps);
      source = '${normalizeLineBreaks(text)}\n';
    }
    return (source, inputOffset(steps!, at));
  };
}

SeqDb _parseSequenceModel(
  String text, [
  RenderOptions options = const RenderOptions(),
]) {
  final pre = preprocess(text);
  final config = options.config != null
      ? <String, dynamic>{...options.config!, ...pre.config}
      : pre.config;
  final parsed = '${encodeEntities(pre.text)}\n';
  return locatingIn<SeqDb>(
    Origin(parsed: parsed, find: _inSource(text)),
    () => sequence.parse(
      parsed,
      config,
      pre.title,
      pre.lineOffset,
      ParseLimits(maxEdges: options.maxEdges ?? 5000),
    ),
  );
}

RenderResult renderMermaid(
  String source, [
  RenderOptions options = const RenderOptions(),
]) {
  final pre = preprocess(source);
  final found = detectDiagram(pre.text)!;
  final config = options.config != null
      ? <String, dynamic>{...options.config!, ...pre.config}
      : pre.config;
  final model = _parseSequenceModel(source, options);
  final section = config['sequence'];
  final fixed = section is Map && section['useMaxWidth'] == false;
  final responsive = options.responsive ?? !fixed;
  final resolve = options.icons;
  final IconResolver? icons = resolve != null
      ? (String name) => resolve(decodeEntities(name))
      : null;
  final rendered = withPalette<Rendered>(
    palette(found.type, config),
    () => withMath<Rendered>(
      options.math,
      () => withIcons<Rendered>(
        icons,
        () => sequence.render(
          model,
          config,
          options.copyWith(responsive: responsive, icons: icons),
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

String _svgOf(
  String src, {
  Map<String, Object?>? config,
  double? maxWidth,
  List<String>? monospace,
  bool? responsive,
  SvgOutputMode outputMode = SvgOutputMode.cssVariables,
}) {
  return renderMermaid(
    src,
    RenderOptions(
      measurer: metricsMeasurer,
      config: config,
      maxWidth: maxWidth,
      monospace: monospace,
      responsive: responsive,
      outputMode: outputMode,
    ),
  ).svg;
}

SeqDb _model(String src) {
  final db = _parseSequenceModel(src);
  expect(db.type, 'sequence');
  return db;
}

int _count(String svg, String needle) => svg.split(needle).length - 1;

Map<String, double> _lifelines(String svg) {
  final out = <String, double>{};
  final re = RegExp(
    r'<path class="pele-lifeline" data-id="([^"]*)" d="M(-?[\d.]+),',
  );
  for (final m in re.allMatches(svg)) {
    out[m.group(1)!] = double.parse(m.group(2)!);
  }
  return out;
}

void main() {
  group('sequence diagram rendering', () {
    test('reports size, type, and renders in both cssVariables and flattened modes', () {
      const src = 'sequenceDiagram\n  Alice->>Bob: Hello';
      final cssResult = renderMermaid(src, _cssOptions);
      expect(cssResult.type, 'sequence');
      expect(cssResult.mermaidType, 'sequence');
      expect(cssResult.width, greaterThan(100));
      expect(cssResult.height, greaterThan(100));
      expect(cssResult.links, isEmpty);
      expect(
        cssResult.svg,
        contains(
          'viewBox="0 0 ${cssResult.width.toInt()} ${cssResult.height.toInt()}"',
        ),
      );
      expect(
        cssResult.svg,
        startsWith(
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele pele-sequence"',
        ),
      );
      expect(cssResult.svg, contains('var(--_fg)'));

      final flatResult = renderMermaid(src, _flatOptions);
      expect(flatResult.type, 'sequence');
      expect(flatResult.width, cssResult.width);
      expect(flatResult.height, cssResult.height);
      expect(flatResult.svg, isNot(contains('var(--')));
      expect(flatResult.svg, isNot(contains('color-mix(')));
      expect(flatResult.svg, contains('fill="#1f1f1f"'));
    });

    test('is detected and parsed to a sequence model', () {
      expect(
        detectDiagram(preprocess('sequenceDiagram\n A->>B: hi').text)?.type,
        'sequence',
      );
      final m = _model('sequenceDiagram\n participant A as Alice\n A->>B: hi');
      expect(m.actors.keys.toList(), <String>['A', 'B']);
      expect(m.actors['A']?.description, 'Alice');
      expect(m.messages.length, 1);
      expect(m.messages[0].from, 'A');
      expect(m.messages[0].to, 'B');
      expect(m.messages[0].message, 'hi');
      expect(m.messages[0].type, LINETYPE.SOLID);
    });

    test('renders an empty diagram and a lone participant', () {
      expect(
        renderMermaid('sequenceDiagram', _cssOptions).width,
        greaterThan(0),
      );
      final svg = _svgOf('sequenceDiagram\n participant Solo');
      expect(_count(svg, 'class="pele-node pele-actor'), 2);
    });

    test(
      'themes through custom properties with fallbacks and no style element',
      () {
        final svg = _svgOf(
          'sequenceDiagram\n  Alice->>+Bob: Hi\n  Note over Alice: n\n  Bob-->>-Alice: Yo',
        );
        for (final token in const <String>[
          '--pele-bg',
          '--pele-fg',
          '--pele-line',
          '--pele-surface',
          '--pele-border',
          '--pele-font',
        ]) {
          expect(svg, contains('var($token,'));
        }
        expect(svg, isNot(contains('<style')));
        expect(svg, isNot(contains('<marker')));
        expect(svg, isNot(contains('<defs')));
      },
    );

    test('mirrors participants at the bottom unless told not to', () {
      const src = 'sequenceDiagram\n  Alice->>Bob: Hi';
      final mirrored = renderMermaid(src, _cssOptions);
      final single = renderMermaid(
        src,
        RenderOptions(
          measurer: metricsMeasurer,
          outputMode: SvgOutputMode.cssVariables,
          config: <String, Object?>{
            'sequence': <String, Object?>{'mirrorActors': false},
          },
        ),
      );
      expect(_count(mirrored.svg, 'class="pele-node pele-actor'), 4);
      expect(_count(mirrored.svg, 'pele-actor-footer'), 2);
      expect(_count(single.svg, 'class="pele-node pele-actor'), 2);
      expect(single.height, lessThan(mirrored.height));
      final directive = _svgOf(
        '%%{init: {"sequence": {"mirrorActors": false}}}%%\n$src',
      );
      expect(_count(directive, 'pele-actor-footer'), 0);
    });

    test(
      'keeps participants in order of appearance and spaces them by their text',
      () {
        final short = _lifelines(
          _svgOf('sequenceDiagram\n  A->>B: hi\n  B->>C: hi'),
        );
        final long = _lifelines(
          _svgOf(
            'sequenceDiagram\n  A->>B: a considerably longer message than before\n  B->>C: hi',
          ),
        );
        expect(short.keys.toList(), <String>['A', 'B', 'C']);
        expect(short['A']!, lessThan(short['B']!));
        expect(short['B']!, lessThan(short['C']!));
        expect(
          long['B']! - long['A']!,
          greaterThan(short['B']! - short['A']! + 100),
        );
        expect(
          long['C']! - long['B']!,
          closeTo(short['C']! - short['B']!, 0.05),
        );
      },
    );

    test('shares the width a long message needs among the gaps it crosses', () {
      final x = _lifelines(
        _svgOf(
          'sequenceDiagram\n  participant A\n  participant B\n  participant C\n  A->>C: a message that is far too long for two default gaps to hold',
        ),
      );
      expect(x['B']! - x['A']!, closeTo(x['C']! - x['B']!, 0.05));
      expect(x['C']! - x['A']!, greaterThan(360));
    });

    test('widens a participant to its label and honors actorMargin', () {
      final tight = _lifelines(
        _svgOf('sequenceDiagram\n  participant A\n  participant B'),
      );
      final wide = _lifelines(
        _svgOf(
          'sequenceDiagram\n  participant A\n  participant B',
          config: <String, Object?>{
            'sequence': <String, Object?>{'actorMargin': 200},
          },
        ),
      );
      expect(wide['B']! - wide['A']!, tight['B']! - tight['A']! + 160);
      final labelled = _lifelines(
        _svgOf(
          'sequenceDiagram\n  participant A as A participant with a long description\n  participant B',
        ),
      );
      expect(
        labelled['B']! - labelled['A']!,
        greaterThan(tight['B']! - tight['A']! + 80),
      );
    });

    test('draws each arrow type with its line and heads', () {
      String one(String arrow) {
        final svg = _svgOf('sequenceDiagram\n  A${arrow}B: x');
        return RegExp(r'<g class="pele-edge pele-message"[^>]*>(.*?)</g>')
            .firstMatch(svg)!
            .group(1)!;
      }

      expect(one('->'), isNot(contains('pele-marker')));
      expect(one('->'), isNot(contains('stroke-dasharray')));
      expect(one('-->'), contains('stroke-dasharray'));
      expect(_count(one('->>'), 'pele-marker'), 1);
      expect(one('-->>'), contains('stroke-dasharray'));
      expect(_count(one('<<->>'), 'pele-marker'), 2);
      expect(_count(one('<<-->>'), 'pele-marker'), 2);
      expect(one('-x'), matches(RegExp(r'pele-marker" d="M[^"]*M')));
      expect(one('-)'), contains('stroke-linejoin="round"'));
      expect(one('-)'), isNot(contains('fill="var(--_l)"')));
      for (final half in const <String>[
        r'-|\',
        '-|/',
        r'-\\',
        '-//',
        '/|-',
        r'\|-',
        '//-',
        r'\\-',
      ]) {
        expect(_count(one(half), 'pele-marker'), 1, reason: half);
        expect(
          one(half.replaceFirst('-', '--')),
          contains('stroke-dasharray'),
          reason: half,
        );
      }
    });

    test('puts a half head above or below the line as its name says', () {
      List<double> head(String arrow) {
        final svg = _svgOf('sequenceDiagram\n  A${arrow}B: x');
        final d = RegExp(r'pele-marker" d="([^"]*)"')
            .firstMatch(svg)!
            .group(1)!;
        return RegExp(r',(-?[\d.]+)')
            .allMatches(d)
            .map((m) => double.parse(m.group(1)!))
            .toList();
      }

      final top = head(r'-|\');
      final bottom = head('-|/');
      expect(top.reduce((a, b) => a < b ? a : b), lessThan(top[0]));
      expect(top.reduce((a, b) => a > b ? a : b), top[0]);
      expect(bottom.reduce((a, b) => a > b ? a : b), greaterThan(bottom[0]));
      expect(bottom.reduce((a, b) => a < b ? a : b), bottom[0]);
    });

    test('loops a message to self back to its own lifeline', () {
      final svg = _svgOf('sequenceDiagram\n  A->>A: think\n  A->>B: tell');
      final x = _lifelines(svg);
      final d = RegExp(r'data-id="i0"><path d="([^"]*)"')
          .firstMatch(svg)!
          .group(1)!;
      expect(d, matches(RegExp(r'^M[\d.]+,[\d.]+H[\d.]+A6,6')));
      final mx = double.parse(RegExp(r'^M([\d.]+)').firstMatch(d)!.group(1)!);
      expect(mx, x['A']);
      final square = _svgOf(
        'sequenceDiagram\n  A->>A: think',
        config: <String, Object?>{
          'sequence': <String, Object?>{'rightAngles': true},
        },
      );
      final sqD = RegExp(r'data-id="i0"><path d="([^"]*)"')
          .firstMatch(square)!
          .group(1)!;
      expect(sqD, isNot(contains('A6,6')));
    });

    test('widens gaps within maxWidth before wrapping a message', () {
      int lines(String svg, String id) {
        final g = RegExp('<g class="pele-edge-label" data-id="$id">(.*?)</g>')
            .firstMatch(svg)!
            .group(1)!;
        final matches = RegExp(r'<tspan').allMatches(g).length;
        return matches == 0 ? 1 : matches;
      }

      const reported =
          'sequenceDiagram\n  participant U as UE\n  participant M as MeNB (LTE anchor)\n  participant S as SgNB (5G, NR leg)\n'
          '  M->>S: SgNB Addition Request (DRB-ID, CG-ConfigInfo)\n  M->>U: RRCConnectionReconfiguration (carries the NR SCG config)\n  U->>M: RRCConnectionReconfigurationComplete';
      const long =
          'thisIsAnExtremelyLongMessageIdentifierThatShouldHaveRoomToFit';
      final cases = <(String, String, double, int, List<String>?)>[
        (reported, 'i2', 760, 1, null),
        (reported, 'i2', 760.5, 1, null),
        (reported, 'i2', 760, 1, <String>['messages']),
        (reported, 'i2', 400, 2, null),
        (
          'sequenceDiagram\n  participant A\n  participant B\n  participant C\n  B->>A: ${'x' * 168}\n  C->>A: ${'x' * 89}',
          'i1',
          709,
          1,
          null,
        ),
        ('sequenceDiagram\n  A->>B: $long', 'i0', 300.25, 3, null),
        (
          'sequenceDiagram\n  participant A\n  participant B\n  participant C\n  participant D\n  A->>D: $long',
          'i0',
          450,
          2,
          null,
        ),
        (
          'sequenceDiagram\n  A->>+B: $long\n  Note right of B: note\n  B-->>-A: ok',
          'i0',
          400,
          2,
          null,
        ),
      ];
      for (final (source, id, maxWidth, count, mono) in cases) {
        final result = renderMermaid(
          source,
          RenderOptions(
            measurer: metricsMeasurer,
            outputMode: SvgOutputMode.cssVariables,
            maxWidth: maxWidth,
            monospace: mono,
          ),
        );
        expect(result.width, lessThanOrEqualTo(maxWidth));
        expect(lines(result.svg, id), count);
      }
    });

    test(
      'draws activations, nested ones offset, and ends arrows at their edges',
      () {
        final svg = _svgOf(
          'sequenceDiagram\n  A->>+B: one\n  A->>+B: two\n  B-->>-A: three\n  B-->>-A: four',
        );
        final x = _lifelines(svg);
        final rects = RegExp(
          r'<rect class="pele-activation" data-id="B" x="(-?[\d.]+)" y="(-?[\d.]+)" width="10" height="([\d.]+)"',
        ).allMatches(svg).toList();
        expect(rects.length, 2);
        final xs = rects.map((r) => double.parse(r.group(1)!)).toList()..sort();
        expect(xs[0], x['B']! - 5);
        expect(xs[1], x['B']! - 1);
        final outer = rects.firstWhere(
          (r) => double.parse(r.group(1)!) == xs[0],
        );
        final inner = rects.firstWhere(
          (r) => double.parse(r.group(1)!) == xs[1],
        );
        expect(
          double.parse(outer.group(3)!),
          greaterThan(double.parse(inner.group(3)!)),
        );
        expect(
          svg.indexOf(outer.group(0)!),
          lessThan(svg.indexOf(inner.group(0)!)),
        );
        final first = RegExp(r'data-id="i0"><path d="M[\d.]+,[\d.]+H([\d.]+)"')
            .firstMatch(svg)!
            .group(1)!;
        expect(double.parse(first), x['B']! - 5 - 7);
      },
    );

    test('accepts explicit activate and deactivate, and rejects deactivating inactive participant', () {
      final closed = _svgOf(
        'sequenceDiagram\n  A->>B: go\n  activate B\n  B-->>A: done\n  deactivate B',
      );
      expect(_count(closed, 'pele-activation"'), 1);
      final open = _svgOf('sequenceDiagram\n  activate A\n  A->>B: go');
      expect(_count(open, 'pele-activation"'), 1);

      expect(
        () => renderMermaid(
          'sequenceDiagram\n  A->>B: go\n  deactivate B',
          _cssOptions,
        ),
        throwsA(
          isA<PeleError>().having(
            (e) => e.message,
            'message',
            contains('inactivate an inactive participant (B)'),
          ),
        ),
      );
      expect(
        () => renderMermaid('sequenceDiagram\n  A->>-B: go', _cssOptions),
        throwsA(isA<PeleError>()),
      );
    });

    test('places notes left of, right of, and over participants', () {
      final svg = _svgOf(
        'sequenceDiagram\n  participant A\n  participant B\n  Note left of A: L\n  Note right of B: R\n  Note over A: O\n  Note over A,B: AB',
      );
      final x = _lifelines(svg);
      final notes =
          RegExp(
                r'<g class="pele-note" data-id="i(\d+)"><rect x="(-?[\d.]+)" y="(-?[\d.]+)" width="([\d.]+)"',
              )
              .allMatches(svg)
              .map(
                (m) => (
                  left: double.parse(m.group(2)!),
                  right: double.parse(m.group(2)!) + double.parse(m.group(4)!),
                  top: double.parse(m.group(3)!),
                ),
              )
              .toList();
      expect(notes.length, 4);
      expect(notes[0].right, lessThan(x['A']!));
      expect(notes[1].left, greaterThan(x['B']!));
      expect((notes[2].left + notes[2].right) / 2, closeTo(x['A']!, 0.05));
      expect(notes[3].left, lessThan(x['A']!));
      expect(notes[3].right, greaterThan(x['B']!));
      for (var i = 1; i < notes.length; i++) {
        expect(notes[i].top, greaterThan(notes[i - 1].top));
      }
      final m = _model(
        'sequenceDiagram\n  Note over A,B: AB\n  Note left of A: L',
      );
      expect(m.notes.map((n) => n.placement).toList(), <int>[
        PLACEMENT.OVER,
        PLACEMENT.LEFTOF,
      ]);
      expect(m.notes[0].actor, <String>['A', 'B']);
    });

    test('frames loop, alt, opt, par, critical, and break blocks with their titles and sections', () {
      const src =
          'sequenceDiagram\n  loop Every minute\n  A->>B: a\n  end\n  alt ok\n  A->>B: b\n  else bad\n  A->>B: c\n  else\n  A->>B: d\n  end\n'
          '  opt maybe\n  A->>B: e\n  end\n  par one\n  A->>B: f\n  and two\n  A->>B: g\n  end\n  par_over three\n  A->>B: h\n  end\n'
          '  critical must\n  A->>B: i\n  option fail\n  A->>B: j\n  end\n  break stop\n  A->>B: k\n  end';
      final svg = _svgOf(src);
      for (final kind in const <String>[
        'loop',
        'alt',
        'opt',
        'par',
        'critical',
        'break',
      ]) {
        expect(svg, contains('class="pele-frame pele-frame-$kind"'));
        expect(svg, contains('>$kind</text>'));
      }
      expect(_count(svg, 'class="pele-frame pele-frame-par"'), 2);
      for (final title in const <String>[
        '[Every minute]',
        '[ok]',
        '[bad]',
        '[maybe]',
        '[one]',
        '[two]',
        '[three]',
        '[must]',
        '[fail]',
        '[stop]',
      ]) {
        expect(svg, contains('>$title</text>'));
      }
      final alt = RegExp(r'<g class="pele-frame pele-frame-alt">(.*?)</g>')
          .firstMatch(svg)!
          .group(1)!;
      expect(_count(alt, 'stroke-dasharray'), 2);

      // Verify flattened mode also renders all blocks cleanly without CSS variables.
      final flatSvg = _svgOf(src, outputMode: SvgOutputMode.flattened);
      expect(flatSvg, isNot(contains('var(--')));
      for (final kind in const <String>[
        'loop',
        'alt',
        'opt',
        'par',
        'critical',
        'break',
      ]) {
        expect(flatSvg, contains('class="pele-frame pele-frame-$kind"'));
      }
    });

    test('shades rect blocks with the given color and picks contrasting text color on rect or box fill', () {
      final svg = _svgOf(
        'sequenceDiagram\n  box rgb(34, 56, 0) Group\n  participant A\n  participant B\n  end\n  participant C\n  participant D\n'
        '  A->>B: boxed\n  C->>D: open\n  rect rgb(191, 223, 255)\n  C->>D: light\n  C->>C: self\n  loop Often\n  D->>C: looped\n  end\n  rect black\n  C->>D: dark\n  end\n  rect rgba(0, 0, 0, .2)\n  C->>D: faint\n  end\n  A->>D: crossing two of the lifelines\n  end',
      );
      String label(String text) =>
          RegExp('<text[^>]*>(?:\\[)?$text(?:\\])?</text>')
              .firstMatch(svg)!
              .group(0)!;
      const light = 'fill="var(--pele-fg-on-light,#1f1f1f)"';
      const dark = 'fill="var(--pele-fg-on-dark,#fff)"';
      expect(label('boxed'), contains(dark));
      expect(svg, contains('<text class="pele-cluster-label" $dark'));
      expect(label('open'), isNot(contains('fill=')));
      expect(label('light'), contains(light));
      expect(label('self'), contains(light));
      expect(
        label('Often'),
        contains('class="pele-frame-label" $light stroke="none"'),
      );
      expect(label('looped'), contains(light));
      expect(label('dark'), contains(dark));
      expect(label('faint'), isNot(contains('fill=')));
      expect(
        svg,
        matches(
          RegExp(
            r'fill="var\(--_bg\)" stroke="none"/><text x=[^>]*>crossing two of the lifelines<',
          ),
        ),
      );
    });

    test('groups participants in boxes, with color and title, and rejects duplicate box definitions', () {
      const src =
          'sequenceDiagram\n  box Aqua Group One\n  participant A\n  participant B\n  end\n  box Group Two\n  participant C\n  end\n  box rgb(1, 2, 3)\n  participant D\n  end\n  A->>D: x';
      final m = _model(src);
      expect(
        m.boxes.map((b) => <Object?>[b.name, b.fill, b.actorKeys]).toList(),
        <List<Object?>>[
          <Object?>[
            'Group One',
            'Aqua',
            <String>['A', 'B'],
          ],
          <Object?>[
            'Group Two',
            'transparent',
            <String>['C'],
          ],
          <Object?>[
            null,
            'rgb(1, 2, 3)',
            <String>['D'],
          ],
        ],
      );
      final svg = _svgOf(src);
      expect(_count(svg, 'class="pele-cluster pele-box"'), 3);
      expect(svg, contains('style="rx:var(--_r);fill:Aqua;"'));
      expect(svg, contains('>Group One</text>'));
      expect(svg, contains('>Group Two</text>'));

      expect(
        () => renderMermaid(
          'sequenceDiagram\n  box One\n  participant A\n  end\n  box Two\n  participant A\n  end',
          _cssOptions,
        ),
        throwsA(
          isA<PeleError>().having(
            (e) => e.message,
            'message',
            contains('should only be defined in one Box'),
          ),
        ),
      );
    });

    test('numbers messages with autonumber, its start and step, and the config switch', () {
      List<String> numbers(String svg) => RegExp(
        r'<g class="pele-sequence-number">.*?<text[^>]*>([^<]*)</text>',
      ).allMatches(svg).map((m) => m.group(1)!).toList();

      const src =
          'sequenceDiagram\n  A->>B: one\n  B-->>A: two\n  A->>A: three';
      expect(numbers(_svgOf(src)), isEmpty);
      expect(
        numbers(_svgOf(src.replaceFirst('\n', '\n  autonumber\n'))),
        <String>['1', '2', '3'],
      );
      expect(
        numbers(_svgOf(src.replaceFirst('\n', '\n  autonumber 10 5\n'))),
        <String>['10', '15', '20'],
      );
      expect(
        numbers(_svgOf(src.replaceFirst('\n', '\n  autonumber 10.01 .01\n'))),
        <String>['10.01', '10.02', '10.03'],
      );
      expect(
        numbers(
          _svgOf(
            src,
            config: <String, Object?>{
              'sequence': <String, Object?>{'showSequenceNumbers': true},
            },
          ),
        ),
        <String>['1', '2', '3'],
      );
      expect(
        numbers(
          _svgOf(
            'sequenceDiagram\n  autonumber\n  A->>B: one\n  autonumber off\n  B-->>A: two\n  autonumber\n  A->>B: three',
          ),
        ),
        <String>['1', '3'],
      );
      expect(
        () => renderMermaid(
          'sequenceDiagram\n  autonumber 10.001\n  A->>B: one',
          _cssOptions,
        ),
        throwsA(isA<PeleError>()),
      );
    });

    test('draws each participant kind, with figures above their labels', () {
      const kinds = <String>[
        'actor',
        'boundary',
        'control',
        'entity',
        'database',
        'collections',
        'queue',
      ];
      final buf = StringBuffer('sequenceDiagram\n  participant P\n  actor A\n');
      for (final kind in kinds.sublist(1)) {
        buf.writeln('  participant $kind@{ "type": "$kind" }');
      }
      final src = buf.toString();
      final m = _model(src);
      expect(m.actors.values.map((a) => a.type).toList(), <String>[
        'participant',
        ...kinds,
      ]);
      final svg = _svgOf(
        src,
        config: <String, Object?>{
          'sequence': <String, Object?>{'mirrorActors': false},
        },
      );
      for (final kind in <String>['participant', ...kinds]) {
        expect(_count(svg, 'pele-actor-$kind"'), 1, reason: kind);
      }
      expect(
        _svgOf('sequenceDiagram\n  participant X@{ "type": "nonsense" }'),
        contains('pele-actor-participant"'),
      );
    });

    test('creates a participant at its first message, destroys with cross, and supports central connections', () {
      const src =
          'sequenceDiagram\n  A->>B: hi\n  create participant C\n  A->>C: make\n  destroy C\n  A-xC: end\n  B->>A: bye';
      final m = _model(src);
      expect(m.createdActors['C'], 1);
      expect(m.destroyedActors['C'], 2);
      final svg = _svgOf(src);
      expect(_count(svg, 'class="pele-destroy" data-id="C"'), 1);
      expect(_count(svg, 'pele-actor-footer" data-id="C"'), 0);
      expect(_count(svg, 'pele-actor-footer" data-id="A"'), 1);

      final ccSvg = _svgOf(
        'sequenceDiagram\n  A->>()B: to\n  A()->>B: from\n  A()->>()B: both',
      );
      final circles = RegExp(r'data-id="i(\d+)">(.*?)</g>')
          .allMatches(ccSvg)
          .where((m) => m.group(2)!.contains('pele-central'))
          .map((m) => (m.group(1)!, _count(m.group(2)!, 'pele-central')))
          .toList();
      expect(circles, <(String, int)>[('0', 1), ('2', 1), ('4', 2)]);
    });

    test('stores participant links, properties, details, titles, and accessibility fields', () {
      const src =
          'sequenceDiagram\n  title My Sequence\n  accTitle: Accessible Seq\n  accDescr {\n    Multi\n    line\n  }\n'
          '  participant A\n  participant B\n  links A: {"Repo": "https://example.com/repo"}\n'
          '  link A: Tests @ https://example.com/?a=1\n  properties B: {"class": "external svc"}\n  details B: some-element\n  A->>B: hi';
      final m = _model(src);
      expect(m.title, 'My Sequence');
      expect(m.accTitle, 'Accessible Seq');
      expect(m.accDescr, 'Multi\nline');
      expect(m.actors['A']!.links, <String, Object?>{
        'Repo': 'https://example.com/repo',
        'Tests': 'https://example.com/?a=1',
      });
      expect(m.actors['B']!.properties, <String, Object?>{
        'class': 'external svc',
      });
      expect(m.actors['B']!.details, 'some-element');

      final svg = _svgOf(src);
      expect(svg, contains('<title id="pele-title">Accessible Seq</title>'));
      expect(svg, contains('<desc id="pele-desc">Multi\nline</desc>'));
      expect(svg, contains('pele-actor-participant external svc" data-id="B"'));
    });

    test('throws structured syntax errors', () {
      PeleError? error;
      try {
        renderMermaid('sequenceDiagram\n  Alice->>Bob\n', _cssOptions);
      } on PeleError catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      expect(error!.code, 'syntax');
      expect(error.line, 2);
      expect(error.message, contains("Expecting 'TXT', got 'NEWLINE'"));
      expect(
        () => renderMermaid('sequenceDiagram\n  participant\n', _cssOptions),
        throwsA(
          isA<PeleError>().having(
            (e) => e.message,
            'message',
            contains('Lexical error on line 2'),
          ),
        ),
      );
      expect(
        () =>
            renderMermaid('sequenceDiagram\n  loop x\n  A->>B: y', _cssOptions),
        throwsA(isA<PeleError>()),
      );
    });
  });
}
