import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart/src/diagrams/class/db.dart';
import 'package:pele_dart/src/diagrams/class/graph.dart';
import 'package:pele_dart/src/diagrams/class/index.dart';
import 'package:pele_dart/src/diagrams/class/members.dart';
import 'package:pele_dart/src/diagrams/class/types.dart';
import 'package:pele_dart/src/types.dart';
import 'package:test/test.dart';

ClassModel _parseClass(String src, [String? title]) => classDiagram.parse(
  src,
  const <String, Object?>{},
  title,
  0,
  const ParseLimits(maxEdges: 500),
);

void main() {
  group('class diagram members', () {
    test('parses attributes and methods with visibility, generics, and classifiers', () {
      final attr = ClassMember('-List~int~ items\$', 'attribute');
      expect(attr.memberType, equals('attribute'));
      expect(attr.visibility, equals('-'));
      expect(attr.classifier, equals('\$'));
      final attrDisplay = attr.getDisplayDetails();
      expect(attrDisplay.displayText, equals('-List<int> items'));
      expect(attrDisplay.cssStyle, equals('text-decoration:underline;'));

      final method = ClassMember(
        '+fetch(String id, Map~K,V~ opts)* Promise~T~',
        'method',
      );
      expect(method.memberType, equals('method'));
      expect(method.visibility, equals('+'));
      expect(method.id, equals('fetch'));
      expect(method.parameters, equals('String id, Map~K,V~ opts'));
      expect(method.classifier, equals('*'));
      expect(method.returnType, equals('Promise~T~'));
      final methodDisplay = method.getDisplayDetails();
      expect(
        methodDisplay.displayText,
        equals('+fetch(String id, Map<K,V> opts) : Promise<T>'),
      );
      expect(methodDisplay.cssStyle, equals('font-style:italic;'));
    });

    test('keeps a method with no opening parenthesis as an attribute', () {
      for (final input in ['run)', '(a)', '+x)', ')(', 'a)b']) {
        final member = ClassMember(input, 'method');
        expect(member.memberType, equals('attribute'));
        expect(member.getDisplayDetails().displayText, equals(input));
      }
    });
  });

  group('class diagram parser & model', () {
    test('parses direction, members, and cardinalities', () {
      final model = _parseClass('''
classDiagram
  direction TB
  class Student {
    -idCard : IdCard
  }
  class IdCard{
    -id : int
    -name : string
  }
  class Bike{
    -id : int
    -name : string
  }
  Student "1" --o "1" IdCard : carries
  Student "1" --o "1" Bike : rides
''');
      expect(model.direction, equals('TB'));
      final student = model.classes['Student']!;
      expect(student.id, equals('Student'));
      expect(student.label, equals('Student'));
      expect(student.members.length, equals(1));
      expect(student.members[0].id, equals('idCard : IdCard'));
      expect(student.members[0].visibility, equals('-'));
      expect(model.relations.length, equals(2));
      expect(model.relations[0].id1, equals('Student'));
      expect(model.relations[0].id2, equals('IdCard'));
      expect(model.relations[0].relation.type1, equals('none'));
      expect(
        model.relations[0].relation.type2,
        equals(RELATION_TYPE.AGGREGATION),
      );
      expect(model.relations[0].relationTitle1, equals('1'));
      expect(model.relations[0].relationTitle2, equals('1'));
      expect(model.relations[0].title, equals('carries'));
    });

    test(
      'parses frontmatter title via public parse() and handles annotations',
      () {
        final parsed = parse('''
---
title: Animals
---
classDiagram-v2
  <<interface>> Shape
  class Shape {
    <<abstract>>
    +draw()* void
  }
  Color : <<enumeration>>
  Animal <|-- Duck
''');
        final model = parsed as ClassModel;
        expect(model.type, equals('class'));
        expect(model.title, equals('Animals'));
        expect(
          model.classes['Shape']!.annotations,
          equals(['interface', 'abstract']),
        );
        expect(model.classes['Shape']!.methods.length, equals(1));
        expect(model.classes['Color']!.annotations, equals(['enumeration']));
        expect(model.classes.keys, containsAll(['Animal', 'Duck']));
      },
    );

    test('handles classDef, cssClass, links, callbacks, namespaces, and lollipop interfaces', () {
      final model = _parseClass('''
classDiagram
  namespace Core.Domain {
    class Service~T~["Domain Service"]:::defined {
      +int count\$
      +execute(T input)* bool
    }
  }
  class Helper
  classDef def fill:#f00
  classDef defined fill:#0f0,stroke:#000
  cssClass "Helper" hot
  link Service "javascript:alert(1)"
  click Helper href "https://example.com/a b" "Helper tip" _self
  bar ()-- Service
  Service --() baz
  note for Service "Core note"
''');
      final service = model.classes['Service']!;
      expect(service.type, equals('T'));
      expect(service.label, equals('Domain Service'));
      expect(service.parent, equals('Core.Domain'));
      expect(service.styles, equals(['fill:#0f0', 'stroke:#000']));
      expect(service.link, equals('about:blank'));
      expect(service.linkTarget, equals('_blank'));

      final helper = model.classes['Helper']!;
      expect(helper.cssClasses, equals('default hot clickable'));
      expect(helper.link, equals('https://example.com/a%20b'));
      expect(helper.linkTarget, equals('_self'));
      expect(helper.tooltip, equals('Helper tip'));

      expect(model.interfaces.length, equals(2));
      expect(model.interfaces[0].label, equals('bar'));
      expect(model.interfaces[1].label, equals('baz'));
      expect(model.notes['note0']!.text, equals('Core note'));

      final graph = buildClassGraph(model);
      expect(graph.nodes, isNotEmpty);
      expect(graph.edges, isNotEmpty);
    });

    test('throws PeleError on syntax and lexical errors', () {
      expect(
        () => _parseClass('classDiagram\nnote link'),
        throwsA(isA<PeleError>()),
      );
      expect(
        () => _parseClass('classDiagram\nclass A { x'),
        throwsA(isA<PeleError>()),
      );
      expect(
        () => _parseClass('classDiagram\nclass A\n@'),
        throwsA(isA<PeleError>()),
      );
    });
  });

  group('class diagram rendering', () {
    test('renders full class diagram in cssVariables and flattened modes', () {
      const src = '''
---
title: Vehicle Hierarchy
---
classDiagram
  direction LR
  namespace Transport {
    class Vehicle~T~ {
      <<abstract>>
      +String make
      #int year\$
      +start()* bool
      +drive(int miles) void
    }
    class Car {
      -int doors
      +honk()
    }
  }
  class Electric {
    <<interface>>
    +charge()
  }
  class Garage {
    +park(Vehicle v)
  }
  Vehicle <|-- Car : extends
  Electric <|.. Car : implements
  Garage "1" *-- "0..*" Vehicle : stores
  Garage o-- Car : manages
  Car --> Electric : uses
  Car ..> Garage : visits
  Inspectable ()-- Car
  Car --> Car : selfCheck
  note "General note"
  note for Car "Car specific note"
  classDef highlight fill:#ffeeaa,stroke:#333333,color:#111111
  cssClass "Car" highlight
  link Car "https://example.com/car" "Car Docs"
''';
      final cssOut = render(
        src,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssOut.type, equals('class'));
      expect(cssOut.width, greaterThan(0));
      expect(cssOut.height, greaterThan(0));
      expect(cssOut.svg, startsWith('<svg'));
      expect(cssOut.svg, contains('class="pele pele-class"'));
      expect(cssOut.svg, contains('aria-roledescription="class"'));
      expect(cssOut.svg, contains('Vehicle Hierarchy'));
      expect(cssOut.svg, contains('Transport'));
      expect(cssOut.svg, contains('Vehicle&lt;T&gt;'));
      expect(cssOut.svg, contains('«abstract»'));
      expect(cssOut.svg, contains('«interface»'));
      expect(cssOut.svg, contains('Car specific note'));
      expect(cssOut.svg, contains('Inspectable'));
      expect(cssOut.svg, contains('https://example.com/car'));
      expect(cssOut.svg, contains('var(--_'));

      final flatOut = render(
        src,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatOut.type, equals('class'));
      expect(flatOut.svg, startsWith('<svg'));
      expect(flatOut.svg, contains('Vehicle Hierarchy'));
      expect(flatOut.svg, contains('Vehicle&lt;T&gt;'));
      expect(flatOut.svg, isNot(contains('var(--_')));
    });
  });
}
