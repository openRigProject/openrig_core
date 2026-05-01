import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

QsoRecord _qso({
  String call = 'W1AW',
  String band = '20m',
  String mode = 'SSB',
  DateTime? timeOn,
}) =>
    QsoRecord(
      call: call,
      band: band,
      mode: mode,
      freqMhz: 14.2,
      timeOn: timeOn ?? DateTime.utc(2025, 6, 1, 12, 0),
    );

void main() {
  group('LogSearch.filter', () {
    test('returns all on empty criteria', () {
      final log = [_qso(), _qso(call: 'VE3ABC')];
      expect(LogSearch.filter(log), hasLength(2));
    });

    test('returns empty for empty log', () {
      expect(LogSearch.filter([]), isEmpty);
    });

    test('filters by callsign prefix (case-insensitive)', () {
      final log = [
        _qso(call: 'W1AW'),
        _qso(call: 'W1ABC'),
        _qso(call: 'VE3XYZ'),
      ];
      final result = LogSearch.filter(log, callsign: 'w1');
      expect(result, hasLength(2));
      expect(result.map((q) => q.call), containsAll(['W1AW', 'W1ABC']));
    });

    test('filters by band', () {
      final log = [
        _qso(band: '20m'),
        _qso(band: '40m'),
        _qso(band: '20m'),
      ];
      expect(LogSearch.filter(log, band: '20m'), hasLength(2));
    });

    test('filters by mode', () {
      final log = [
        _qso(mode: 'SSB'),
        _qso(mode: 'FT8'),
        _qso(mode: 'CW'),
      ];
      expect(LogSearch.filter(log, mode: 'FT8'), hasLength(1));
    });

    test('filters by date range (inclusive)', () {
      final log = [
        _qso(timeOn: DateTime.utc(2025, 1, 1)),
        _qso(timeOn: DateTime.utc(2025, 6, 15)),
        _qso(timeOn: DateTime.utc(2025, 12, 31)),
      ];
      final result = LogSearch.filter(
        log,
        from: DateTime.utc(2025, 6, 15),
        to: DateTime.utc(2025, 6, 15),
      );
      expect(result, hasLength(1));
    });

    test('filters by DXCC entity', () {
      final log = [
        _qso(call: 'W1AW'),
        _qso(call: 'VE3ABC'),
        _qso(call: 'K5XYZ'),
      ];
      final result = LogSearch.filter(log, dxcc: 'United States');
      expect(result, hasLength(2));
    });

    test('combines multiple criteria', () {
      final log = [
        _qso(call: 'W1AW', band: '20m', mode: 'SSB'),
        _qso(call: 'W1AW', band: '40m', mode: 'SSB'),
        _qso(call: 'W1AW', band: '20m', mode: 'CW'),
        _qso(call: 'VE3ABC', band: '20m', mode: 'SSB'),
      ];
      final result = LogSearch.filter(log, callsign: 'W1', band: '20m', mode: 'SSB');
      expect(result, hasLength(1));
      expect(result[0].call, equals('W1AW'));
    });
  });

  group('LogSearch.workedCallsigns', () {
    test('returns empty set for empty log', () {
      expect(LogSearch.workedCallsigns([]), isEmpty);
    });

    test('returns unique uppercase callsigns', () {
      final log = [
        _qso(call: 'W1AW'),
        _qso(call: 'w1aw'),
        _qso(call: 'VE3ABC'),
      ];
      final calls = LogSearch.workedCallsigns(log);
      expect(calls, hasLength(2));
      expect(calls, contains('W1AW'));
      expect(calls, contains('VE3ABC'));
    });
  });

  group('LogSearch.workedCombos', () {
    test('returns empty set for empty log', () {
      expect(LogSearch.workedCombos([]), isEmpty);
    });

    test('returns unique (callsign, band, mode) tuples', () {
      final log = [
        _qso(call: 'W1AW', band: '20m', mode: 'SSB'),
        _qso(call: 'W1AW', band: '20m', mode: 'SSB'), // duplicate
        _qso(call: 'W1AW', band: '20m', mode: 'CW'),
        _qso(call: 'W1AW', band: '40m', mode: 'SSB'),
      ];
      final combos = LogSearch.workedCombos(log);
      expect(combos, hasLength(3));
      expect(combos, contains(('W1AW', '20m', 'SSB')));
      expect(combos, contains(('W1AW', '20m', 'CW')));
      expect(combos, contains(('W1AW', '40m', 'SSB')));
    });
  });
}
