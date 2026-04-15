/// ADIF (Amateur Data Interchange Format) log read/write.
///
/// ADIF is the de facto standard for QSO log interchange.
/// Used by LoTW, QRZ Logbook, Club Log, and virtually all logging software.
///
/// Spec: https://adif.org/
library;

/// A single QSO log entry.
class QsoRecord {
  final String call;         // Contacted station callsign
  final String band;         // Band (e.g. '20m', '40m')
  final String mode;         // Mode (e.g. 'SSB', 'CW', 'FT8')
  final double freqMhz;      // Frequency in MHz
  final DateTime timeOn;     // QSO start (UTC)
  final DateTime? timeOff;   // QSO end (UTC), optional
  final String? rstSent;     // RST sent
  final String? rstRcvd;     // RST received
  final String? name;        // Operator name
  final String? gridsquare;  // Maidenhead grid square
  final String? comment;     // Free-text comment
  final Map<String, String> extra; // Any additional ADIF fields

  const QsoRecord({
    required this.call,
    required this.band,
    required this.mode,
    required this.freqMhz,
    required this.timeOn,
    this.timeOff,
    this.rstSent,
    this.rstRcvd,
    this.name,
    this.gridsquare,
    this.comment,
    this.extra = const {},
  });

  // TODO: implement toAdif() and fromAdif() serialization
}

/// Read/write ADIF log files.
class AdifLog {
  // TODO: implement parse(String adif) → List<QsoRecord>
  // TODO: implement encode(List<QsoRecord>) → String
  // TODO: implement appendRecord(String path, QsoRecord) for live logging
}
