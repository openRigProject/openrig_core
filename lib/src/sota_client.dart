import 'dart:convert';

import 'package:http/http.dart' as http;

class SotaSpot {
  final String activatorCallsign;
  final String summitCode;
  final String summitName;
  final String comments;
  final double frequencyMhz;
  final String mode;
  final DateTime time;
  final double? latitude;
  final double? longitude;
  final int? altitude;

  const SotaSpot({
    required this.activatorCallsign,
    required this.summitCode,
    required this.summitName,
    required this.comments,
    required this.frequencyMhz,
    required this.mode,
    required this.time,
    this.latitude,
    this.longitude,
    this.altitude,
  });

  double get frequencyKhz => frequencyMhz * 1000;

  factory SotaSpot.fromJson(Map<String, dynamic> j) {
    return SotaSpot(
      activatorCallsign:
          (j['activatorCallsign'] as String? ?? '').toUpperCase(),
      summitCode: j['summitCode'] as String? ?? '',
      summitName: j['summitDetails'] as String? ?? '',
      comments: j['comments'] as String? ?? '',
      frequencyMhz:
          double.tryParse(j['frequency']?.toString() ?? '') ?? 0,
      mode: j['mode'] as String? ?? '',
      time: DateTime.tryParse(j['timeStamp'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      latitude: double.tryParse(j['latitude']?.toString() ?? ''),
      longitude: double.tryParse(j['longitude']?.toString() ?? ''),
      altitude: int.tryParse(j['altitude']?.toString() ?? ''),
    );
  }
}

class SotaClient {
  final http.Client _http;

  SotaClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  void dispose() => _http.close();

  Future<List<SotaSpot>> fetchSpots({int count = 50}) async {
    final resp = await _http.get(
      Uri.parse('https://api2.sota.org.uk/api/spots/$count/all'),
    );
    if (resp.statusCode != 200) {
      throw Exception('SOTA API returned HTTP ${resp.statusCode}');
    }
    final list = jsonDecode(resp.body) as List;
    return list
        .cast<Map<String, dynamic>>()
        .map((j) => SotaSpot.fromJson(j))
        .toList();
  }
}
