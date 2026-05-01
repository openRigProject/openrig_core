import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

QsoRecord _qso({String call = 'JA1ABC'}) => QsoRecord(
      call: call,
      band: '20m',
      mode: 'FT8',
      freqMhz: 14.074,
      timeOn: DateTime.utc(2025, 6, 1, 12, 0),
    );

MockClient _mock(String Function(http.Request) handler) {
  return MockClient((req) async {
    return http.Response(handler(req), 200);
  });
}

void main() {
  group('checkKey', () {
    test('returns callsign on OK', () async {
      final client = QrzLogbookClient(
        apiKey: 'test-key',
        httpClient: _mock((req) => 'RESULT=OK\nCALLSIGN=W1AW\n'),
      );
      final callsign = await client.checkKey();
      expect(callsign, equals('W1AW'));
      client.dispose();
    });

    test('returns STATION_CALLSIGN when CALLSIGN absent', () async {
      final client = QrzLogbookClient(
        apiKey: 'test-key',
        httpClient: _mock((req) => 'RESULT=OK\nSTATION_CALLSIGN=K5ABC\n'),
      );
      final callsign = await client.checkKey();
      expect(callsign, equals('K5ABC'));
      client.dispose();
    });

    test('throws QrzException on FAIL', () async {
      final client = QrzLogbookClient(
        apiKey: 'bad-key',
        httpClient: _mock((req) => 'RESULT=FAIL\nREASON=invalid api key\n'),
      );
      expect(
        () => client.checkKey(),
        throwsA(isA<QrzException>().having(
          (e) => e.message,
          'message',
          equals('invalid api key'),
        )),
      );
      client.dispose();
    });
  });

  group('insertQso', () {
    test('returns log ID on OK', () async {
      final client = QrzLogbookClient(
        apiKey: 'test-key',
        httpClient: _mock((req) {
          // Verify the request includes ADIF and ACTION
          expect(req.body, contains('ACTION=INSERT'));
          expect(req.body, contains('ADIF='));
          return 'RESULT=OK\nLOGID=12345\n';
        }),
      );
      final logId = await client.insertQso(_qso());
      expect(logId, equals('12345'));
      client.dispose();
    });

    test('throws QrzException on FAIL', () async {
      final client = QrzLogbookClient(
        apiKey: 'test-key',
        httpClient: _mock((req) => 'RESULT=FAIL\nREASON=duplicate QSO\n'),
      );
      expect(
        () => client.insertQso(_qso()),
        throwsA(isA<QrzException>().having(
          (e) => e.message,
          'message',
          equals('duplicate QSO'),
        )),
      );
      client.dispose();
    });

    test('sends KEY in request body', () async {
      final client = QrzLogbookClient(
        apiKey: 'my-secret-key',
        httpClient: _mock((req) {
          expect(req.body, contains('KEY=my-secret-key'));
          return 'RESULT=OK\nLOGID=99\n';
        }),
      );
      await client.insertQso(_qso());
      client.dispose();
    });
  });

  group('insertQsos', () {
    test('returns mixed results without throwing', () async {
      var callCount = 0;
      final client = QrzLogbookClient(
        apiKey: 'test-key',
        httpClient: _mock((req) {
          callCount++;
          if (callCount == 1) return 'RESULT=OK\nLOGID=100\n';
          if (callCount == 2) return 'RESULT=FAIL\nREASON=dupe\n';
          return 'RESULT=OK\nLOGID=102\n';
        }),
      );

      final results = await client.insertQsos([
        _qso(call: 'W1AW'),
        _qso(call: 'VE3ABC'),
        _qso(call: 'JA1XYZ'),
      ]);

      expect(results, hasLength(3));
      expect(results[0].success, isTrue);
      expect(results[0].logId, equals('100'));
      expect(results[0].error, isNull);

      expect(results[1].success, isFalse);
      expect(results[1].logId, isNull);
      expect(results[1].error, equals('dupe'));

      expect(results[2].success, isTrue);
      expect(results[2].logId, equals('102'));

      client.dispose();
    });

    test('empty list returns empty results', () async {
      final client = QrzLogbookClient(
        apiKey: 'test-key',
        httpClient: _mock((req) => 'RESULT=OK\n'),
      );
      final results = await client.insertQsos([]);
      expect(results, isEmpty);
      client.dispose();
    });
  });

  group('QrzException', () {
    test('toString includes message', () {
      const e = QrzException('bad key');
      expect(e.toString(), equals('QrzException: bad key'));
    });
  });
}
