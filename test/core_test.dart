import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/detect.dart';
import 'package:pele_dart/src/diagrams/info/render.dart';
import 'package:pele_dart/src/layout/compound.dart';
import 'package:pele_dart/src/layout/layered.dart';
import 'package:pele_dart/src/preprocess.dart';
import 'package:pele_dart/src/text/entities.dart';
import 'package:pele_dart/src/text/label.dart';
import 'package:pele_dart/src/util/yaml.dart';
import 'package:test/test.dart';

void main() {
  group('Phase 1 Core Foundation', () {
    test('detectDiagram detects all 33 diagram families', () {
      expect(detectDiagram('flowchart TD\n A-->B')?.type, 'flowchart');
      expect(detectDiagram('graph LR\n A-->B')?.type, 'flowchart');
      expect(detectDiagram('sequenceDiagram\n A->>B: hi')?.type, 'sequence');
      expect(detectDiagram('classDiagram\n class A')?.type, 'class');
      expect(
        detectDiagram('classDiagram\n class A')?.mermaidType,
        'classDiagram',
      );
      expect(detectDiagram('stateDiagram-v2\n [*]-->A')?.type, 'state');
      expect(detectDiagram('erDiagram\n A ||--o{ B : has')?.type, 'er');
      expect(detectDiagram('gantt\n title T')?.type, 'gantt');
      expect(detectDiagram('pie\n "A": 1')?.type, 'pie');
      expect(detectDiagram('gitGraph\n commit')?.type, 'gitGraph');
      expect(detectDiagram('mindmap\n root')?.type, 'mindmap');
      expect(detectDiagram('info')?.type, 'info');
      expect(detectDiagram('kanban\n Todo')?.type, 'kanban');
      expect(detectDiagram('timeline\n title T')?.type, 'timeline');
      expect(detectDiagram('journey\n title T')?.type, 'journey');
      expect(detectDiagram('quadrantChart\n title T')?.type, 'quadrantChart');
      expect(detectDiagram('xychart-beta\n line [1, 2]')?.type, 'xychart');
      expect(detectDiagram('architecture-beta')?.type, 'architecture');
      expect(detectDiagram('requirementDiagram')?.type, 'requirement');
      expect(detectDiagram('sankey-beta')?.type, 'sankey');
      expect(detectDiagram('packet-beta')?.type, 'packet');
      expect(detectDiagram('radar-beta')?.type, 'radar');
      expect(detectDiagram('treemap-beta')?.type, 'treemap');
      expect(detectDiagram('C4Context')?.type, 'c4');
      expect(detectDiagram('block-beta')?.type, 'block');
      expect(detectDiagram('railroad-beta')?.type, 'railroad');
      expect(detectDiagram('agentflow-beta')?.type, 'agentflow');
      expect(detectDiagram('treeView-beta')?.type, 'treeView');
      expect(detectDiagram('cynefin-beta')?.type, 'cynefin');
      expect(detectDiagram('wardley-beta')?.type, 'wardley');
      expect(detectDiagram('eventmodeling')?.type, 'eventmodeling');
      expect(detectDiagram('usecase-beta')?.type, 'usecase');
      expect(detectDiagram('venn-beta')?.type, 'venn');
      expect(detectDiagram('ishikawa-beta')?.type, 'ishikawa');
      expect(detectDiagram('swimlane-beta')?.type, 'swimlane');
    });

    test('preprocess extracts YAML frontmatter, directives, and comments', () {
      const src = '''---
title: Frontmatter Title
config:
  flowchart:
    curve: linear
---
%%{init: {"flowchart": {"nodeSpacing": 40}}}%%
flowchart TD
  %% A comment
  A --> B''';
      final pre = preprocess(src);
      expect(pre.title, 'Frontmatter Title');
      expect((pre.config['flowchart'] as Map)['nodeSpacing'], 40);
      expect(pre.text.contains('%% A comment'), isFalse);
    });

    test('parseYaml handles nested mappings and lists', () {
      final doc = parseYaml('title: Hello\nitems:\n  - one\n  - two\n') as Map;
      expect(doc['title'], 'Hello');
      expect(doc['items'], <dynamic>['one', 'two']);
    });

    test('encodeEntities and decodeEntities round-trip', () {
      final encoded = encodeEntities('Hello &amp; #35; world');
      final decoded = decodeEntities(encoded);
      expect(decoded, 'Hello & # world');
    });

    test('TextMeasurer and layoutLabel measure and wrap text', () {
      final label = layoutLabel(
        'Hello <b>bold</b><br/>second line',
        false,
        metricsMeasurer,
        14,
        400,
      );
      expect(label.lines.length, 2);
      expect(label.width, greaterThan(50));
      expect(label.height, greaterThan(20));
    });

    test('layered and compoundLayout position nodes and edges', () {
      final nodes = <CNode>[cnode(80, 40), cnode(80, 40)];
      final edges = <CEdge>[CEdge(src: 0, dst: 1)];
      final res = compoundLayout(
        nodes,
        edges,
        'TB',
        const LayeredOptions(
          nodeSep: 30,
          edgeSep: 15,
          rankSep: 40,
          portSep: 16,
        ),
      );
      expect(res.width, greaterThanOrEqualTo(80));
      expect(res.height, greaterThanOrEqualTo(120));
      expect(nodes[0].y, lessThan(nodes[1].y));
      expect(edges[0].route.length, greaterThanOrEqualTo(6));
    });

    test('info diagram renders in both cssVariables and flattened modes', () {
      const src =
          'info\n  title Info Diagram\n  accTitle: Accessible Info\n  accDescr: Description here';
      final cssRes = render(
        src,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssRes.type, 'info');
      expect(cssRes.svg, contains('var(--_fg)'));
      expect(cssRes.svg, contains('Pele v$peleVersion'));
      expect(
        cssRes.svg,
        contains('<title id="pele-title">Accessible Info</title>'),
      );

      final flatRes = render(
        src,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatRes.svg, isNot(contains('var(--')));
      expect(flatRes.svg, isNot(contains('color-mix(')));
      expect(flatRes.svg, contains('fill="#1f1f1f"'));
      expect(flatRes.svg, contains('Pele v$peleVersion'));
    });

    test('flattenPeleSvg resolves color-mix, var, rx style, font weights, and baseline-shift', () {
      const rawSvg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele pele-test" style="--_bg:#fff;" fill="var(--_fg)">'
          '<rect x="0" y="0" width="10" height="10" style="rx:var(--_r);fill:color-mix(in srgb,var(--_fg) 20%,var(--_bg));stroke:var(--_b);"/>'
          '<text font-weight="var(--_tw)"><tspan font-weight="var(--_w)" baseline-shift="sub" font-size="smaller">2</tspan></text>'
          '</svg>';
      final flat = flattenPeleSvg(rawSvg);
      expect(flat, isNot(contains('var(--')));
      expect(flat, isNot(contains('color-mix(')));
      expect(flat, isNot(contains('baseline-shift=')));
      expect(flat, contains('rx="4"'));
      expect(flat, contains('font-weight="bold"'));
      expect(flat, contains('dy="3" font-size="10"'));
    });

    test('layered layout handles repeated mixed class namespace and ER renders across GC cycles', () {
      const classSrc = '''classDiagram
  namespace Earth {
    class Volcano {
      +erupt()
    }
    class Summit
  }
  namespace Reef {
    class Coral
    class Trench
  }
  Volcano --> Summit
  Summit ..> Coral : ash
  Coral --> Trench : sediment''';
      const erSrc = '''erDiagram
  direction LR
  CUSTOMER ||--o{ ORDER : places
  CUSTOMER {
    string name
    string custNumber
  }
  ORDER ||--|{ LINE-ITEM : contains
  ORDER {
    int orderNumber
  }''';
      for (var i = 0; i < 64; i++) {
        final cRes = render(classSrc);
        final eRes = render(erSrc);
        expect(cRes.svg, contains('pele-class'));
        expect(eRes.svg, contains('pele-er'));
      }
    });

    test('flattenPeleSvg propagates group fill-opacity to radar curves and resolves cScale0..2', () {
      const radarSrc = '''---
config:
  radar:
    axisScaleFactor: 0.25
    curveTension: 0.1
  theme: base
  themeVariables:
    cScale0: "#FF0000"
    cScale1: "#00FF00"
    cScale2: "#0000FF"
    radar:
      curveOpacity: 0
---
radar-beta
  axis A, B, C, D, E
  curve c1{1,2,3,4,5}
  curve c2{5,4,3,2,1}
  curve c3{3,3,3,3,3}''';
      final cssRes = render(
        radarSrc,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(
        cssRes.svg,
        contains(
          '<g class="pele-curves" fill-opacity="0.2" stroke-width="1.5" stroke-linejoin="round">',
        ),
      );

      final flatRes = render(
        radarSrc,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(
        flatRes.svg,
        contains(
          '<g class="pele-curves" stroke-width="1.5" stroke-linejoin="round">',
        ),
      );
      expect(
        flatRes.svg,
        contains('data-id="c1" fill="#FF0000" stroke="#FF0000"'),
      );
      expect(
        flatRes.svg,
        contains('data-id="c2" fill="#00FF00" stroke="#00FF00"'),
      );
      expect(
        flatRes.svg,
        contains('data-id="c3" fill="#0000FF" stroke="#0000FF"'),
      );
      expect(
        RegExp(r'class="pele-curve"[^>]*fill-opacity="0\.2"')
            .allMatches(flatRes.svg)
            .length,
        3,
      );
    });

    test('flattenPeleSvg extracts root font-size, resolves concrete font-family, and propagates group font-size to Sankey labels', () {
      const sankeySrc = '''---
config:
  sankey:
    showValues: false
    labelStyle: outlined
---
sankey
Agricultural 'waste',Bio-conversion,124.729
Bio-conversion,Liquid,0.597''';
      final flatRes = render(
        sankeySrc,
        const RenderOptions(
          outputMode: SvgOutputMode.flattened,
          idPrefix: 'p1',
        ),
      );
      expect(flatRes.svg, contains('font-family="Helvetica" font-size="16"'));
      expect(
        flatRes.svg,
        contains(
          'stroke-linejoin="round" font-size="14">Agricultural \'waste\'</text>',
        ),
      );
      expect(
        flatRes.svg,
        contains(
          'text-anchor="start" font-size="14">Agricultural \'waste\'</text>',
        ),
      );
      expect(flatRes.svg, contains('fill="url(#p1-sankey-'));
      expect(flatRes.svg, isNot(contains(') #')));
    });

    test(
      'flattenPeleSvg converts nested pele-icon SVGs into scaled g groups',
      () {
        const archSrc = '''architecture-beta
  group api(cloud)[API]
  service db(database)[Database] in api''';
        final flatRes = render(
          archSrc,
          const RenderOptions(outputMode: SvgOutputMode.flattened),
        );
        expect(flatRes.svg, isNot(contains('<svg class="pele-icon"')));
        expect(flatRes.svg, contains('<g class="pele-icon"'));
      },
    );

    test('flattenPeleSvg promotes first tspan x and y onto parent text for multi-span labels', () {
      const mindmapSrc = '''mindmap
  id1["`**Pele** is the
goddess of volcanoes
Unicode works too: 🌋`"]
    id2["`She lives in **the** crater of Kīlauea... a *very old story* that is still told today`"]
    id3[Lava builds new land]''';
      final cssRes = render(
        mindmapSrc,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(
        cssRes.svg,
        contains(
          '<text class="pele-label" text-anchor="middle" xml:space="preserve"><tspan x="0" y="-15.4" font-weight="var(--_w)">Pele</tspan><tspan> is the</tspan>',
        ),
      );

      final flatRes = render(
        mindmapSrc,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(
        flatRes.svg,
        contains(
          '<text class="pele-label" text-anchor="middle" xml:space="preserve" x="0" y="-15.4"><tspan x="0" y="-15.4" font-weight="bold">Pele</tspan><tspan> is the</tspan>',
        ),
      );
    });

    test('flattenPeleSvg converts positioned subscript and superscript tspan dy into explicit x and y coordinates', () {
      const rawSvg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele pele-test" style="--_bg:#fff;font:16px sans-serif" fill="var(--_fg)">'
          '<g transform="translate(8, 8)">'
          '<text text-anchor="middle" xml:space="preserve">'
          '<tspan x="100" y="50">H</tspan>'
          '<tspan baseline-shift="sub" font-size="smaller">2</tspan>'
          '<tspan>O</tspan>'
          '</text>'
          '</g>'
          '</svg>';
      final flat = flattenPeleSvg(rawSvg);
      expect(flat, isNot(contains('dy="3"')));
      expect(flat, contains('<text x="100" y="50"'));
      expect(flat, contains('text-anchor="start"'));
      expect(flat, contains('y="50">H</tspan>'));
      expect(flat, contains('y="53" font-size="10">2</tspan>'));
      expect(flat, contains('y="50">O</tspan>'));
    });
  });
}
