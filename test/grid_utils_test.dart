import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

void main() {
  group('isValidGrid', () {
    test('accepts valid 4-char grids', () {
      expect(isValidGrid('FN31'), isTrue);
      expect(isValidGrid('JO22'), isTrue);
      expect(isValidGrid('AA00'), isTrue);
      expect(isValidGrid('RR99'), isTrue);
    });

    test('accepts valid 6-char grids', () {
      expect(isValidGrid('FN31pr'), isTrue);
      expect(isValidGrid('JO22ab'), isTrue);
    });

    test('is case-insensitive', () {
      expect(isValidGrid('fn31'), isTrue);
      expect(isValidGrid('FN31PR'), isTrue);
    });

    test('rejects invalid grids', () {
      expect(isValidGrid(''), isFalse);
      expect(isValidGrid('AB'), isFalse);
      expect(isValidGrid('FN3'), isFalse);
      expect(isValidGrid('FN31p'), isFalse); // 5 chars
      expect(isValidGrid('ZZ00'), isFalse); // Z > R
      expect(isValidGrid('FN31pz'), isFalse); // z > x
      expect(isValidGrid('12AB'), isFalse); // digits first
    });
  });

  group('latLonToGrid', () {
    test('ARRL HQ (Newington, CT) -> FN31', () {
      // ~41.7°N, 72.7°W
      expect(latLonToGrid(41.7, -72.7), equals('FN31'));
    });

    test('London -> JO01 or IO91', () {
      // ~51.5°N, 0.0°W
      final grid = latLonToGrid(51.5, -0.1);
      expect(grid, equals('IO91'));
    });

    test('Tokyo -> PM95', () {
      final grid = latLonToGrid(35.68, 139.77);
      expect(grid, equals('PM95'));
    });
  });

  group('latLonToGrid6', () {
    test('ARRL HQ -> FN31pr area', () {
      final grid = latLonToGrid6(41.71, -72.73);
      expect(grid.length, equals(6));
      expect(grid.substring(0, 4), equals('FN31'));
    });

    test('origin (0, 0) -> JJ00aa', () {
      final grid = latLonToGrid6(0.0, 0.0);
      expect(grid, equals('JJ00aa'));
    });
  });

  group('gridToLatLon', () {
    test('FN31 returns center of grid square', () {
      final pos = gridToLatLon('FN31');
      expect(pos, isNotNull);
      // FN31: lon = -73 to -71, lat = 41 to 42 -> center (-72, 41.5)
      expect(pos!.lat, closeTo(41.5, 0.5));
      expect(pos.lon, closeTo(-72.0, 1.0));
    });

    test('6-char grid returns center of sub-square', () {
      final pos = gridToLatLon('FN31pr');
      expect(pos, isNotNull);
      expect(pos!.lat, closeTo(41.7, 0.1));
      expect(pos.lon, closeTo(-72.7, 0.2));
    });

    test('returns null for invalid grid', () {
      expect(gridToLatLon('ZZZZZ'), isNull);
      expect(gridToLatLon(''), isNull);
    });

    test('is case-insensitive', () {
      final p1 = gridToLatLon('FN31');
      final p2 = gridToLatLon('fn31');
      expect(p1, isNotNull);
      expect(p2, isNotNull);
      expect(p1!.lat, equals(p2!.lat));
      expect(p1.lon, equals(p2.lon));
    });
  });

  group('gridDistance', () {
    test('FN31 to JO01 is roughly transatlantic', () {
      final km = gridDistance('FN31', 'JO01');
      expect(km, isNotNull);
      // Newington CT to London ~5500 km
      expect(km!, closeTo(5500, 500));
    });

    test('same grid returns ~0', () {
      final km = gridDistance('FN31', 'FN31');
      expect(km, isNotNull);
      expect(km!, closeTo(0, 1));
    });

    test('returns null for invalid grid', () {
      expect(gridDistance('FN31', 'ZZZZ'), isNull);
      expect(gridDistance('ZZZZ', 'FN31'), isNull);
    });
  });

  group('gridBearing', () {
    test('FN31 to JO01 is roughly east-northeast', () {
      final bearing = gridBearing('FN31', 'JO01');
      expect(bearing, isNotNull);
      // ~50-70 degrees
      expect(bearing!, closeTo(60, 15));
    });

    test('returns null for invalid grid', () {
      expect(gridBearing('FN31', 'ZZZZ'), isNull);
    });

    test('bearing is between 0 and 360', () {
      final b = gridBearing('FN31', 'PM95');
      expect(b, isNotNull);
      expect(b!, greaterThanOrEqualTo(0));
      expect(b, lessThan(360));
    });
  });
}
