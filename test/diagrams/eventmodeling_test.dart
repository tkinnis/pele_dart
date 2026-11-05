import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('eventmodeling diagram', () {
    const sampleSource = '''---
title: Hotel Booking Flow
---
eventmodeling

entity Cart.RoomSelection
entity Payment.Gateway

tf 01 ui RoomSelector `html` "<button>Book</button>"
tf 02 cmd Cart.SelectRoom ->> 01 `json` { "roomId": 101 }
tf 03 evt Cart.RoomSelected ->> 02 [[RoomData]]
tf 04 rmo RoomAvailability ->> 03
tf 05 pcr Payment.ChargeProcessor ->> 03
rf 06 evt Cart.CartCleared

data RoomData `json` {
  "roomId": 101,
  "nights": 3
}
  accTitle: Booking Event Model

note 03 `md` {
  Emitted when a guest confirms room selection.
}
  accDescr: Event model for booking a room

gwt 02
  given evt RoomSelected
  when cmd SelectRoom
  then evt RoomSelected
''';

    test('renders horizontal eventmodeling diagram in cssVariables and flattened modes', () {
      final cssRes = render(
        sampleSource,
        const RenderOptions(outputMode: SvgOutputMode.cssVariables),
      );
      expect(cssRes.type, 'eventmodeling');
      expect(cssRes.mermaidType, 'eventmodeling');
      expect(cssRes.width, greaterThan(400));
      expect(cssRes.height, greaterThan(250));
      expect(cssRes.svg, contains('class="pele pele-eventmodeling"'));
      expect(
        cssRes.svg,
        contains('<title id="pele-title">Booking Event Model</title>'),
      );
      expect(cssRes.svg, contains('Hotel Booking Flow'));
      expect(cssRes.svg, contains('pele-em-lane'));
      expect(cssRes.svg, contains('pele-em-ui'));
      expect(cssRes.svg, contains('pele-em-command'));
      expect(cssRes.svg, contains('pele-em-event'));
      expect(cssRes.svg, contains('pele-em-readmodel'));
      expect(cssRes.svg, contains('pele-em-processor'));
      expect(cssRes.svg, contains('pele-em-reset'));
      expect(cssRes.svg, contains('pele-em-note'));
      expect(cssRes.svg, contains('pele-em-specification'));
      expect(cssRes.svg, contains('Given / When / Then'));
      expect(cssRes.svg, contains('var(--_fg)'));

      final flatRes = render(
        sampleSource,
        const RenderOptions(outputMode: SvgOutputMode.flattened),
      );
      expect(flatRes.type, 'eventmodeling');
      expect(flatRes.svg, isNot(contains('var(--')));
      expect(flatRes.svg, isNot(contains('color-mix(')));
      expect(flatRes.svg, contains('Hotel Booking Flow'));
      expect(flatRes.svg, contains('RoomSelector'));
    });

    test('turns to vertical layout when maxWidth is narrow', () {
      final verticalRes = render(
        sampleSource,
        const RenderOptions(maxWidth: 360, outputMode: SvgOutputMode.flattened),
      );
      expect(verticalRes.type, 'eventmodeling');
      expect(verticalRes.svg, contains('pele-em-frame'));
      expect(verticalRes.svg, isNot(contains('var(--')));
    });

    test('throws semantic PeleError on duplicate frame IDs', () {
      const dupSource = '''eventmodeling
tf 01 ui HomeScreen
tf 01 cmd DoSomething
''';
      expect(
        () => render(dupSource),
        throwsA(
          isA<PeleError>()
              .having((e) => e.code, 'code', 'semantic')
              .having(
                (e) => e.message,
                'message',
                contains('Duplicate event modeling frame ID "01"'),
              ),
        ),
      );
    });
  });
}
