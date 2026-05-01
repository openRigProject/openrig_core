/// ADIF (Amateur Data Interchange Format) log read/write.
///
/// ADIF is the de facto standard for QSO log interchange.
/// Used by LoTW, QRZ Logbook, Club Log, and virtually all logging software.
///
/// Spec: https://adif.org/
library;

import 'dart:io';

/// Regex to match ADIF field tags: <FIELD_NAME:LENGTH[:TYPE]>VALUE
final _fieldRegex = RegExp(r'<([^:>]+):(\d+)(?::[^>]*)?>');

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
  final String? mySotaRef;   // MY_SOTA_REF — operator's summit (e.g. "W7W/KG-001")
  final String? sotaRef;     // SOTA_REF — contacted station's summit
  final String? myPotaRef;   // MY_POTA_REF — operator's park (e.g. "K-0001")
  final String? potaRef;     // POTA_REF — contacted station's park (comma-separated for multiple)
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
    this.mySotaRef,
    this.sotaRef,
    this.myPotaRef,
    this.potaRef,
    this.extra = const {},
  });

  /// Serialize this record to an ADIF record string (one line, ends with <EOR>).
  String toAdif() {
    final buf = StringBuffer();

    void writeField(String name, String value) {
      buf.write('<$name:${value.length}>$value');
    }

    writeField('CALL', call);
    writeField('BAND', band);
    writeField('MODE', mode);
    writeField('FREQ', freqMhz.toStringAsFixed(6));
    writeField('QSO_DATE', _formatDate(timeOn));
    writeField('TIME_ON', _formatTime(timeOn));
    if (timeOff != null) {
      writeField('QSO_DATE_OFF', _formatDate(timeOff!));
      writeField('TIME_OFF', _formatTime(timeOff!));
    }
    if (rstSent != null) writeField('RST_SENT', rstSent!);
    if (rstRcvd != null) writeField('RST_RCVD', rstRcvd!);
    if (name != null) writeField('NAME', name!);
    if (gridsquare != null) writeField('GRIDSQUARE', gridsquare!);
    if (comment != null) writeField('COMMENT', comment!);
    if (mySotaRef != null && mySotaRef!.isNotEmpty) {
      writeField('MY_SOTA_REF', mySotaRef!);
    }
    if (sotaRef != null && sotaRef!.isNotEmpty) {
      writeField('SOTA_REF', sotaRef!);
    }
    if (myPotaRef != null && myPotaRef!.isNotEmpty) {
      writeField('MY_POTA_REF', myPotaRef!);
    }
    if (potaRef != null && potaRef!.isNotEmpty) {
      writeField('POTA_REF', potaRef!);
    }
    for (final e in extra.entries) {
      writeField(e.key.toUpperCase(), e.value);
    }

    buf.write('<EOR>');
    return buf.toString();
  }

  /// Parse a map of ADIF fields (uppercase keys) into a QsoRecord.
  /// Returns null if required fields are missing.
  static QsoRecord? fromFields(Map<String, String> fields) {
    final call = fields['CALL'];
    final band = fields['BAND'];
    final mode = fields['MODE'];
    final freqStr = fields['FREQ'];
    final dateStr = fields['QSO_DATE'];
    final timeStr = fields['TIME_ON'];

    if (call == null || band == null || mode == null ||
        freqStr == null || dateStr == null || timeStr == null) {
      return null;
    }

    final freq = double.tryParse(freqStr);
    if (freq == null) return null;

    final timeOn = _parseDateTime(dateStr, timeStr);
    if (timeOn == null) return null;

    DateTime? timeOff;
    final dateOffStr = fields['QSO_DATE_OFF'] ?? dateStr;
    final timeOffStr = fields['TIME_OFF'];
    if (timeOffStr != null) {
      timeOff = _parseDateTime(dateOffStr, timeOffStr);
    }

    // Collect extra fields not handled by named properties
    const knownFields = {
      'CALL', 'BAND', 'MODE', 'FREQ', 'QSO_DATE', 'TIME_ON',
      'QSO_DATE_OFF', 'TIME_OFF', 'RST_SENT', 'RST_RCVD',
      'NAME', 'GRIDSQUARE', 'COMMENT',
      'MY_SOTA_REF', 'SOTA_REF', 'MY_POTA_REF', 'POTA_REF',
    };
    final extra = Map.fromEntries(
      fields.entries.where((e) => !knownFields.contains(e.key)),
    );

    return QsoRecord(
      call: call,
      band: band,
      mode: mode,
      freqMhz: freq,
      timeOn: timeOn,
      timeOff: timeOff,
      rstSent: fields['RST_SENT'],
      rstRcvd: fields['RST_RCVD'],
      name: fields['NAME'],
      gridsquare: fields['GRIDSQUARE'],
      comment: fields['COMMENT'],
      mySotaRef: fields['MY_SOTA_REF'],
      sotaRef: fields['SOTA_REF'],
      myPotaRef: fields['MY_POTA_REF'],
      potaRef: fields['POTA_REF'],
      extra: extra,
    );
  }
}

/// Read/write ADIF log files.
class AdifLog {
  /// Parse an ADIF string into a list of QSO records.
  static List<QsoRecord> parse(String adif) {
    // Skip the header (everything before <EOH>)
    var body = adif;
    final eohIndex = adif.toUpperCase().indexOf('<EOH>');
    if (eohIndex >= 0) {
      body = adif.substring(eohIndex + 5);
    }

    final records = <QsoRecord>[];

    // Split on <EOR> to get individual record strings
    final parts = body.toUpperCase().indexOf('<EOR>') >= 0
        ? _splitOnEor(body)
        : <String>[];

    for (final part in parts) {
      final fields = _parseFields(part);
      if (fields.isEmpty) continue;
      final record = QsoRecord.fromFields(fields);
      if (record != null) records.add(record);
    }

    return records;
  }

  /// Encode a list of QSO records to an ADIF string.
  static String encode(List<QsoRecord> records, {String? header}) {
    final buf = StringBuffer();

    // Write header
    buf.writeln(header ?? 'openRig ADIF Export');
    buf.writeln('<ADIF_VER:5>3.1.4');
    buf.writeln('<PROGRAMID:7>openRig');
    buf.writeln('<EOH>');
    buf.writeln();

    for (final record in records) {
      buf.writeln(record.toAdif());
    }

    return buf.toString();
  }

  /// Append a single QSO record to an existing ADIF file.
  /// Creates the file with a header if it doesn't exist.
  static Future<void> appendRecord(String path, QsoRecord record) async {
    final file = File(path);
    if (!await file.exists()) {
      await file.writeAsString(encode([record]));
    } else {
      await file.writeAsString('${record.toAdif()}\n', mode: FileMode.append);
    }
  }
}

/// Split body text on <EOR> markers (case-insensitive).
List<String> _splitOnEor(String body) {
  final results = <String>[];
  final upper = body.toUpperCase();
  var start = 0;
  while (true) {
    final idx = upper.indexOf('<EOR>', start);
    if (idx < 0) break;
    results.add(body.substring(start, idx));
    start = idx + 5;
  }
  return results;
}

/// Parse ADIF fields from a record string into an uppercase-keyed map.
Map<String, String> _parseFields(String recordStr) {
  final fields = <String, String>{};
  for (final match in _fieldRegex.allMatches(recordStr)) {
    final name = match.group(1)!.toUpperCase();
    final len = int.tryParse(match.group(2)!) ?? 0;
    final valueStart = match.end;
    if (valueStart + len <= recordStr.length) {
      fields[name] = recordStr.substring(valueStart, valueStart + len);
    }
  }
  return fields;
}

/// Format a DateTime as ADIF date string: YYYYMMDD
String _formatDate(DateTime dt) {
  return '${dt.year.toString().padLeft(4, '0')}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}';
}

/// Format a DateTime as ADIF time string: HHMMSS
String _formatTime(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '${dt.second.toString().padLeft(2, '0')}';
}

/// Parse ADIF date (YYYYMMDD) and time (HHMM or HHMMSS) into a DateTime (UTC).
DateTime? _parseDateTime(String date, String time) {
  if (date.length != 8) return null;
  final year = int.tryParse(date.substring(0, 4));
  final month = int.tryParse(date.substring(4, 6));
  final day = int.tryParse(date.substring(6, 8));
  if (year == null || month == null || day == null) return null;

  final hour = time.length >= 2 ? int.tryParse(time.substring(0, 2)) : null;
  final minute = time.length >= 4 ? int.tryParse(time.substring(2, 4)) : null;
  final second = time.length >= 6 ? int.tryParse(time.substring(4, 6)) : null;
  if (hour == null || minute == null) return null;

  return DateTime.utc(year, month, day, hour, minute, second ?? 0);
}
