import 'dart:async';
import 'dart:io';
import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

/// Integration tests for RigctldClient using hamlib model 1 (Dummy rig).
///
/// Requires `rigctld` to be installed. The Dummy rig needs no real hardware.
void main() {
  late Process rigctldProcess;
  late RigctldClient client;
  const port = 14600;

  setUpAll(() async {
    rigctldProcess = await Process.start(
      'rigctld',
      ['-m', '1', '-t', '$port'],
    );
    // Wait for rigctld to be ready
    await Future.delayed(const Duration(milliseconds: 500));
  });

  tearDownAll(() async {
    rigctldProcess.kill();
    await rigctldProcess.exitCode;
  });

  setUp(() async {
    client = RigctldClient(host: 'localhost', port: port);
    await client.connect();
  });

  tearDown(() async {
    await client.dispose();
  });

  test('connect and disconnect lifecycle', () async {
    expect(client.isConnected, isTrue);
    await client.disconnect();
    expect(client.isConnected, isFalse);
  });

  test('getFrequency returns default frequency', () async {
    final freq = await client.getFrequency();
    expect(freq, isA<int>());
    expect(freq, greaterThan(0));
  });

  test('setFrequency / getFrequency round-trip', () async {
    await client.setFrequency(14225000);
    final freq = await client.getFrequency();
    expect(freq, equals(14225000));
  });

  test('getMode returns a mode and passband', () async {
    final result = await client.getMode();
    expect(result.mode, isNotEmpty);
    expect(result.passband, isA<int>());
  });

  test('setMode / getMode round-trip', () async {
    await client.setMode('USB', passband: 2400);
    final result = await client.getMode();
    expect(result.mode, equals('USB'));
    expect(result.passband, equals(2400));
  });

  test('setPtt / getPtt round-trip', () async {
    await client.setPtt(false);
    final off = await client.getPtt();
    expect(off, isFalse);

    await client.setPtt(true);
    final on = await client.getPtt();
    expect(on, isTrue);

    // Clean up — turn PTT off
    await client.setPtt(false);
  });

  group('RigctldError', () {
    test('thrown when server returns non-zero RPRT', () async {
      // Start a mock TCP server that always returns RPRT -1
      final server = await ServerSocket.bind('localhost', 0);
      final mockPort = server.port;
      server.listen((socket) {
        socket.listen((data) {
          socket.write('RPRT -1\n');
        });
      });

      try {
        final mockClient = RigctldClient(host: 'localhost', port: mockPort);
        await mockClient.connect();

        try {
          await mockClient.getFrequency();
          fail('Expected RigctldError to be thrown');
        } on RigctldError catch (e) {
          expect(e.code, equals(-1));
        }

        await mockClient.disconnect();
      } finally {
        await server.close();
      }
    });
  });

  group('connectionState', () {
    test('emits true on connect, false on disconnect', () async {
      final c = RigctldClient(host: 'localhost', port: port);
      final states = <bool>[];
      final sub = c.connectionState.listen(states.add);

      await c.connect();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(states, equals([true]));

      await c.disconnect();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(states, equals([true, false]));

      await sub.cancel();
      await c.dispose();
    });

    test('autoReconnect false does not reconnect', () async {
      // Mock server that accepts one connection then closes
      final server = await ServerSocket.bind('localhost', 0);
      final mockPort = server.port;
      server.listen((socket) {
        // Close immediately to simulate connection loss
        socket.close();
      });

      final c = RigctldClient(
        host: 'localhost',
        port: mockPort,
        autoReconnect: false,
      );
      final states = <bool>[];
      final sub = c.connectionState.listen(states.add);

      await c.connect();
      // Wait for connection loss to be detected
      await Future.delayed(const Duration(milliseconds: 300));

      // Should have connected then disconnected, no reconnect
      expect(states, contains(true));
      expect(states.last, isFalse);
      // Only 1 true event (no reconnect attempts)
      expect(states.where((s) => s).length, equals(1));

      await sub.cancel();
      await c.dispose();
      await server.close();
    });

    test('autoReconnect true reconnects after loss', () async {
      // Mock server that accepts connections
      final server = await ServerSocket.bind('localhost', 0);
      final mockPort = server.port;
      var connectionCount = 0;
      server.listen((socket) {
        connectionCount++;
        if (connectionCount == 1) {
          // Close first connection to trigger reconnect
          socket.close();
        }
        // Second connection stays open
      });

      final c = RigctldClient(
        host: 'localhost',
        port: mockPort,
        autoReconnect: true,
      );
      final states = <bool>[];
      final sub = c.connectionState.listen(states.add);

      await c.connect();
      // Wait for disconnect + reconnect cycle (back-off starts at 1s)
      await Future.delayed(const Duration(milliseconds: 2000));

      // Should have reconnected: true, false, true
      expect(states.where((s) => s).length, greaterThanOrEqualTo(2));

      await sub.cancel();
      await c.dispose();
      await server.close();
    });

    test('dispose stops reconnect loop', () async {
      // Server that rejects all connections after first
      final server = await ServerSocket.bind('localhost', 0);
      final mockPort = server.port;
      server.listen((socket) {
        socket.close(); // Always close to trigger reconnect
      });

      final c = RigctldClient(
        host: 'localhost',
        port: mockPort,
        autoReconnect: true,
      );

      await c.connect();
      await Future.delayed(const Duration(milliseconds: 200));

      // Dispose should stop any reconnect loop
      await c.dispose();

      // Give time for any pending reconnect to fire (it shouldn't)
      await Future.delayed(const Duration(milliseconds: 500));

      // If we got here without hanging, the loop stopped
      expect(c.isConnected, isFalse);

      await server.close();
    });
  });
}
