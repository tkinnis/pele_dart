import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('C4 Diagram (c4)', () {
    test('renders C4Context with Person, System, boundaries, relationships, and styles in cssVariables and flattened modes', () {
      const source = '''
C4Context
  title System Context diagram for Internet Banking System
  accDescr {
    Internet Banking System Context Description
  }

  Enterprise_Boundary(b0, "BankBoundary0") {
    Person(customerA, "Banking Customer A", "A customer of the bank, with personal bank accounts.")
    Person_Ext(customerB, "Banking Customer B")

    System(SystemAA, "Internet Banking System", "Allows customers to view information about their bank accounts, and make payments.", \$link="https://example.com/ibs")

    Enterprise_Boundary(b1, "BankBoundary") {
      SystemDb_Ext(SystemE, "Mainframe Banking System", "Stores all of the core banking information about customers, accounts, transactions, etc.")

      System_Boundary(b2, "BankBoundary2") {
        System(SystemA, "Banking System A")
        SystemQueue(SystemB, "Banking System B", "A system of the bank.")
      }

      System_Ext(SystemC, "E-mail system", "The internal Microsoft Exchange e-mail system.")
      SystemDb(SystemD, "Banking System D Database", "A system of the bank, with personal bank accounts.")
    }
  }

  BiRel(customerA, SystemAA, "Uses")
  BiRel(SystemAA, SystemE, "Uses", "HTTPS")
  Rel(SystemAA, SystemC, "Sends e-mails", "SMTP", "Email notifications", \$link="https://example.com/smtp")
  Rel(SystemC, customerA, "Sends e-mails to")

  UpdateElementStyle(customerA, \$fontColor="red", \$bgColor="grey", \$borderColor="red")
  UpdateRelStyle(customerA, SystemAA, \$textColor="blue", \$lineColor="blue", \$offsetX="5", \$offsetY="-5")
  UpdateLayoutConfig(\$c4ShapeInRow="3", \$c4BoundaryInRow="1")
''';

      final cssRes = render(
        source,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssRes.type, 'c4');
      expect(cssRes.mermaidType, 'c4');
      expect(cssRes.width, greaterThan(200));
      expect(cssRes.height, greaterThan(200));
      expect(cssRes.svg, contains('class="pele pele-c4"'));
      expect(cssRes.svg, contains('var(--_fg)'));
      expect(
        cssRes.svg,
        contains('System Context diagram for Internet Banking System'),
      );
      expect(
        cssRes.svg,
        contains(
          '<desc id="pele-desc">Internet Banking System Context Description</desc>',
        ),
      );
      expect(cssRes.svg, contains('pele-shape-person'));
      expect(cssRes.svg, contains('pele-shape-cyl'));
      expect(cssRes.svg, contains('pele-shape-h-cyl'));
      expect(cssRes.svg, contains('pele-c4-external'));
      expect(cssRes.svg, contains('«person»'));
      expect(cssRes.svg, contains('«external person»'));
      expect(cssRes.svg, contains('«external system db»'));
      expect(cssRes.svg, contains('«system queue»'));
      expect(cssRes.svg, contains('[ENTERPRISE]'));
      expect(cssRes.svg, contains('[SYSTEM]'));
      expect(cssRes.svg, contains('[HTTPS]'));
      expect(cssRes.svg, contains('[SMTP]'));
      expect(cssRes.links, hasLength(2));
      expect(cssRes.links[0].id, 'SystemAA-SystemC');
      expect(cssRes.links[0].href, 'https://example.com/smtp');
      expect(cssRes.links[1].id, 'SystemAA');
      expect(cssRes.links[1].href, 'https://example.com/ibs');

      final flatSvg = renderMermaid(
        source,
        options: const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatSvg, isNot(contains('var(--')));
      expect(flatSvg, isNot(contains('color-mix(')));
      expect(
        flatSvg,
        contains('System Context diagram for Internet Banking System'),
      );
      expect(flatSvg, contains('Banking Customer A'));
      expect(flatSvg, contains('Internet Banking System'));
    });

    test('renders C4Container, C4Component, C4Dynamic, and C4Deployment variants with tight maxWidth', () {
      const dynamicSource = '''
C4Dynamic
  title Dynamic diagram
  ContainerDb(c4, "Database", "Relational Schema", "Stores users")
  Component(c1, "Sign In Controller", "Spring MVC", "Allows sign in")
  Component(c2, "Security Component", "Spring Bean", "Auth logic")
  Container_Boundary(b, "API Application") {
    ComponentDb(c3, "Audit Store", "Event Store")
    ComponentQueue_Ext(c5, "Message Bus", "Kafka")
  }
  Rel(c1, c2, "Calls")
  RelIndex(2, c2, c4, "Queries", "JDBC")
  Rel_Back(c3, c2, "Logs audit trail")
  Rel(c1, c1, "Check")
''';

      final dynCss = renderMermaid(
        dynamicSource,
        options: const RenderOptions(
          outputMode: SvgOutputMode.cssVariables,
          maxWidth: 360,
        ),
      );
      expect(dynCss, contains('class="pele pele-c4"'));
      expect(dynCss, contains('1: Calls'));
      expect(dynCss, contains('2: Queries'));
      expect(dynCss, contains('3: Logs audit trail'));
      expect(dynCss, contains('[CONTAINER]'));

      final dynFlat = renderMermaid(
        dynamicSource,
        options: const RenderOptions(
          outputMode: SvgOutputMode.flattened,
          maxWidth: 360,
        ),
      );
      expect(dynFlat, isNot(contains('var(--')));
      expect(dynFlat, isNot(contains('color-mix(')));

      const deploySource = '''
C4Deployment
  title Deployment Diagram
  Deployment_Node(plc, "Live", "Big Bank plc") {
    Node_L(dn, "bb-server", "Ubuntu 22.04") {
      Container(api, "API Application", "Java", "Provides functionality")
    }
    Node_R(dbNode, "bb-db", "Oracle") {
      ContainerDb(db, "Database", "Oracle 19c", "Stores data")
    }
  }
  Rel_R(api, db, "Reads from and writes to", "JDBC")
''';

      final depFlat = renderMermaid(
        deploySource,
        options: const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(depFlat, isNot(contains('var(--')));
      expect(depFlat, contains('pele-c4-node'));
      expect(depFlat, contains('API Application'));
    });

    test('throws PeleError on unknown relationship target or syntax error', () {
      expect(
        () => renderMermaid('''
C4Context
  Person(u, "User")
  Rel(u, missing, "Uses")
'''),
        throwsA(isA<PeleError>()),
      );

      expect(
        () => renderMermaid('C4Context\n  InvalidKeyword(a, "b")'),
        throwsA(isA<PeleError>()),
      );
    });
  });
}
