import 'package:flutter_test/flutter_test.dart';

import 'package:dar_plus/services/ai_context_service.dart';

void main() {
  group('AiContextService.detectServiceType', () {
    test('recognizes a French plumbing request', () {
      expect(
        AiContextService.detectServiceType("J'ai une fuite sous l'évier"),
        'Plomberie',
      );
    });

    test('recognizes an English cleaning request', () {
      expect(
        AiContextService.detectServiceType('I need a home cleaning service'),
        'Ménage',
      );
    });

    test('recognizes an Arabic electrical request', () {
      expect(
        AiContextService.detectServiceType('أحتاج كهربائي'),
        'Électricité',
      );
    });

    test(
      'recognizes a painting request for the test professional category',
      () {
        expect(
          AiContextService.detectServiceType(
            'Je cherche un peintre pour le salon',
          ),
          'Peinture',
        );
      },
    );

    test('does not guess when the request is unclear', () {
      expect(AiContextService.detectServiceType('Bonjour'), isNull);
    });
  });
}
