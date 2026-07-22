import 'dart:convert';

import 'package:http/http.dart' as http;

class AprsStation {
  final String callsign;
  final String comment;
  final String path;
  final String symbol;
  final double lat;
  final double lng;
  final double? altitude;
  final double? course;
  final double? speed;
  final DateTime lastTime;

  const AprsStation({
    required this.callsign,
    required this.comment,
    required this.path,
    required this.symbol,
    required this.lat,
    required this.lng,
    this.altitude,
    this.course,
    this.speed,
    required this.lastTime,
  });

  factory AprsStation.fromJson(Map<String, dynamic> j) {
    return AprsStation(
      callsign: (j['name'] as String? ?? '').toUpperCase(),
      comment: j['comment'] as String? ?? '',
      path: j['path'] as String? ?? '',
      symbol: j['symbol'] as String? ?? '',
      lat: double.tryParse(j['lat']?.toString() ?? '') ?? 0,
      lng: double.tryParse(j['lng']?.toString() ?? '') ?? 0,
      altitude: double.tryParse(j['altitude']?.toString() ?? ''),
      course: double.tryParse(j['course']?.toString() ?? ''),
      speed: double.tryParse(j['speed']?.toString() ?? ''),
      lastTime: DateTime.fromMillisecondsSinceEpoch(
        (int.tryParse(j['lasttime']?.toString() ?? '') ?? 0) * 1000,
        isUtc: true,
      ),
    );
  }
}

class AprsFiClient {
  final String apiKey;
  final http.Client _http;

  AprsFiClient({required this.apiKey, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  void dispose() => _http.close();

  Future<List<AprsStation>> getLocations(List<String> callsigns) async {
    if (callsigns.isEmpty) return [];
    final names = callsigns.join(',');
    final resp = await _http.get(
      Uri.parse(
        'https://api.aprs.fi/api/get'
        '?name=$names&what=loc&apikey=$apiKey&format=json',
      ),
    );
    if (resp.statusCode != 200) {
      throw Exception('APRS.fi API returned HTTP ${resp.statusCode}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['result'] != 'ok') {
      throw Exception(
        'APRS.fi API error: ${body['description'] ?? body['result']}',
      );
    }
    final entries = body['entries'] as List? ?? [];
    return entries
        .cast<Map<String, dynamic>>()
        .map((j) => AprsStation.fromJson(j))
        .toList();
  }
}
