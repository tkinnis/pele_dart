import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('timeline diagram', () {
    const sampleTimeline = '''
timeline
  title History of Social Media Platform
  accTitle: Timeline Accessible Title
  accDescr: Timeline Accessible Description
  2001 : Leading event before sections
  section 2002-2003
    2002 : LinkedIn
    2003 : MySpace : WordPress
  section 2004-2006
    2004 : Facebook
         : Google
    2005 : YouTube
    2006 : Twitter
''';

    test('renders in cssVariables mode', () {
      final res = render(
        sampleTimeline,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(res.type, 'timeline');
      expect(res.mermaidType, 'timeline');
      expect(res.width, greaterThan(400));
      expect(res.height, greaterThan(150));
      expect(res.svg, contains('class="pele pele-timeline"'));
      expect(res.svg, contains('var(--_fg)'));
      expect(
        res.svg,
        contains('<title id="pele-title">Timeline Accessible Title</title>'),
      );
      expect(
        res.svg,
        contains('<desc id="pele-desc">Timeline Accessible Description</desc>'),
      );
      expect(res.svg, contains('History of Social Media Platform'));
      expect(res.svg, contains('LinkedIn'));
      expect(res.svg, contains('WordPress'));
      expect(res.svg, contains('pele-axis'));
      expect(res.svg, contains('pele-period'));
      expect(res.svg, contains('pele-event'));
    });

    test('renders in flattened mode without CSS variables', () {
      final res = render(
        sampleTimeline,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(res.type, 'timeline');
      expect(res.svg, isNot(contains('var(--')));
      expect(res.svg, isNot(contains('color-mix(')));
      expect(res.svg, contains('History of Social Media Platform'));
      expect(res.svg, contains('Facebook'));
      expect(res.svg, contains('YouTube'));
    });

    test(
      'renders vertical TD timeline and auto-rotates under narrow maxWidth',
      () {
        const tdSrc = '''
timeline TD
  title Vertical Timeline
  section Phase 1
    Q1 : Kickoff : Planning
    Q2 : Execution
''';
        final tdRes = render(
          tdSrc,
          const RenderOptions(outputMode: SvgOutputMode.flattened),
        );
        expect(tdRes.svg, isNot(contains('var(--')));
        expect(tdRes.svg, contains('Vertical Timeline'));
        expect(tdRes.svg, contains('Kickoff'));

        final autoRes = render(
          sampleTimeline,
          const RenderOptions(
            outputMode: SvgOutputMode.flattened,
            maxWidth: 420,
          ),
        );
        expect(autoRes.width, lessThan(600));
        expect(autoRes.svg, isNot(contains('var(--')));
      },
    );

    test('throws PeleError when an event precedes any period', () {
      expect(
        () => render('timeline\n  : Orphan event'),
        throwsA(isA<PeleError>()),
      );
    });
  });
}
