import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

DxSpot _spot({
  String dxCall = 'JA1ABC',
  double frequencyKhz = 14074.0,
  DateTime? time,
}) =>
    DxSpot(
      spotter: 'W3LPL',
      dxCall: dxCall,
      frequencyKhz: frequencyKhz,
      comment: 'FT8',
      time: time ?? DateTime.utc(2025, 6, 1, 14, 0),
    );

void main() {
  group('deduplicateSpots', () {
    test('empty list returns empty', () {
      expect(deduplicateSpots([]), isEmpty);
    });

    test('no duplicates returns all', () {
      final spots = [
        _spot(dxCall: 'JA1ABC', frequencyKhz: 14074.0),
        _spot(dxCall: 'VE3XYZ', frequencyKhz: 7074.0),
      ];
      expect(deduplicateSpots(spots), hasLength(2));
    });

    test('exact duplicate keeps newest', () {
      final older = _spot(
        dxCall: 'JA1ABC',
        frequencyKhz: 14074.0,
        time: DateTime.utc(2025, 6, 1, 14, 0),
      );
      final newer = _spot(
        dxCall: 'JA1ABC',
        frequencyKhz: 14074.0,
        time: DateTime.utc(2025, 6, 1, 14, 5),
      );
      final result = deduplicateSpots([older, newer]);
      expect(result, hasLength(1));
      expect(result[0].time, equals(newer.time));
    });

    test('within tolerance treated as duplicate', () {
      final s1 = _spot(dxCall: 'JA1ABC', frequencyKhz: 14074.0,
          time: DateTime.utc(2025, 6, 1, 14, 0));
      final s2 = _spot(dxCall: 'JA1ABC', frequencyKhz: 14074.5,
          time: DateTime.utc(2025, 6, 1, 14, 5));
      expect(deduplicateSpots([s1, s2]), hasLength(1));
    });

    test('outside tolerance treated as separate', () {
      final s1 = _spot(dxCall: 'JA1ABC', frequencyKhz: 14074.0);
      final s2 = _spot(dxCall: 'JA1ABC', frequencyKhz: 14076.0);
      expect(deduplicateSpots([s1, s2]), hasLength(2));
    });

    test('maxAge removes old spots before dedup', () {
      final now = DateTime.utc(2025, 6, 1, 15, 0);
      final fresh = _spot(time: DateTime.utc(2025, 6, 1, 14, 50));
      final stale = _spot(
        dxCall: 'VE3XYZ',
        time: DateTime.utc(2025, 6, 1, 14, 0),
      );
      final result = deduplicateSpots(
        [fresh, stale],
        maxAge: const Duration(minutes: 30),
        now: now,
      );
      expect(result, hasLength(1));
      expect(result[0].dxCall, equals('JA1ABC'));
    });
  });

  group('expireSpots', () {
    test('all fresh spots kept', () {
      final now = DateTime.utc(2025, 6, 1, 15, 0);
      final spots = [
        _spot(time: DateTime.utc(2025, 6, 1, 14, 50)),
        _spot(dxCall: 'VE3XYZ', time: DateTime.utc(2025, 6, 1, 14, 55)),
      ];
      final result = expireSpots(spots, const Duration(minutes: 30), now: now);
      expect(result, hasLength(2));
    });

    test('all expired spots removed', () {
      final now = DateTime.utc(2025, 6, 1, 15, 0);
      final spots = [
        _spot(time: DateTime.utc(2025, 6, 1, 13, 0)),
        _spot(dxCall: 'VE3XYZ', time: DateTime.utc(2025, 6, 1, 13, 30)),
      ];
      final result = expireSpots(spots, const Duration(minutes: 30), now: now);
      expect(result, isEmpty);
    });

    test('mixed: keeps fresh, removes expired', () {
      final now = DateTime.utc(2025, 6, 1, 15, 0);
      final fresh = _spot(time: DateTime.utc(2025, 6, 1, 14, 50));
      final stale = _spot(
        dxCall: 'VE3XYZ',
        time: DateTime.utc(2025, 6, 1, 14, 0),
      );
      final result = expireSpots([fresh, stale], const Duration(minutes: 30),
          now: now);
      expect(result, hasLength(1));
      expect(result[0].dxCall, equals('JA1ABC'));
    });

    test('spot exactly at cutoff is kept', () {
      final now = DateTime.utc(2025, 6, 1, 15, 0);
      final atCutoff = _spot(time: DateTime.utc(2025, 6, 1, 14, 30));
      final result = expireSpots([atCutoff], const Duration(minutes: 30),
          now: now);
      expect(result, hasLength(1));
    });
  });

  group('mergeSpot', () {
    test('into empty list returns single-element list', () {
      final spot = _spot();
      final result = mergeSpot([], spot);
      expect(result, hasLength(1));
      expect(result[0], same(spot));
    });

    test('new callsign prepended without removing existing', () {
      final existing = [_spot(dxCall: 'VE3XYZ')];
      final newSpot = _spot(dxCall: 'JA1ABC');
      final result = mergeSpot(existing, newSpot);
      expect(result, hasLength(2));
      expect(result[0].dxCall, equals('JA1ABC'));
      expect(result[1].dxCall, equals('VE3XYZ'));
    });

    test('replaces duplicate (same call, within tolerance)', () {
      final existing = [
        _spot(dxCall: 'JA1ABC', frequencyKhz: 14074.0),
        _spot(dxCall: 'VE3XYZ', frequencyKhz: 7074.0),
      ];
      final updated = _spot(
        dxCall: 'JA1ABC',
        frequencyKhz: 14074.5,
        time: DateTime.utc(2025, 6, 1, 15, 0),
      );
      final result = mergeSpot(existing, updated);
      expect(result, hasLength(2));
      expect(result[0].dxCall, equals('JA1ABC'));
      expect(result[0].time, equals(DateTime.utc(2025, 6, 1, 15, 0)));
      expect(result[1].dxCall, equals('VE3XYZ'));
    });

    test('different freq same call not replaced (outside tolerance)', () {
      final existing = [
        _spot(dxCall: 'JA1ABC', frequencyKhz: 14074.0),
      ];
      final newSpot = _spot(dxCall: 'JA1ABC', frequencyKhz: 7074.0);
      final result = mergeSpot(existing, newSpot);
      expect(result, hasLength(2));
    });
  });
}
