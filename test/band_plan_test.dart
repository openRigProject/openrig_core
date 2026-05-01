import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

void main() {
  group('bandFromMhz', () {
    test('returns 20m for 14.225', () {
      final band = bandFromMhz(14.225);
      expect(band, isNotNull);
      expect(band!.name, equals('20m'));
    });

    test('returns 40m for 7.074 (FT8)', () {
      final band = bandFromMhz(7.074);
      expect(band, isNotNull);
      expect(band!.name, equals('40m'));
    });

    test('returns 2m for 146.520', () {
      final band = bandFromMhz(146.520);
      expect(band, isNotNull);
      expect(band!.name, equals('2m'));
    });

    test('returns 70cm for 440.000', () {
      final band = bandFromMhz(440.0);
      expect(band, isNotNull);
      expect(band!.name, equals('70cm'));
    });

    test('returns 60m for 5.36 MHz', () {
      final band = bandFromMhz(5.36);
      expect(band, isNotNull);
      expect(band!.name, equals('60m'));
    });

    test('returns 30m for 10.125 MHz', () {
      final band = bandFromMhz(10.125);
      expect(band, isNotNull);
      expect(band!.name, equals('30m'));
    });

    test('returns 17m for 18.1 MHz', () {
      final band = bandFromMhz(18.1);
      expect(band, isNotNull);
      expect(band!.name, equals('17m'));
    });

    test('returns 12m for 24.9 MHz', () {
      final band = bandFromMhz(24.9);
      expect(band, isNotNull);
      expect(band!.name, equals('12m'));
    });

    test('returns null for out-of-band frequency', () {
      expect(bandFromMhz(100.0), isNull);
    });

    test('returns band at exact lower edge', () {
      final band = bandFromMhz(14.000);
      expect(band, isNotNull);
      expect(band!.name, equals('20m'));
    });

    test('returns band at exact upper edge', () {
      final band = bandFromMhz(14.350);
      expect(band, isNotNull);
      expect(band!.name, equals('20m'));
    });

    test('all HF bands are findable', () {
      final testFreqs = {
        '160m': 1.9,
        '80m': 3.75,
        '60m': 5.37,
        '40m': 7.15,
        '30m': 10.12,
        '20m': 14.2,
        '17m': 18.1,
        '15m': 21.3,
        '12m': 24.95,
        '10m': 28.5,
      };
      for (final entry in testFreqs.entries) {
        final band = bandFromMhz(entry.value);
        expect(band, isNotNull, reason: '${entry.key} at ${entry.value} MHz');
        expect(band!.name, equals(entry.key));
      }
    });
  });

  group('bandFromKhz', () {
    test('returns 20m for 14225.0 kHz', () {
      final band = bandFromKhz(14225.0);
      expect(band, isNotNull);
      expect(band!.name, equals('20m'));
    });
  });

  group('bandFromHz', () {
    test('returns 20m for 14225000 Hz', () {
      final band = bandFromHz(14225000);
      expect(band, isNotNull);
      expect(band!.name, equals('20m'));
    });
  });

  group('SubBand', () {
    test('20m CW sub-band at 14.025', () {
      final band = bandFromMhz(14.025);
      expect(band, isNotNull);
      final sub = band!.subBandFromMhz(14.025);
      expect(sub, isNotNull);
      expect(sub!.name, equals('CW'));
    });

    test('20m SSB sub-band at 14.225', () {
      final band = bandFromMhz(14.225);
      final sub = band!.subBandFromMhz(14.225);
      expect(sub, isNotNull);
      expect(sub!.name, equals('SSB'));
    });

    test('20m digital sub-band at 14.074 (FT8)', () {
      final band = bandFromMhz(14.074);
      final sub = band!.subBandFromMhz(14.074);
      expect(sub, isNotNull);
      expect(sub!.name, equals('Digital'));
    });
  });

  group('hfBands', () {
    test('contains 10 HF bands', () {
      expect(hfBands, hasLength(10));
    });

    test('all have sub-bands', () {
      for (final band in hfBands) {
        expect(band.subBands, isNotEmpty,
            reason: '${band.name} should have sub-bands');
      }
    });
  });

  group('vhfUhfBands', () {
    test('contains 3 VHF/UHF bands', () {
      expect(vhfUhfBands, hasLength(3));
      expect(vhfUhfBands.map((b) => b.name), containsAll(['6m', '2m', '70cm']));
    });
  });
}
