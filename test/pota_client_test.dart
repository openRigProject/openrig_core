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
  group('PotaSpot.fromJson', () {
    test('parses frequency as string', () {
      final spot = PotaSpot.fromJson({
        'activator': 'w1aw',
        'frequency': '14074.0',
        'mode': 'FT8',
        'reference': 'K-0001',
        'parkName': 'Test Park',
        'spotter': 'k5abc',
        'comments': 'Loud signal',
        'spotTime': '2025-06-01T12:00:00',
      });
      expect(spot.activator, equals('W1AW'));
      expect(spot.frequencyKhz, equals(14074.0));
      expect(spot.frequencyMhz, closeTo(14.074, 0.001));
      expect(spot.spotter, equals('K5ABC'));
    });

    test('parses frequency as number', () {
      final spot = PotaSpot.fromJson({
        'activator': 'W1AW',
        'frequency': 7074,
        'mode': 'FT8',
        'reference': 'K-0002',
        'parkName': 'Another Park',
        'spotter': 'N0CALL',
        'comments': '',
        'spotTime': '2025-06-01T13:00:00',
      });
      expect(spot.frequencyKhz, equals(7074.0));
    });

    test('handles missing optional fields', () {
      final spot = PotaSpot.fromJson({
        'activator': 'W1AW',
        'frequency': '14074.0',
        'mode': 'FT8',
        'reference': 'K-0001',
        'parkName': 'Test Park',
        'spotter': 'K5ABC',
        'comments': '',
        'spotTime': '2025-06-01T12:00:00',
      });
      expect(spot.latitude, isNull);
      expect(spot.longitude, isNull);
    });

    test('parses latitude and longitude when present', () {
      final spot = PotaSpot.fromJson({
        'activator': 'W1AW',
        'frequency': '14074.0',
        'mode': 'FT8',
        'reference': 'K-0001',
        'parkName': 'Test Park',
        'spotter': 'K5ABC',
        'comments': '',
        'spotTime': '2025-06-01T12:00:00',
        'latitude': '41.7147',
        'longitude': '-72.7272',
      });
      expect(spot.latitude, closeTo(41.7147, 0.001));
      expect(spot.longitude, closeTo(-72.7272, 0.001));
    });
  });

  group('PotaClient.fetchActivators', () {
    test('parses valid JSON array', () async {
      final json = jsonEncode([
        {
          'activator': 'W1AW',
          'frequency': '14074.0',
          'mode': 'FT8',
          'reference': 'K-0001',
          'parkName': 'Acadia NP',
          'spotter': 'K5ABC',
          'comments': 'Strong',
          'spotTime': '2025-06-01T12:00:00',
          'latitude': '44.35',
          'longitude': '-68.21',
        },
        {
          'activator': 'VE3ABC',
          'frequency': '7074',
          'mode': 'FT8',
          'reference': 'VE-0100',
          'parkName': 'Algonquin',
          'spotter': 'W0SUN',
          'comments': '',
          'spotTime': '2025-06-01T12:30:00',
        },
      ]);
      final client = PotaClient(httpClient: _mock(json));
      final spots = await client.fetchActivators();
      expect(spots, hasLength(2));
      expect(spots[0].activator, equals('W1AW'));
      expect(spots[1].reference, equals('VE-0100'));
      client.dispose();
    });

    test('filters out invalid spots', () async {
      final json = jsonEncode([
        {
          'activator': 'W1AW',
          'frequency': '14074.0',
          'mode': 'FT8',
          'reference': 'K-0001',
          'parkName': 'Valid Park',
          'spotter': 'K5ABC',
          'comments': '',
          'spotTime': '2025-06-01T12:00:00',
          'invalid': 0,
        },
        {
          'activator': 'N0BAD',
          'frequency': '7074',
          'mode': 'CW',
          'reference': 'K-9999',
          'parkName': 'Invalid Park',
          'spotter': 'W0SUN',
          'comments': '',
          'spotTime': '2025-06-01T12:30:00',
          'invalid': 1,
        },
        {
          'activator': 'K0ALSO',
          'frequency': '3574',
          'mode': 'FT8',
          'reference': 'K-8888',
          'parkName': 'Also Invalid',
          'spotter': 'W0SUN',
          'comments': '',
          'spotTime': '2025-06-01T13:00:00',
          'invalid': true,
        },
      ]);
      final client = PotaClient(httpClient: _mock(json));
      final spots = await client.fetchActivators();
      expect(spots, hasLength(1));
      expect(spots[0].activator, equals('W1AW'));
      client.dispose();
    });

    test('throws on non-200 status', () async {
      final client =
          PotaClient(httpClient: _mock('Server Error', statusCode: 500));
      expect(
        () => client.fetchActivators(),
        throwsA(isA<Exception>()),
      );
      client.dispose();
    });
  });
}
