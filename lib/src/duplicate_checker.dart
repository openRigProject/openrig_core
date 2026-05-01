/// QSO duplicate checking with O(1) lookups.
library;

import 'adif.dart';

/// Fast duplicate checker backed by indexed maps.
class DuplicateChecker {
  /// Callsign (uppercase) -> list of QSOs.
  final Map<String, List<QsoRecord>> _byCall = {};

  /// (callsign, band) -> true.
  final Set<(String, String)> _callBand = {};

  /// (callsign, band, mode) -> true.
  final Set<(String, String, String)> _callBandMode = {};

  DuplicateChecker(List<QsoRecord> log) {
    for (final qso in log) {
      _index(qso);
    }
  }

  /// True if this callsign has been worked on ANY band/mode.
  bool isWorked(String callsign) {
    return _byCall.containsKey(callsign.toUpperCase());
  }

  /// True if worked on this specific band.
  bool isWorkedOnBand(String callsign, String band) {
    return _callBand.contains((callsign.toUpperCase(), band));
  }

  /// True if worked on this specific band AND mode.
  bool isWorkedOnBandMode(String callsign, String band, String mode) {
    return _callBandMode.contains((callsign.toUpperCase(), band, mode));
  }

  /// All previous QSOs with this callsign.
  List<QsoRecord> previousQsos(String callsign) {
    return List.unmodifiable(_byCall[callsign.toUpperCase()] ?? []);
  }

  /// Update the checker with a newly logged QSO.
  void addQso(QsoRecord qso) {
    _index(qso);
  }

  void _index(QsoRecord qso) {
    final call = qso.call.toUpperCase();
    (_byCall[call] ??= []).add(qso);
    _callBand.add((call, qso.band));
    _callBandMode.add((call, qso.band, qso.mode));
  }
}
