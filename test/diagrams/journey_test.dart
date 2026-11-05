import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('journey diagram', () {
    const sampleJourney = '''
journey
  title My working day
  accTitle: Journey Accessible Title
  accDescr: Journey Accessible Description
  section Go to work
    Make tea: 5: Me
    Go upstairs: 3: Me
    Do work: 1: Me, Cat
  section Go home
    Go downstairs: 5: Me
    Sit down: 5: Me
''';

    test('renders in cssVariables mode', () {
      final res = render(
        sampleJourney,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(res.type, 'journey');
      expect(res.mermaidType, 'journey');
      expect(res.width, greaterThan(400));
      expect(res.height, greaterThan(150));
      expect(res.svg, contains('class="pele pele-journey"'));
      expect(res.svg, contains('var(--_fg)'));
      expect(
        res.svg,
        contains('<title id="pele-title">Journey Accessible Title</title>'),
      );
      expect(
        res.svg,
        contains('<desc id="pele-desc">Journey Accessible Description</desc>'),
      );
      expect(res.svg, contains('My working day'));
      expect(res.svg, contains('Make tea'));
      expect(res.svg, contains('pele-face-happy'));
      expect(res.svg, contains('pele-face-neutral'));
      expect(res.svg, contains('pele-face-sad'));
      expect(res.svg, contains('pele-legend'));
      expect(res.svg, contains('Cat'));
    });

    test('renders in flattened mode without CSS variables', () {
      final res = render(
        sampleJourney,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(res.type, 'journey');
      expect(res.svg, isNot(contains('var(--')));
      expect(res.svg, isNot(contains('color-mix(')));
      expect(res.svg, contains('My working day'));
      expect(res.svg, contains('Go to work'));
      expect(res.svg, contains('Go home'));
    });

    test('switches to vertical layout when maxWidth is narrow', () {
      final res = render(
        sampleJourney,
        const RenderOptions(outputMode: SvgOutputMode.flattened, maxWidth: 360),
      );
      expect(res.svg, isNot(contains('var(--')));
      expect(res.svg, contains('pele-journey-step'));
      expect(res.svg, contains('pele-journey-score'));
      expect(res.svg, contains('pele-journey-actor'));
    });

    test('throws PeleError on syntax error', () {
      expect(
        () => render('journey\n  Task without colon'),
        throwsA(isA<PeleError>()),
      );
    });
  });
}
