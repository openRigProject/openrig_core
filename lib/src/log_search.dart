/// QSO log search and filtering utilities.
library;

import 'adif.dart';
import 'dxcc.dart';

/// Filter and query QSO log records.
class LogSearch {
  /// Filter QSOs by any combination of criteria.
  ///
  /// - [callsign]: case-insensitive prefix match on [QsoRecord.call]
  /// - [band]: exact match on [QsoRecord.band]
  /// - [mode]: exact match on [QsoRecord.mode]
  /// - [from]: inclusive lower bound on [QsoRecord.timeOn]
  /// - [to]: inclusive upper bound on [QsoRecord.timeOn]
  /// - [dxcc]: exact match on lookupDxcc(record.call)
  static List<QsoRecord> filter(
    List<QsoRecord> log, {
    String? callsign,
    String? band,
    String? mode,
    DateTime? from,
    DateTime? to,
    String? dxcc,
  }) {
    final callUpper = callsign?.toUpperCase();
    return log.where((qso) {
      if (callUpper != null &&
          !qso.call.toUpperCase().startsWith(callUpper)) {
        return false;
      }
      if (band != null && qso.band != band) return false;
      if (mode != null && qso.mode != mode) return false;
      if (from != null && qso.timeOn.isBefore(from)) return false;
      if (to != null && qso.timeOn.isAfter(to)) return false;
      if (dxcc != null && lookupDxcc(qso.call) != dxcc) return false;
      return true;
    }).toList();
  }

  /// Return all unique callsigns worked (uppercase).
  static Set<String> workedCallsigns(List<QsoRecord> log) {
    return log.map((qso) => qso.call.toUpperCase()).toSet();
  }

  /// Return all unique (callsign, band, mode) combos worked.
  static Set<(String callsign, String band, String mode)> workedCombos(
      List<QsoRecord> log) {
    return log
        .map((qso) => (qso.call.toUpperCase(), qso.band, qso.mode))
        .toSet();
  }
}
