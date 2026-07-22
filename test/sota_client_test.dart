import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

MockClient _mock(String body, {int statusCode = 200}) {
  return MockClient(
      (req) async => http.Response(body, statusCode));
}

void main() {
  group('SotaSpot.fromJson', () {
    test('parses standard spot', () {
      final spot = SotaSpot.fromJson({
        'id': 123,
        'timeStamp': '2025-06-01T12:00:00',
        'comments': 'FT8 up',
        'callsign': 'W1ABC/P',
        'associationCode': 'W7W',
        'summitCode': 'W7W/KG-001',
        'summitDetails': 'Mount Si',
        'activatorCallsign': 'W1ABC',
        'activatorName': 'John',
        'frequency': '14.074',
        'mode': 'FT8',
        'highlightColor': 'green',
      });
      expect(spot.activatorCallsign, equals('W1ABC'));
      expect(spot.summitCode, equals('W7W/KG-001'));
      expect(spot.summitName, equals('Mount Si'));
      expect(spot.frequencyMhz, closeTo(14.074, 0.001));
      expect(spot.frequencyKhz, closeTo(14074.0, 1.0));
      expect(spot.mode, equals('FT8'));
      expect(spot.comments, equals('FT8 up'));
    });

    test('latitude, longitude, altitude are null from spots endpoint', () {
      final spot = SotaSpot.fromJson({
        'activatorCallsign': 'W1ABC',
        'summitCode': 'W7W/KG-001',
        'summitDetails': 'Mount Si',
        'comments': '',
        'frequency': '14.074',
        'mode': 'FT8',
        'timeStamp': '2025-06-01T12:00:00',
      });
      expect(spot.latitude, isNull);
      expect(spot.longitude, isNull);
      expect(spot.altitude, isNull);
    });

    test('handles missing optional fields gracefully', () {
      final spot = SotaSpot.fromJson(<String, dynamic>{});
      expect(spot.activatorCallsign, equals(''));
      expect(spot.summitCode, equals(''));
      expect(spot.frequencyMhz, equals(0));
      expect(spot.mode, equals(''));
    });
  });

  group('SotaClient.fetchSpots', () {
    test('parses valid JSON array', () async {
      final json = jsonEncode([
        {
          'id': 1,
          'timeStamp': '2025-06-01T12:00:00',
          'comments': 'CW',
          'callsign': 'W1ABC/P',
          'summitCode': 'W7W/KG-001',
          'summitDetails': 'Mount Si',
          'activatorCallsign': 'W1ABC',
          'frequency': '7.032',
          'mode': 'CW',
        },
        {
          'id': 2,
          'timeStamp': '2025-06-01T12:30:00',
          'comments': 'SSB',
          'callsign': 'VE3XYZ/P',
          'summitCode': 'VE3/SE-001',
          'summitDetails': 'Blue Mountain',
          'activatorCallsign': 'VE3XYZ',
          'frequency': '14.285',
          'mode': 'SSB',
        },
      ]);
      final client = SotaClient(httpClient: _mock(json));
      final spots = await client.fetchSpots();
      expect(spots, hasLength(2));
      expect(spots[0].activatorCallsign, equals('W1ABC'));
      expect(spots[1].summitName, equals('Blue Mountain'));
      client.dispose();
    });

    test('passes count parameter in URL', () async {
      final client = SotaClient(
        httpClient: MockClient((req) async {
          expect(req.url.path, contains('/25/'));
          return http.Response('[]', 200);
        }),
      );
      await client.fetchSpots(count: 25);
      client.dispose();
    });

    test('throws on non-200 status', () async {
      final client =
          SotaClient(httpClient: _mock('Server Error', statusCode: 500));
      expect(
        () => client.fetchSpots(),
        throwsA(isA<Exception>()),
      );
      client.dispose();
    });
  });
}
