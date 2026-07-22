import 'dart:convert';

import 'package:http/http.dart' as http;

class PotaSpot {
  final String activator;
  final double frequencyKhz;
  final String mode;
  final String reference;
  final String parkName;
  final String spotter;
  final String comment;
  final DateTime time;
  final double? latitude;
  final double? longitude;

  const PotaSpot({
    required this.activator,
    required this.frequencyKhz,
    required this.mode,
    required this.reference,
    required this.parkName,
    required this.spotter,
    required this.comment,
    required this.time,
    this.latitude,
    this.longitude,
  });

  double get frequencyMhz => frequencyKhz / 1000;

  factory PotaSpot.fromJson(Map<String, dynamic> j) {
    return PotaSpot(
      activator: (j['activator'] as String? ?? '').toUpperCase(),
      frequencyKhz: double.tryParse(j['frequency']?.toString() ?? '') ?? 0,
      mode: j['mode'] as String? ?? '',
      reference: j['reference'] as String? ?? '',
      parkName: j['parkName'] as String? ?? '',
      spotter: (j['spotter'] as String? ?? '').toUpperCase(),
      comment: j['comments'] as String? ?? '',
      time: DateTime.tryParse(j['spotTime'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      latitude: double.tryParse(j['latitude']?.toString() ?? ''),
      longitude: double.tryParse(j['longitude']?.toString() ?? ''),
    );
  }
}

class PotaClient {
  final http.Client _http;

  PotaClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  void dispose() => _http.close();

  Future<List<PotaSpot>> fetchActivators() async {
    final resp = await _http.get(
      Uri.parse('https://api.pota.app/spot/activator'),
    );
    if (resp.statusCode != 200) {
      throw Exception('POTA API returned HTTP ${resp.statusCode}');
    }
    final list = jsonDecode(resp.body) as List;
    return list
        .cast<Map<String, dynamic>>()
        .where((j) => j['invalid'] != 1 && j['invalid'] != true)
        .map((j) => PotaSpot.fromJson(j))
        .toList();
  }
}
