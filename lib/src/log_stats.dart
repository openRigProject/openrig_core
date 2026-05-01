/// Log statistics computed from a list of QSO records.
///
/// Provides DXCC entity count, WAS (Worked All States), WAZ (Worked All Zones),
/// and per-band QSO counts.
library;

import 'adif.dart';
import 'dxcc.dart';

/// Count unique DXCC entities worked.
int countDxcc(List<QsoRecord> qsos) {
  final entities = <String>{};
  for (final qso in qsos) {
    final entity = lookupDxccOrNull(qso.call);
    if (entity != null) entities.add(entity);
  }
  return entities.length;
}

/// Count unique US states worked (from ADIF STATE field).
int countWas(List<QsoRecord> qsos) {
  final states = <String>{};
  for (final qso in qsos) {
    final state = qso.extra['STATE'];
    if (state != null && state.isNotEmpty) {
      states.add(state.toUpperCase());
    }
  }
  return states.length;
}

/// Count unique CQ WAZ zones worked (from ADIF CQZ field).
int countWaz(List<QsoRecord> qsos) {
  final zones = <String>{};
  for (final qso in qsos) {
    final zone = qso.extra['CQZ'];
    if (zone != null && zone.isNotEmpty) {
      zones.add(zone);
    }
  }
  return zones.length;
}

/// Count QSOs by band. Returns a map of band name to count.
Map<String, int> qsosByBand(List<QsoRecord> qsos) {
  final counts = <String, int>{};
  for (final qso in qsos) {
    counts[qso.band] = (counts[qso.band] ?? 0) + 1;
  }
  return counts;
}
