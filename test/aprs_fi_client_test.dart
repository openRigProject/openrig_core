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
  group('AprsStation.fromJson', () {
    test('parses full entry', () {
      final station = AprsStation.fromJson({
        'name': 'W1AW',
        'type': 'l',
        'time': '1625000000',
        'lasttime': '1625000000',
        'lat': '41.7147',
        'lng': '-72.7272',
        'altitude': '30.000',
        'course': '90',
        'speed': '5',
        'symbol': '/-',
        'srccall': 'W1AW',
        'comment': 'ARRL HQ',
        'path': 'WIDE1-1',
      });
      expect(station.callsign, equals('W1AW'));
      expect(station.lat, closeTo(41.7147, 0.001));
      expect(station.lng, closeTo(-72.7272, 0.001));
      expect(station.altitude, closeTo(30.0, 0.1));
      expect(station.course, closeTo(90.0, 0.1));
      expect(station.speed, closeTo(5.0, 0.1));
      expect(station.comment, equals('ARRL HQ'));
      expect(station.path, equals('WIDE1-1'));
      expect(station.symbol, equals('/-'));
      expect(
        station.lastTime,
        equals(DateTime.utc(2021, 6, 29, 20, 53, 20)),
      );
    });

    test('handles missing optional fields', () {
      final station = AprsStation.fromJson({
        'name': 'W1AW',
        'lasttime': '1625000000',
        'lat': '41.7147',
        'lng': '-72.7272',
        'symbol': '/-',
      });
      expect(station.altitude, isNull);
      expect(station.course, isNull);
      expect(station.speed, isNull);
      expect(station.comment, equals(''));
      expect(station.path, equals(''));
    });
  });

  group('AprsFiClient.getLocations', () {
    test('returns empty list for empty callsigns', () async {
      final client = AprsFiClient(
        apiKey: 'test-key',
        httpClient: _mock('should not be called'),
      );
      final result = await client.getLocations([]);
      expect(result, isEmpty);
      client.dispose();
    });

    test('parses valid response', () async {
      final json = jsonEncode({
        'command': 'get',
        'result': 'ok',
        'what': 'loc',
        'found': 2,
        'entries': [
          {
            'name': 'W1AW',
            'lasttime': '1625000000',
            'lat': '41.7147',
            'lng': '-72.7272',
            'altitude': '30.000',
            'symbol': '/-',
            'comment': 'ARRL HQ',
            'path': 'WIDE1-1',
          },
          {
            'name': 'K5ABC',
            'lasttime': '1625001000',
            'lat': '32.0',
            'lng': '-97.0',
            'symbol': '/k',
            'comment': 'Mobile',
            'path': 'WIDE2-1',
          },
        ],
      });
      final client = AprsFiClient(
        apiKey: 'test-key',
        httpClient: _mock(json),
      );
      final stations = await client.getLocations(['W1AW', 'K5ABC']);
      expect(stations, hasLength(2));
      expect(stations[0].callsign, equals('W1AW'));
      expect(stations[1].callsign, equals('K5ABC'));
      client.dispose();
    });

    test('includes apikey in request URL', () async {
      final client = AprsFiClient(
        apiKey: 'my-secret',
        httpClient: MockClient((req) async {
          expect(req.url.queryParameters['apikey'], equals('my-secret'));
          expect(req.url.queryParameters['name'], equals('W1AW'));
          return http.Response(
            jsonEncode({
              'result': 'ok',
              'entries': [],
            }),
            200,
          );
        }),
      );
      await client.getLocations(['W1AW']);
      client.dispose();
    });

    test('throws on non-ok result', () async {
      final json = jsonEncode({
        'result': 'fail',
        'description': 'invalid api key',
      });
      final client = AprsFiClient(
        apiKey: 'bad-key',
        httpClient: _mock(json),
      );
      expect(
        () => client.getLocations(['W1AW']),
        throwsA(isA<Exception>()),
      );
      client.dispose();
    });

    test('throws on non-200 status', () async {
      final client = AprsFiClient(
        apiKey: 'test-key',
        httpClient: _mock('Server Error', statusCode: 500),
      );
      expect(
        () => client.getLocations(['W1AW']),
        throwsA(isA<Exception>()),
      );
      client.dispose();
    });
  });
}
