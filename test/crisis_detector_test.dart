import 'package:flutter_test/flutter_test.dart';
import 'package:rumini/services/crisis_detector.dart';

void main() {
  group('CrisisDetector.preCheck', () {
    test('flags English high-severity phrases', () {
      final match = CrisisDetector.preCheck(
        'I don\'t want to be here anymore, I want to kill myself',
      );
      expect(match, isNotNull);
      expect(match!.isHigh, isTrue);
      expect(match.language, 'en');
    });

    test('flags Tagalog high-severity phrases', () {
      final match = CrisisDetector.preCheck('Promise ayoko nang mabuhay pa');
      expect(match, isNotNull);
      expect(match!.isHigh, isTrue);
      expect(match.language, 'tl');
    });

    test('flags Taglish phrasing', () {
      final match = CrisisDetector.preCheck(
        'di ko na talaga kaya, gusto ko nang mamatay honestly',
      );
      expect(match, isNotNull);
      expect(match!.isHigh, isTrue);
    });

    test('flags medium-severity distress as medium', () {
      final match = CrisisDetector.preCheck('parang wala nang pag-asa lahat');
      expect(match, isNotNull);
      expect(match!.severity, 'medium');
    });

    test('returns null for everyday messages', () {
      expect(CrisisDetector.preCheck('I have finals next week'), isNull);
      expect(CrisisDetector.preCheck('paano mag book ng appointment?'), isNull);
      expect(CrisisDetector.preCheck('masaya ako ngayong araw'), isNull);
    });

    test('is case-insensitive and punctuation tolerant', () {
      final match = CrisisDetector.preCheck('I want to KILL MYSELF!!');
      expect(match, isNotNull);
      expect(match!.isHigh, isTrue);
    });
  });

  group('CrisisDetector.postCheck', () {
    test('catches high-severity content in model output', () {
      final match = CrisisDetector.postCheck(
        'Some students consider suicide when overwhelmed.',
      );
      expect(match, isNotNull);
      expect(match!.isHigh, isTrue);
    });

    test('ignores medium-severity phrases in model output', () {
      final match = CrisisDetector.postCheck(
        'Kapag sinasabi ng estudyante na hindi ko na kaya, mahalagang mag-check in.',
      );
      expect(match, isNull);
    });
  });

  group('CrisisDetector.fixedSafetyResponse', () {
    test('high severity includes hotline numbers', () {
      final text = CrisisDetector.fixedSafetyResponse(
        const CrisisMatch(
          phrase: 'kill myself',
          severity: 'high',
          language: 'en',
        ),
      );
      expect(text, contains('1553'));
      expect(text, contains('counselor'));
    });

    test('medium severity stays gentle and validating', () {
      final text = CrisisDetector.fixedSafetyResponse(
        const CrisisMatch(
          phrase: 'wala nang pag-asa',
          severity: 'medium',
          language: 'tl',
        ),
      );
      expect(text, contains('1553'));
      expect(text.toLowerCase(), contains('counselor'));
    });
  });
}
