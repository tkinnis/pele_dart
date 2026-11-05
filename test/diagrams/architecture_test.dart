import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Architecture Diagram (architecture-beta)', () {
    test('renders groups, services, junctions, edges, and builtin icons in cssVariables and flattened modes', () {
      const source = '''
architecture-beta
  title Cloud Storage Architecture
  accTitle: Cloud Architecture Title
  accDescr: Cloud Architecture Description

  group api(cloud)[API]
  group storage(disk)[Storage Tier] in api

  service db(database)[Database] in storage
  service disk1(disk)[Storage] in storage
  service disk2(disk)[Replica] in storage
  service server(server)[Gateway] in api
  service client(internet)[Client]
  service badge"S3"[Object Store] in storage

  junction juncCenter in storage

  client:R --> L:server
  server:B -[writes]-> T:juncCenter
  juncCenter:L --> R:db
  juncCenter:T --> B:disk1
  juncCenter:B <-- T:disk2
  disk1:R -- L:badge

  align row db badge
''';

      final cssRes = render(
        source,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssRes.type, 'architecture');
      expect(cssRes.mermaidType, 'architecture');
      expect(cssRes.width, greaterThan(150));
      expect(cssRes.height, greaterThan(150));
      expect(cssRes.svg, contains('class="pele pele-architecture"'));
      expect(cssRes.svg, contains('var(--_fg)'));
      expect(cssRes.svg, contains('Cloud Storage Architecture'));
      expect(
        cssRes.svg,
        contains('<title id="pele-title">Cloud Architecture Title</title>'),
      );
      expect(
        cssRes.svg,
        contains('<desc id="pele-desc">Cloud Architecture Description</desc>'),
      );
      expect(cssRes.svg, contains('pele-cluster'));
      expect(cssRes.svg, contains('pele-service'));
      expect(cssRes.svg, contains('pele-junction'));
      expect(cssRes.svg, contains('pele-icon-text'));
      expect(cssRes.svg, contains('data-icon="cloud"'));
      expect(cssRes.svg, contains('data-icon="database"'));
      expect(cssRes.svg, contains('data-icon="server"'));
      expect(cssRes.svg, contains('data-icon="internet"'));
      expect(cssRes.svg, contains('writes'));
      expect(cssRes.svg, contains('Object Store'));

      final flatSvg = renderMermaid(
        source,
        options: const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatSvg, isNot(contains('var(--')));
      expect(flatSvg, isNot(contains('color-mix(')));
      expect(flatSvg, contains('Cloud Storage Architecture'));
      expect(flatSvg, contains('Database'));
      expect(flatSvg, contains('Gateway'));
    });

    test('supports {group} boundary edges, custom icon resolver, column alignment, and tight maxWidth', () {
      const source = '''
architecture-beta
  group left_group[Left Zone]
  group right_group[Right Zone]

  service svc1(custom:api)[API 1] in left_group
  service svc2(server)[API 2] in left_group
  service svc3(database)[Main DB] in right_group

  svc1{group}:R --> L:svc3{group}
  svc1:B -- T:svc2
  align column svc1 svc2
''';

      final cssSvg = renderMermaid(
        source,
        options: RenderOptions(
          outputMode: SvgOutputMode.cssVariables,
          maxWidth: 280,
          icons: (name) =>
              name == 'custom:api' ? '<circle cx="12" cy="12" r="8"/>' : null,
        ),
      );
      expect(cssSvg, contains('Left Zone'));
      expect(cssSvg, contains('Right Zone'));
      expect(cssSvg, contains('<circle cx="12" cy="12" r="8"/>'));

      final flatSvg = renderMermaid(
        source,
        options: const RenderOptions(
          outputMode: SvgOutputMode.flattened,
          maxWidth: 280,
        ),
      );
      expect(flatSvg, isNot(contains('var(--')));
      expect(flatSvg, isNot(contains('color-mix(')));
    });

    test('throws PeleError on semantic and syntax errors', () {
      // Duplicate ID
      expect(
        () => renderMermaid('''
architecture-beta
  service dup(server)[A]
  service dup(database)[B]
'''),
        throwsA(isA<PeleError>()),
      );

      // Edge to non-existent node
      expect(
        () => renderMermaid('''
architecture-beta
  service a(server)[A]
  a:R --> L:missing
'''),
        throwsA(isA<PeleError>()),
      );

      // Edge directly to a group without {group} on a service
      expect(
        () => renderMermaid('''
architecture-beta
  group g[Group]
  service a(server)[A]
  a:R --> L:g
'''),
        throwsA(isA<PeleError>()),
      );

      // {group} modifier within the same group
      expect(
        () => renderMermaid('''
architecture-beta
  group g[Group]
  service a(server)[A] in g
  service b(server)[B] in g
  a{group}:R --> L:b
'''),
        throwsA(isA<PeleError>()),
      );
    });
  });
}
