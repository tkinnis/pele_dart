import 'package:pele_dart/src/detect.dart';
import 'package:pele_dart/src/diagrams/git/db.dart';
import 'package:pele_dart/src/diagrams/git/index.dart';
import 'package:pele_dart/src/errors.dart';
import 'package:pele_dart/src/preprocess.dart';
import 'package:pele_dart/src/svg/flattener.dart';
import 'package:pele_dart/src/svg/palette.dart';
import 'package:pele_dart/src/text/entities.dart';
import 'package:pele_dart/src/text/icons.dart';
import 'package:pele_dart/src/text/math.dart';
import 'package:pele_dart/src/types.dart';
import 'package:test/test.dart';

GitModel parseGitDiagram(
  String source, [
  RenderOptions options = const RenderOptions(),
]) {
  final pre = preprocess(source);
  final parsed = '${encodeEntities(pre.text)}\n';
  return gitGraph.parse(
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
  final model = gitGraph.parse(
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
      gitGraph.math ? options.math : null,
      () => withIcons<Rendered>(
        icons,
        () => gitGraph.render(
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
  group('gitGraph diagram', () {
    test('renders basic commits, branches, merges, and cherry-picks in cssVariables and flattened modes', () {
      const src = '''
gitGraph
  title Release History
  accTitle: Git History
  accDescr: Shows main, develop, and feature branches
  commit id: "c1" msg: "Initial commit" tag: "v0.1.0"
  commit type: HIGHLIGHT
  branch develop order: 1
  checkout develop
  commit id: "d1" type: REVERSE
  branch feature
  commit id: "f1" msg: "Feature work"
  switch develop
  merge feature id: "m1" tag: "v0.2.0" type: NORMAL
  checkout main
  cherry-pick id: "f1"
  merge develop tag: "v1.0.0"
''';

      final cssRes = renderMermaid(
        src,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssRes.type, 'gitGraph');
      expect(cssRes.mermaidType, 'gitGraph');
      expect(cssRes.width, greaterThan(100));
      expect(cssRes.height, greaterThan(100));
      expect(cssRes.svg, contains('class="pele pele-gitGraph"'));
      expect(cssRes.svg, contains('var(--_fg)'));
      expect(cssRes.svg, contains('Release History'));
      expect(
        cssRes.svg,
        contains('<title id="pele-title">Git History</title>'),
      );
      expect(
        cssRes.svg,
        contains(
          '<desc id="pele-desc">Shows main, develop, and feature branches</desc>',
        ),
      );
      expect(cssRes.svg, contains('data-id="c1"'));
      expect(cssRes.svg, contains('data-id="1-3c6ef36"'));
      expect(cssRes.svg, contains('pele-commit-highlight'));
      expect(cssRes.svg, contains('pele-commit-reverse'));
      expect(cssRes.svg, contains('pele-commit-merge'));
      expect(cssRes.svg, contains('pele-commit-cherry-pick'));
      expect(cssRes.svg, contains('pele-edge-merge'));
      expect(cssRes.svg, contains('pele-edge-cherry-pick'));
      expect(cssRes.svg, contains('v0.1.0'));
      expect(cssRes.svg, contains('v1.0.0'));

      final flatRes = renderMermaid(
        src,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatRes.type, 'gitGraph');
      expect(flatRes.svg, isNot(contains('var(--')));
      expect(flatRes.svg, isNot(contains('color-mix(')));
      expect(flatRes.svg, contains('Release History'));
      expect(flatRes.svg, contains('data-id="c1"'));
    });

    test('supports TB and BT orientations and auto-direction turnToFit', () {
      const tbSrc = '''
gitGraph TB:
  commit id: "a"
  branch dev
  commit id: "b" tag: "beta"
  checkout main
  commit id: "c"
  merge dev
''';
      final tbRes = renderMermaid(tbSrc);
      expect(tbRes.svg, contains('data-id="a"'));
      expect(tbRes.svg, contains('data-id="b"'));

      const btSrc = '''
gitGraph BT:
  commit id: "a"
  branch dev
  commit id: "b" tag: "beta"
  checkout main
  merge dev
''';
      final btRes = renderMermaid(btSrc);
      expect(btRes.svg, contains('transform="rotate(45 '));

      const lrSrc = '''
gitGraph LR:
  commit id: "c1"
  commit id: "c2"
  commit id: "c3"
  commit id: "c4"
  commit id: "c5"
''';
      final turnedRes = renderMermaid(
        lrSrc,
        const RenderOptions(maxWidth: 200),
      );
      final wideRes = renderMermaid(lrSrc);
      expect(turnedRes.width, lessThan(wideRes.width));
    });

    test(
      'respects gitGraph config options and cherry-pick of merge commits',
      () {
        const src = '''
---
config:
  gitGraph:
    mainBranchName: trunk
    mainBranchOrder: 2
    showBranches: false
    showCommitLabel: false
    rotateCommitLabel: false
    parallelCommits: true
---
gitGraph
  accDescr {
    Multiline description
    for gitGraph
  }
  commit id: "t1"
  branch b1 order: 1
  commit id: "b1-c1"
  checkout trunk
  commit id: "t2"
  merge b1 id: "m1"
  branch b2 order: 0
  commit id: "b2-c1"
  cherry-pick id: "m1" parent: "t2" tag: "cp-merge"
''';
        final model = parseGitDiagram(src);
        expect(model.lanes, <String>['b2', 'b1', 'trunk']);
        expect(model.accDescr, 'Multiline description\nfor gitGraph');

        final res = renderMermaid(src);
        expect(res.svg, isNot(contains('class="pele-branches"')));
        expect(res.svg, isNot(contains('class="pele-commit-label"')));
        expect(res.svg, contains('cp-merge'));
      },
    );

    test('validates semantic and syntax errors', () {
      expect(
        () => renderMermaid('gitGraph\n  checkout missing'),
        throwsA(isA<PeleError>().having((e) => e.code, 'code', 'semantic')),
      );
      expect(
        () => renderMermaid('gitGraph\n  branch main'),
        throwsA(isA<PeleError>().having((e) => e.code, 'code', 'semantic')),
      );
      expect(
        () => renderMermaid('gitGraph\n  commit\n  merge main'),
        throwsA(isA<PeleError>().having((e) => e.code, 'code', 'semantic')),
      );
      expect(
        () =>
            renderMermaid('gitGraph\n  commit id: "a"\n  cherry-pick id: "a"'),
        throwsA(isA<PeleError>().having((e) => e.code, 'code', 'semantic')),
      );
      expect(
        () => renderMermaid('gitGraph\n  invalidStatement'),
        throwsA(isA<PeleError>().having((e) => e.code, 'code', 'syntax')),
      );
    });
  });
}
