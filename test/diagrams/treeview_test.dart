import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('treeView diagram', () {
    const sampleIndentSource = '''---
config:
  treeView:
    showIcons: true
---
treeView-beta
title Project Workspace
accTitle: Workspace Tree
accDescr: Directory hierarchy for the project
src/ ## Source code root
    index.ts :::highlight ## Entrypoint
    components/
        "Button.tsx" icon(react) ## UI button
    README.md icon() ## Documentation without icon
''';

    test(
      'renders indentation-based treeView in cssVariables and flattened modes',
      () {
        final cssRes = render(
          sampleIndentSource,
          const RenderOptions(
            outputMode: SvgOutputMode.cssVariables,
            monospace: <String>['files'],
          ),
        );
        expect(cssRes.type, 'treeView');
        expect(cssRes.mermaidType, 'treeView');
        expect(cssRes.width, greaterThan(150));
        expect(cssRes.height, greaterThan(100));
        expect(cssRes.svg, contains('class="pele pele-treeView"'));
        expect(
          cssRes.svg,
          contains('<title id="pele-title">Workspace Tree</title>'),
        );
        expect(cssRes.svg, contains('Project Workspace'));
        expect(cssRes.svg, contains('pele-tree-guides'));
        expect(cssRes.svg, contains('pele-tree-dir'));
        expect(cssRes.svg, contains('pele-tree-file'));
        expect(cssRes.svg, contains('pele-tree-highlight'));
        expect(cssRes.svg, contains('pele-tree-description'));
        expect(cssRes.svg, contains('pele-icon'));
        expect(cssRes.svg, contains('var(--_fg)'));

        final flatRes = render(
          sampleIndentSource,
          const RenderOptions(
            outputMode: SvgOutputMode.flattened,
            monospace: <String>['files'],
          ),
        );
        expect(flatRes.type, 'treeView');
        expect(flatRes.svg, isNot(contains('var(--')));
        expect(flatRes.svg, isNot(contains('color-mix(')));
        expect(flatRes.svg, contains('Project Workspace'));
        expect(flatRes.svg, contains('Button.tsx'));
      },
    );

    test('renders box-drawing format and tight maxWidth layout', () {
      const boxSource = '''treeView-beta
my-app/
├── src/
│   ├── main.dart ## Application entry
│   └── utils.dart
└── pubspec.yaml ## Package manifest
''';
      final res = render(
        boxSource,
        const RenderOptions(maxWidth: 220, outputMode: SvgOutputMode.flattened),
      );
      expect(res.type, 'treeView');
      expect(res.svg, contains('my-app'));
      expect(res.svg, contains('main.dart'));
      expect(res.svg, contains('pubspec.yaml'));
      expect(res.svg, isNot(contains('var(--')));
    });

    test('throws syntax PeleError on invalid box-drawing indentation', () {
      const badBoxSource = '''treeView-beta
root/
├── child1.txt
    indented_without_branch.txt
''';
      expect(
        () => render(badBoxSource),
        throwsA(isA<PeleError>().having((e) => e.code, 'code', 'syntax')),
      );
    });
  });
}
