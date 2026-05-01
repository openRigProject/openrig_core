import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

void main() {
  group('isValidCallsign', () {
    test('accepts standard callsigns', () {
      expect(isValidCallsign('W1AW'), isTrue);
      expect(isValidCallsign('VK2ABC'), isTrue);
      expect(isValidCallsign('9A1A'), isTrue);
      expect(isValidCallsign('HS0ZJF'), isTrue);
      expect(isValidCallsign('JA1ABC'), isTrue);
      expect(isValidCallsign('G3XYZ'), isTrue);
    });

    test('accepts callsigns with prefix', () {
      expect(isValidCallsign('EA/W1AW'), isTrue);
      expect(isValidCallsign('VK/JA1ABC'), isTrue);
    });

    test('accepts callsigns with suffix', () {
      expect(isValidCallsign('W1AW/P'), isTrue);
      expect(isValidCallsign('W1AW/QRP'), isTrue);
      expect(isValidCallsign('W1AW/M'), isTrue);
      expect(isValidCallsign('W1AW/MM'), isTrue);
      expect(isValidCallsign('W1AW/AM'), isTrue);
    });

    test('accepts callsigns with prefix and suffix', () {
      expect(isValidCallsign('EA/W1AW/P'), isTrue);
    });

    test('is case-insensitive', () {
      expect(isValidCallsign('w1aw'), isTrue);
      expect(isValidCallsign('ea/w1aw/p'), isTrue);
    });

    test('rejects invalid strings', () {
      expect(isValidCallsign(''), isFalse);
      expect(isValidCallsign('AB'), isFalse);
      expect(isValidCallsign('HELLO'), isFalse);
      expect(isValidCallsign('12345'), isFalse);
      expect(isValidCallsign('A'), isFalse);
    });

    test('rejects strings exceeding max length', () {
      expect(isValidCallsign('EA/W1AWWWWWWW/P'), isFalse);
    });
  });

  group('normalizeCallsign', () {
    test('uppercases and trims', () {
      expect(normalizeCallsign('  w1aw  '), equals('W1AW'));
      expect(normalizeCallsign('ea/w1aw/p'), equals('EA/W1AW/P'));
    });
  });

  group('baseCallsign', () {
    test('returns bare callsign unchanged', () {
      expect(baseCallsign('W1AW'), equals('W1AW'));
    });

    test('strips prefix', () {
      expect(baseCallsign('EA/W1AW'), equals('W1AW'));
    });

    test('strips suffix', () {
      expect(baseCallsign('W1AW/P'), equals('W1AW'));
      expect(baseCallsign('W1AW/QRP'), equals('W1AW'));
    });

    test('strips both prefix and suffix', () {
      expect(baseCallsign('EA/W1AW/P'), equals('W1AW'));
    });

    test('is case-insensitive (returns uppercase)', () {
      expect(baseCallsign('ea/w1aw/p'), equals('W1AW'));
    });
  });

  group('callsignPrefix', () {
    test('returns null for bare callsign', () {
      expect(callsignPrefix('W1AW'), isNull);
    });

    test('returns prefix when present', () {
      expect(callsignPrefix('EA/W1AW'), equals('EA'));
      expect(callsignPrefix('VK/JA1ABC'), equals('VK'));
    });

    test('returns null for suffix-only', () {
      expect(callsignPrefix('W1AW/P'), isNull);
    });

    test('returns prefix from three-part callsign', () {
      expect(callsignPrefix('EA/W1AW/P'), equals('EA'));
    });
  });

  group('callsignSuffix', () {
    test('returns null for bare callsign', () {
      expect(callsignSuffix('W1AW'), isNull);
    });

    test('returns suffix when present', () {
      expect(callsignSuffix('W1AW/P'), equals('P'));
      expect(callsignSuffix('W1AW/QRP'), equals('QRP'));
      expect(callsignSuffix('W1AW/MM'), equals('MM'));
    });

    test('returns null for prefix-only', () {
      expect(callsignSuffix('EA/W1AW'), isNull);
    });

    test('returns suffix from three-part callsign', () {
      expect(callsignSuffix('EA/W1AW/P'), equals('P'));
    });
  });
}
