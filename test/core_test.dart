import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/detect.dart';
import 'package:pele_dart/src/layout/compound.dart';
import 'package:pele_dart/src/layout/layered.dart';
import 'package:pele_dart/src/preprocess.dart';
import 'package:pele_dart/src/text/entities.dart';
import 'package:pele_dart/src/text/label.dart';
import 'package:pele_dart/src/text/measurer.dart';
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
      expect(cssRes.svg, contains('Pele v1.13.0'));
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
      expect(flatRes.svg, contains('fill="#24292e"'));
      expect(flatRes.svg, contains('Pele v1.13.0'));
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
      expect(flat, contains('rx="6"'));
      expect(flat, contains('font-weight="bold"'));
      expect(flat, contains('dy="3" font-size="10"'));
    });
  });
}
