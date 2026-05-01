import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

QsoRecord _qso(
  String call,
  String band, {
  String mode = 'SSB',
  double freq = 14.225,
  Map<String, String> extra = const {},
}) {
  return QsoRecord(
    call: call,
    band: band,
    mode: mode,
    freqMhz: freq,
    timeOn: DateTime.utc(2025, 1, 1),
    extra: extra,
  );
}

void main() {
  group('countDxcc', () {
    test('counts unique DXCC entities', () {
      final qsos = [
        _qso('W1AW', '20m'),
        _qso('K3LR', '20m'),     // same entity as W1AW
        _qso('VE3ABC', '40m'),
        _qso('JA1ABC', '20m'),
        _qso('DL1ABC', '15m'),
      ];
      // W1AW + K3LR = United States (1), Canada (1), Japan (1), Germany (1) = 4
      expect(countDxcc(qsos), equals(4));
    });

    test('returns 0 for empty list', () {
      expect(countDxcc([]), equals(0));
    });

    test('skips unknown callsigns', () {
      final qsos = [
        _qso('W1AW', '20m'),
        _qso('XX9ZZZ', '20m'), // unknown
      ];
      expect(countDxcc(qsos), equals(1));
    });
  });

  group('countWas', () {
    test('counts unique US states from ADIF STATE field', () {
      final qsos = [
        _qso('W1AW', '20m', extra: {'STATE': 'CT'}),
        _qso('K3LR', '40m', extra: {'STATE': 'PA'}),
        _qso('N1MM', '20m', extra: {'STATE': 'CT'}), // duplicate
        _qso('W6ABC', '15m', extra: {'STATE': 'CA'}),
      ];
      expect(countWas(qsos), equals(3)); // CT, PA, CA
    });

    test('returns 0 when no STATE fields present', () {
      final qsos = [
        _qso('W1AW', '20m'),
        _qso('VE3ABC', '40m'),
      ];
      expect(countWas(qsos), equals(0));
    });

    test('case insensitive', () {
      final qsos = [
        _qso('W1AW', '20m', extra: {'STATE': 'ct'}),
        _qso('K3LR', '40m', extra: {'STATE': 'CT'}),
      ];
      expect(countWas(qsos), equals(1));
    });
  });

  group('countWaz', () {
    test('counts unique CQ zones from ADIF CQZ field', () {
      final qsos = [
        _qso('W1AW', '20m', extra: {'CQZ': '5'}),
        _qso('JA1ABC', '20m', extra: {'CQZ': '25'}),
        _qso('VE3ABC', '40m', extra: {'CQZ': '5'}), // duplicate
        _qso('DL1ABC', '15m', extra: {'CQZ': '14'}),
      ];
      expect(countWaz(qsos), equals(3)); // 5, 25, 14
    });

    test('returns 0 for empty list', () {
      expect(countWaz([]), equals(0));
    });
  });

  group('qsosByBand', () {
    test('counts QSOs per band', () {
      final qsos = [
        _qso('W1AW', '20m'),
        _qso('K3LR', '20m'),
        _qso('VE3ABC', '40m'),
        _qso('JA1ABC', '15m'),
        _qso('DL1ABC', '15m'),
        _qso('SP9ABC', '15m'),
      ];
      final counts = qsosByBand(qsos);
      expect(counts['20m'], equals(2));
      expect(counts['40m'], equals(1));
      expect(counts['15m'], equals(3));
    });

    test('returns empty map for empty list', () {
      expect(qsosByBand([]), isEmpty);
    });
  });
}
