import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

DxSpot _spot({
  String dxCall = 'JA1ABC',
  double frequencyKhz = 14074.0, // 20m Digital (FT8)
}) =>
    DxSpot(
      spotter: 'W3LPL',
      dxCall: dxCall,
      frequencyKhz: frequencyKhz,
      comment: 'FT8',
      time: DateTime.utc(2025, 6, 1, 14, 23),
    );

QsoRecord _qso({
  String call = 'JA1ABC',
  String band = '20m',
  String mode = 'Digital',
}) =>
    QsoRecord(
      call: call,
      band: band,
      mode: mode,
      freqMhz: 14.074,
      timeOn: DateTime.utc(2025, 6, 1, 12, 0),
    );

void main() {
  group('ClusterFilter', () {
    test('default filter passes everything', () {
      final filter = ClusterFilter();
      expect(filter.passes(_spot()), isTrue);
      expect(filter.passes(_spot(frequencyKhz: 7074.0)), isTrue);
    });

    test('band filter passes matching band', () {
      final filter = ClusterFilter(bands: ['20m']);
      expect(filter.passes(_spot(frequencyKhz: 14074.0)), isTrue);
      expect(filter.passes(_spot(frequencyKhz: 7074.0)), isFalse);
    });

    test('band filter with multiple bands', () {
      final filter = ClusterFilter(bands: ['20m', '40m']);
      expect(filter.passes(_spot(frequencyKhz: 14074.0)), isTrue);
      expect(filter.passes(_spot(frequencyKhz: 7074.0)), isTrue);
      expect(filter.passes(_spot(frequencyKhz: 21074.0)), isFalse);
    });

    test('band filter rejects unknown frequency', () {
      final filter = ClusterFilter(bands: ['20m']);
      expect(filter.passes(_spot(frequencyKhz: 99999.0)), isFalse);
    });

    test('mode filter passes matching mode', () {
      final filter = ClusterFilter(modes: ['Digital']);
      // 14074 kHz = 20m Digital sub-band
      expect(filter.passes(_spot(frequencyKhz: 14074.0)), isTrue);
      // 14225 kHz = 20m SSB sub-band
      expect(filter.passes(_spot(frequencyKhz: 14225.0)), isFalse);
    });

    test('mode filter is case-insensitive', () {
      final filter = ClusterFilter(modes: ['digital']);
      expect(filter.passes(_spot(frequencyKhz: 14074.0)), isTrue);
    });

    test('mode filter rejects spot with no sub-band match', () {
      final filter = ClusterFilter(modes: ['SSB']);
      // Out-of-band frequency has no sub-band
      expect(filter.passes(_spot(frequencyKhz: 99999.0)), isFalse);
    });

    test('neededOnly filters worked band+mode dupes', () {
      final checker = DuplicateChecker([_qso(call: 'JA1ABC', band: '20m', mode: 'Digital')]);
      final filter = ClusterFilter(neededOnly: true, dupeChecker: checker);
      // JA1ABC already worked on 20m Digital
      expect(filter.passes(_spot(dxCall: 'JA1ABC', frequencyKhz: 14074.0)), isFalse);
      // JA1ABC on 40m Digital is not a dupe
      expect(filter.passes(_spot(dxCall: 'JA1ABC', frequencyKhz: 7074.0)), isTrue);
      // Different callsign passes
      expect(filter.passes(_spot(dxCall: 'VE3XYZ', frequencyKhz: 14074.0)), isTrue);
    });

    test('newBandOnly filters worked-on-band dupes', () {
      final checker = DuplicateChecker([_qso(call: 'JA1ABC', band: '20m', mode: 'Digital')]);
      final filter = ClusterFilter(newBandOnly: true, dupeChecker: checker);
      // JA1ABC already worked on 20m (any mode)
      expect(filter.passes(_spot(dxCall: 'JA1ABC', frequencyKhz: 14225.0)), isFalse);
      // JA1ABC on 40m is new band
      expect(filter.passes(_spot(dxCall: 'JA1ABC', frequencyKhz: 7074.0)), isTrue);
    });

    test('dupe filters ignored without dupeChecker', () {
      final filter = ClusterFilter(neededOnly: true, newBandOnly: true);
      expect(filter.passes(_spot()), isTrue);
    });

    test('combined band + neededOnly filter', () {
      final checker = DuplicateChecker([_qso(call: 'JA1ABC', band: '20m', mode: 'Digital')]);
      final filter = ClusterFilter(
        bands: ['20m'],
        neededOnly: true,
        dupeChecker: checker,
      );
      // 20m Digital dupe -- fails neededOnly
      expect(filter.passes(_spot(dxCall: 'JA1ABC', frequencyKhz: 14074.0)), isFalse);
      // 20m SSB not a dupe
      expect(filter.passes(_spot(dxCall: 'JA1ABC', frequencyKhz: 14225.0)), isTrue);
      // 40m filtered out by band filter
      expect(filter.passes(_spot(dxCall: 'VE3XYZ', frequencyKhz: 7074.0)), isFalse);
    });

    test('copyWith creates modified copy', () {
      final original = ClusterFilter(bands: ['20m'], neededOnly: true);
      final modified = original.copyWith(bands: ['40m'], neededOnly: false);

      expect(modified.bands, equals(['40m']));
      expect(modified.neededOnly, isFalse);
      // Unmodified fields preserved
      expect(modified.modes, isEmpty);
      expect(modified.newBandOnly, isFalse);
    });

    test('copyWith preserves unset fields', () {
      final checker = DuplicateChecker([]);
      final original = ClusterFilter(
        bands: ['20m'],
        modes: ['CW'],
        neededOnly: true,
        newBandOnly: true,
        dupeChecker: checker,
      );
      final modified = original.copyWith(bands: ['40m']);
      expect(modified.modes, equals(['CW']));
      expect(modified.neededOnly, isTrue);
      expect(modified.newBandOnly, isTrue);
      expect(modified.dupeChecker, same(checker));
    });
  });
}
