/// QRZ.com Logbook API client.
///
/// Uploads QSOs to QRZ.com logbook via their HTTPS API.
/// See: https://www.qrz.com/docs/logbook/QRZLogbookAPI.html
library;

import 'package:http/http.dart' as http;

import 'adif.dart';

/// Exception thrown on QRZ API failures.
class QrzException implements Exception {
  final String message;
  const QrzException(this.message);

  @override
  String toString() => 'QrzException: $message';
}

/// Result of inserting a single QSO into QRZ logbook.
class QrzInsertResult {
  final QsoRecord qso;
  final String? logId;
  final String? error;

  const QrzInsertResult({required this.qso, this.logId, this.error});

  bool get success => logId != null;
}

/// Client for the QRZ.com Logbook API.
class QrzLogbookClient {
  final String _apiKey;
  final http.Client _http;
  final bool _ownedClient;

  static final Uri _endpoint = Uri.parse('https://logbook.qrz.com/api');

  QrzLogbookClient({required String apiKey, http.Client? httpClient})
      : _apiKey = apiKey,
        _http = httpClient ?? http.Client(),
        _ownedClient = httpClient == null;

  /// Check that the API key is valid. Returns the callsign associated with it.
  Future<String> checkKey() async {
    final resp = await _post({'ACTION': 'STATUS'});
    return resp['CALLSIGN'] ?? resp['STATION_CALLSIGN'] ?? '';
  }

  /// Upload a single QSO. Returns the QRZ log ID on success.
  Future<String> insertQso(QsoRecord qso) async {
    final resp = await _post({'ACTION': 'INSERT', 'ADIF': qso.toAdif()});
    return resp['LOGID'] ?? '';
  }

  /// Upload multiple QSOs. Returns a result per QSO (never throws).
  Future<List<QrzInsertResult>> insertQsos(List<QsoRecord> qsos) async {
    final results = <QrzInsertResult>[];
    for (final qso in qsos) {
      try {
        final logId = await insertQso(qso);
        results.add(QrzInsertResult(qso: qso, logId: logId));
      } on QrzException catch (e) {
        results.add(QrzInsertResult(qso: qso, error: e.message));
      }
    }
    return results;
  }

  void dispose() {
    if (_ownedClient) _http.close();
  }

  Future<Map<String, String>> _post(Map<String, String> fields) async {
    final body = {'KEY': _apiKey, ...fields};
    final resp = await _http.post(_endpoint, body: body);
    final parsed = _parseResponse(resp.body);

    final result = parsed['RESULT'];
    if (result == null || result != 'OK') {
      throw QrzException(parsed['REASON'] ?? 'Unknown error');
    }
    return parsed;
  }

  Map<String, String> _parseResponse(String body) {
    final map = <String, String>{};
    for (final line in body.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Handle both "KEY=VALUE" and "KEY=VALUE with = signs"
      final eq = trimmed.indexOf('=');
      if (eq < 0) continue;
      map[trimmed.substring(0, eq)] = trimmed.substring(eq + 1);
    }
    return map;
  }
}
