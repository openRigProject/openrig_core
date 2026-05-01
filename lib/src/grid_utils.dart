/// Maidenhead grid square utilities.
library;

import 'dart:math';

/// Regex for a valid 4-character grid square.
final _grid4Regex = RegExp(r'^[A-R]{2}[0-9]{2}$', caseSensitive: false);

/// Regex for a valid 6-character grid square.
final _grid6Regex = RegExp(r'^[A-R]{2}[0-9]{2}[A-X]{2}$', caseSensitive: false);

/// Returns true if the grid square string is valid (4 or 6 chars).
bool isValidGrid(String grid) {
  final g = grid.trim();
  return _grid4Regex.hasMatch(g) || _grid6Regex.hasMatch(g);
}

/// Convert lat/lon (degrees) to a 4-character Maidenhead grid square.
String latLonToGrid(double lat, double lon) {
  final adjLon = lon + 180.0;
  final adjLat = lat + 90.0;

  final field1 = String.fromCharCode(65 + (adjLon / 20.0).floor());
  final field2 = String.fromCharCode(65 + (adjLat / 10.0).floor());
  final sq1 = ((adjLon % 20.0) / 2.0).floor();
  final sq2 = (adjLat % 10.0).floor();

  return '$field1$field2$sq1$sq2';
}

/// Convert lat/lon to a 6-character grid square.
String latLonToGrid6(double lat, double lon) {
  final adjLon = lon + 180.0;
  final adjLat = lat + 90.0;

  final field1 = String.fromCharCode(65 + (adjLon / 20.0).floor());
  final field2 = String.fromCharCode(65 + (adjLat / 10.0).floor());
  final sq1 = ((adjLon % 20.0) / 2.0).floor();
  final sq2 = (adjLat % 10.0).floor();
  final sub1 = String.fromCharCode(
      97 + (((adjLon % 20.0) % 2.0) / (2.0 / 24.0)).floor().clamp(0, 23));
  final sub2 = String.fromCharCode(
      97 + ((adjLat % 10.0 % 1.0) / (1.0 / 24.0)).floor().clamp(0, 23));

  return '$field1$field2$sq1$sq2$sub1$sub2';
}

/// Convert a 4- or 6-character grid square to center lat/lon.
({double lat, double lon})? gridToLatLon(String grid) {
  final g = grid.trim().toUpperCase();
  if (!isValidGrid(g)) return null;

  final lon0 = (g.codeUnitAt(0) - 65) * 20.0 - 180.0;
  final lat0 = (g.codeUnitAt(1) - 65) * 10.0 - 90.0;
  final lon1 = lon0 + int.parse(g[2]) * 2.0;
  final lat1 = lat0 + int.parse(g[3]) * 1.0;

  if (g.length == 6) {
    final lonSub = (g.codeUnitAt(4) - 65) * (2.0 / 24.0);
    final latSub = (g.codeUnitAt(5) - 65) * (1.0 / 24.0);
    return (
      lat: lat1 + latSub + (1.0 / 48.0),
      lon: lon1 + lonSub + (1.0 / 24.0),
    );
  }

  // 4-char: center of the square
  return (lat: lat1 + 0.5, lon: lon1 + 1.0);
}

/// Distance in km between two grid squares (Haversine, center to center).
double? gridDistance(String grid1, String grid2) {
  final p1 = gridToLatLon(grid1);
  final p2 = gridToLatLon(grid2);
  if (p1 == null || p2 == null) return null;
  return _haversineKm(p1.lat, p1.lon, p2.lat, p2.lon);
}

/// Bearing in degrees (0-360) from grid1 to grid2.
double? gridBearing(String grid1, String grid2) {
  final p1 = gridToLatLon(grid1);
  final p2 = gridToLatLon(grid2);
  if (p1 == null || p2 == null) return null;
  return _bearing(p1.lat, p1.lon, p2.lat, p2.lon);
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0; // Earth radius in km
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _bearing(double lat1, double lon1, double lat2, double lon2) {
  final dLon = _toRad(lon2 - lon1);
  final y = sin(dLon) * cos(_toRad(lat2));
  final x = cos(_toRad(lat1)) * sin(_toRad(lat2)) -
      sin(_toRad(lat1)) * cos(_toRad(lat2)) * cos(dLon);
  return (_toDeg(atan2(y, x)) + 360) % 360;
}

double _toRad(double deg) => deg * pi / 180.0;
double _toDeg(double rad) => rad * 180.0 / pi;
