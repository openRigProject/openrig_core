import 'dart:async';
import 'dart:io';
import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

void main() {
  group('DxSpot.fromLine', () {
    test('parses a standard spot line', () {
      const line =
          'DX de W3LPL:      14025.0 JA1ABC       up 1-2               1423Z';
      final spot = DxSpot.fromLine(line);

      expect(spot, isNotNull);
      expect(spot!.spotter, equals('W3LPL'));
      expect(spot.dxCall, equals('JA1ABC'));
      expect(spot.frequencyKhz, closeTo(14025.0, 0.1));
      expect(spot.comment, equals('up 1-2'));
      expect(spot.time.hour, equals(14));
      expect(spot.time.minute, equals(23));
    });

    test('parses spot with slash in callsigns', () {
      const line =
          'DX de VE3/W1AW:   21074.5 F/DL1ABC     FT8 -12 dB           0930Z';
      final spot = DxSpot.fromLine(line);

      expect(spot, isNotNull);
      expect(spot!.spotter, equals('VE3/W1AW'));
      expect(spot.dxCall, equals('F/DL1ABC'));
      expect(spot.frequencyKhz, closeTo(21074.5, 0.1));
    });

    test('parses spot with integer frequency (no decimal)', () {
      const line =
          'DX de K9OX:       7025 W1AW           CW 599                2359Z';
      final spot = DxSpot.fromLine(line);

      expect(spot, isNotNull);
      expect(spot!.frequencyKhz, closeTo(7025.0, 0.1));
    });

    test('returns null on empty string', () {
      expect(DxSpot.fromLine(''), isNull);
    });

    test('returns null on cluster login prompt', () {
      expect(DxSpot.fromLine('login: '), isNull);
    });

    test('returns null on cluster banner line', () {
      expect(
        DxSpot.fromLine('Hello W1AW, this is K9OX-2 in Chicago'),
        isNull,
      );
    });

    test('returns null on partial/truncated spot', () {
      expect(DxSpot.fromLine('DX de W3LPL:'), isNull);
    });

    test('date rollover: future time treated as yesterday', () {
      // Build a spot line with a time 1 hour in the future
      final now = DateTime.now().toUtc();
      final future = now.add(const Duration(hours: 1));
      final hhmm =
          '${future.hour.toString().padLeft(2, '0')}${future.minute.toString().padLeft(2, '0')}';

      final line =
          'DX de W1AW:       14025.0 K1ABC        test                 ${hhmm}Z';
      final spot = DxSpot.fromLine(line);

      expect(spot, isNotNull);
      // Should be yesterday (or at least not in the future)
      expect(spot!.time.isBefore(now) || spot.time.isAtSameMomentAs(now),
          isTrue);
    });

    test('parses pota-prefixed spot line with park ref', () {
      const line =
          'pota DX de JH7CSU1-#   7006.5  JM1TBU       CW 27 dB 20 WPM via JH7CSU1-#  0529Z JP-0118';
      final spot = DxSpot.fromLine(line);

      expect(spot, isNotNull);
      expect(spot!.source, equals('pota'));
      expect(spot.spotter, equals('JH7CSU1-#'));
      expect(spot.dxCall, equals('JM1TBU'));
      expect(spot.frequencyKhz, closeTo(7006.5, 0.1));
      expect(spot.time.hour, equals(5));
      expect(spot.time.minute, equals(29));
      expect(spot.parkRef, equals('JP-0118'));
    });

    test('parses dxsu-prefixed spot line', () {
      const line =
          'dxsu DX de VK6KXW-@   50313.0  XU7O         :r-21                          0534Z';
      final spot = DxSpot.fromLine(line);

      expect(spot, isNotNull);
      expect(spot!.source, equals('dxsu'));
      expect(spot.spotter, equals('VK6KXW-@'));
      expect(spot.dxCall, equals('XU7O'));
      expect(spot.frequencyKhz, closeTo(50313.0, 0.1));
      expect(spot.time.hour, equals(5));
      expect(spot.time.minute, equals(34));
    });

    test('standard spot has source dx', () {
      const line =
          'DX de W3LPL:      14025.0 JA1ABC       up 1-2               1423Z';
      final spot = DxSpot.fromLine(line);
      expect(spot, isNotNull);
      expect(spot!.source, equals('dx'));
    });

    test('current/past time stays on today', () {
      // Build a spot with a time 1 hour in the past
      final now = DateTime.now().toUtc();
      final past = now.subtract(const Duration(hours: 1));
      final hhmm =
          '${past.hour.toString().padLeft(2, '0')}${past.minute.toString().padLeft(2, '0')}';

      final line =
          'DX de W1AW:       14025.0 K1ABC        test                 ${hhmm}Z';
      final spot = DxSpot.fromLine(line);

      expect(spot, isNotNull);
      expect(spot!.time.day, equals(now.day));
    });
  });

  group('DxClusterClient connectionState', () {
    late ServerSocket server;

    setUp(() async {
      server = await ServerSocket.bind('localhost', 0);
    });

    tearDown(() async {
      await server.close();
    });

    test('emits true on connect, false on disconnect', () async {
      // Keep connections open
      server.listen((_) {});

      final client = DxClusterClient(
        host: 'localhost',
        callsign: 'W1AW',
        port: server.port,
      );

      final states = <bool>[];
      final sub = client.connectionState.listen(states.add);

      await client.connect();
      await Future.delayed(const Duration(milliseconds: 50));

      await client.disconnect();
      await Future.delayed(const Duration(milliseconds: 50));

      await sub.cancel();
      await client.dispose();

      expect(states, contains(true));
      expect(states.last, isFalse);
    });

    test('auto-reconnect reconnects after server drop', () async {
      var connectionCount = 0;
      server.listen((socket) {
        connectionCount++;
        if (connectionCount == 1) {
          // Close first connection to trigger reconnect
          socket.close();
        }
        // Second connection stays open
      });

      final client = DxClusterClient(
        host: 'localhost',
        callsign: 'W1AW',
        port: server.port,
        autoReconnect: true,
      );

      final states = <bool>[];
      final sub = client.connectionState.listen(states.add);

      await client.connect();
      // Wait for disconnect + reconnect cycle (back-off starts at 1s)
      await Future.delayed(const Duration(milliseconds: 2000));

      // Should have reconnected: true, false, true
      expect(states.where((s) => s).length, greaterThanOrEqualTo(2));

      await sub.cancel();
      await client.dispose();
    });

    test('dispose stops reconnect loop', () async {
      server.listen((socket) {
        socket.close(); // Always close to trigger reconnect
      });

      final client = DxClusterClient(
        host: 'localhost',
        callsign: 'W1AW',
        port: server.port,
        autoReconnect: true,
      );

      await client.connect();
      await Future.delayed(const Duration(milliseconds: 200));

      // Dispose should stop any reconnect loop
      await client.dispose();

      // Give time for any pending reconnect to fire (it shouldn't)
      await Future.delayed(const Duration(milliseconds: 500));

      expect(client.isConnected, isFalse);
    });
  });
}
