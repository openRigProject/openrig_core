import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

QsoRecord _qso({
  String call = 'W1AW',
  String band = '20m',
  String mode = 'SSB',
}) =>
    QsoRecord(
      call: call,
      band: band,
      mode: mode,
      freqMhz: 14.2,
      timeOn: DateTime.utc(2025, 6, 1, 12, 0),
    );

void main() {
  group('DuplicateChecker', () {
    test('empty log returns no duplicates', () {
      final checker = DuplicateChecker([]);
      expect(checker.isWorked('W1AW'), isFalse);
      expect(checker.isWorkedOnBand('W1AW', '20m'), isFalse);
      expect(checker.isWorkedOnBandMode('W1AW', '20m', 'SSB'), isFalse);
      expect(checker.previousQsos('W1AW'), isEmpty);
    });

    test('single QSO is found', () {
      final checker = DuplicateChecker([_qso()]);
      expect(checker.isWorked('W1AW'), isTrue);
      expect(checker.isWorkedOnBand('W1AW', '20m'), isTrue);
      expect(checker.isWorkedOnBandMode('W1AW', '20m', 'SSB'), isTrue);
    });

    test('case-insensitive callsign matching', () {
      final checker = DuplicateChecker([_qso(call: 'W1AW')]);
      expect(checker.isWorked('w1aw'), isTrue);
      expect(checker.isWorkedOnBand('w1Aw', '20m'), isTrue);
      expect(checker.isWorkedOnBandMode('W1aw', '20m', 'SSB'), isTrue);
    });

    test('different band is not a band duplicate', () {
      final checker = DuplicateChecker([_qso(band: '20m')]);
      expect(checker.isWorked('W1AW'), isTrue);
      expect(checker.isWorkedOnBand('W1AW', '40m'), isFalse);
      expect(checker.isWorkedOnBandMode('W1AW', '40m', 'SSB'), isFalse);
    });

    test('different mode is not a band-mode duplicate', () {
      final checker = DuplicateChecker([_qso(mode: 'SSB')]);
      expect(checker.isWorkedOnBandMode('W1AW', '20m', 'CW'), isFalse);
      expect(checker.isWorkedOnBand('W1AW', '20m'), isTrue);
    });

    test('previousQsos returns all QSOs with that callsign', () {
      final log = [
        _qso(call: 'W1AW', band: '20m'),
        _qso(call: 'W1AW', band: '40m'),
        _qso(call: 'VE3ABC'),
      ];
      final checker = DuplicateChecker(log);
      expect(checker.previousQsos('W1AW'), hasLength(2));
      expect(checker.previousQsos('VE3ABC'), hasLength(1));
      expect(checker.previousQsos('K5XYZ'), isEmpty);
    });

    test('previousQsos returns unmodifiable list', () {
      final checker = DuplicateChecker([_qso()]);
      final qsos = checker.previousQsos('W1AW');
      expect(() => qsos.add(_qso()), throwsUnsupportedError);
    });

    test('addQso updates the index', () {
      final checker = DuplicateChecker([]);
      expect(checker.isWorked('W1AW'), isFalse);

      checker.addQso(_qso(call: 'W1AW', band: '20m', mode: 'FT8'));
      expect(checker.isWorked('W1AW'), isTrue);
      expect(checker.isWorkedOnBand('W1AW', '20m'), isTrue);
      expect(checker.isWorkedOnBandMode('W1AW', '20m', 'FT8'), isTrue);
      expect(checker.previousQsos('W1AW'), hasLength(1));
    });

    test('addQso accumulates with existing entries', () {
      final checker = DuplicateChecker([_qso(call: 'W1AW', band: '20m')]);
      checker.addQso(_qso(call: 'W1AW', band: '40m'));
      expect(checker.previousQsos('W1AW'), hasLength(2));
      expect(checker.isWorkedOnBand('W1AW', '20m'), isTrue);
      expect(checker.isWorkedOnBand('W1AW', '40m'), isTrue);
    });

    test('multiple callsigns indexed independently', () {
      final checker = DuplicateChecker([
        _qso(call: 'W1AW', band: '20m'),
        _qso(call: 'VE3ABC', band: '40m'),
      ]);
      expect(checker.isWorkedOnBand('W1AW', '20m'), isTrue);
      expect(checker.isWorkedOnBand('W1AW', '40m'), isFalse);
      expect(checker.isWorkedOnBand('VE3ABC', '40m'), isTrue);
      expect(checker.isWorkedOnBand('VE3ABC', '20m'), isFalse);
    });
  });
}
