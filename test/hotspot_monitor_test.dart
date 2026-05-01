import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

/// Mutable mock response state for the mock server.
Map<String, dynamic> _statusJson = {
  'type': 'hotspot',
  'callsign': 'W1AW',
  'hostname': 'w1aw-hotspot',
  'version': '0.1.0',
  'uptime': 100,
  'provisioned': true,
};

List<Map<String, dynamic>> _clientsJson = [
  {
    'callsign': 'W1AW',
    'mode': 'DMR',
    'lastHeard': '2025-03-15T14:30:00.000Z',
    'duration': 45,
  },
];

Map<String, dynamic> _hotspotJson = {
  'dmr': {
    'enabled': true,
    'colorcode': 1,
    'masterServer': 'tgif.network',
    'password': 'pass',
    'talkgroups': [
      {'id': 91, 'slot': 1, 'name': 'Worldwide'},
    ],
  },
  'ysf': {
    'enabled': false,
    'reflector': 'US-openRig',
    'description': 'openRig YSF',
  },
  'ysf2dmr': {'enabled': false},
  'dmr2ysf': {'enabled': false},
};

Map<String, dynamic> _networkJson = {
  'mode': 'wifi',
  'ssid': 'HomeNetwork',
  'ip': '192.168.1.42',
  'signal_dbm': -65,
  'connected': true,
  'interface': 'wlan0',
};

bool _shouldFail = false;

void main() {
  late HttpServer server;
  late OpenRigApiClient apiClient;

  setUpAll(() async {
    server = await HttpServer.bind('localhost', 0);
    server.listen((request) async {
      final path = request.uri.path;

      if (_shouldFail) {
        request.response.statusCode = 500;
        request.response.write('server error');
        await request.response.close();
        return;
      }

      switch (path) {
        case '/api/status':
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(_statusJson));
        case '/api/clients':
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(_clientsJson));
        case '/api/hotspot':
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(_hotspotJson));
        case '/api/network':
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(_networkJson));
        default:
          request.response.statusCode = 404;
          request.response.write('not found');
      }
      await request.response.close();
    });
  });

  tearDownAll(() async {
    await server.close();
  });

  setUp(() {
    _shouldFail = false;
    _statusJson['uptime'] = 100;
    _clientsJson = [
      {
        'callsign': 'W1AW',
        'mode': 'DMR',
        'lastHeard': '2025-03-15T14:30:00.000Z',
        'duration': 45,
      },
    ];
    apiClient = OpenRigApiClient(host: 'localhost', port: server.port);
  });

  test('emits status on first poll', () async {
    final monitor = HotspotMonitor.withClient(
      client: apiClient,
      interval: const Duration(seconds: 60),
    );

    final future = monitor.status.first;
    monitor.start();

    final s = await future.timeout(const Duration(seconds: 2));
    expect(s.callsign, equals('W1AW'));
    expect(s.type, equals('hotspot'));
    expect(s.uptime, equals(100));

    monitor.dispose();
  });

  test('emits clients list on first poll', () async {
    final monitor = HotspotMonitor.withClient(
      client: apiClient,
      interval: const Duration(seconds: 60),
    );

    final future = monitor.clients.first;
    monitor.start();

    final c = await future.timeout(const Duration(seconds: 2));
    expect(c, hasLength(1));
    expect(c[0].callsign, equals('W1AW'));
    expect(c[0].mode, equals('DMR'));

    monitor.dispose();
  });

  test('emits hotspot config on first poll', () async {
    final monitor = HotspotMonitor.withClient(
      client: apiClient,
      interval: const Duration(seconds: 60),
    );

    final future = monitor.hotspot.first;
    monitor.start();

    final config = await future.timeout(const Duration(seconds: 2));
    expect(config.dmr.enabled, isTrue);
    expect(config.dmr.colorcode, equals(1));

    monitor.dispose();
  });

  test('does not re-emit unchanged values', () async {
    final monitor = HotspotMonitor.withClient(
      client: apiClient,
      interval: const Duration(milliseconds: 100),
    );

    final statuses = <DeviceStatus>[];
    final sub = monitor.status.listen(statuses.add);

    monitor.start();

    // Wait for multiple poll cycles
    await Future.delayed(const Duration(milliseconds: 500));

    monitor.stop();
    await sub.cancel();

    // Should have emitted only once since data didn't change
    expect(statuses, hasLength(1));

    monitor.dispose();
  });

  test('emits again when values change', () async {
    final monitor = HotspotMonitor.withClient(
      client: apiClient,
      interval: const Duration(milliseconds: 100),
    );

    final statuses = <DeviceStatus>[];
    final sub = monitor.status.listen(statuses.add);

    monitor.start();

    // Wait for first poll
    await Future.delayed(const Duration(milliseconds: 200));

    // Change the mock data
    _statusJson['uptime'] = 200;

    // Wait for next poll to pick up the change
    await Future.delayed(const Duration(milliseconds: 200));

    monitor.stop();
    await sub.cancel();

    expect(statuses.length, greaterThanOrEqualTo(2));
    expect(statuses.first.uptime, equals(100));
    expect(statuses.last.uptime, equals(200));

    monitor.dispose();
  });

  test('error ticks do not crash streams', () async {
    final monitor = HotspotMonitor.withClient(
      client: apiClient,
      interval: const Duration(milliseconds: 100),
    );

    final statuses = <DeviceStatus>[];
    final sub = monitor.status.listen(statuses.add);

    monitor.start();

    // Wait for first successful poll
    await Future.delayed(const Duration(milliseconds: 200));
    expect(statuses, hasLength(1));

    // Trigger failures — should be silently swallowed
    _shouldFail = true;
    await Future.delayed(const Duration(milliseconds: 300));

    // Recover and change data
    _shouldFail = false;
    _statusJson['uptime'] = 999;
    await Future.delayed(const Duration(milliseconds: 300));

    // Stream should still be alive — new status emitted
    expect(statuses.length, greaterThanOrEqualTo(2));

    monitor.stop();
    await sub.cancel();
    monitor.dispose();
  });

  test('stop pauses polling, start resumes', () async {
    final monitor = HotspotMonitor.withClient(
      client: apiClient,
      interval: const Duration(milliseconds: 100),
    );

    final statuses = <DeviceStatus>[];
    final sub = monitor.status.listen(statuses.add);

    monitor.start();
    await Future.delayed(const Duration(milliseconds: 200));
    expect(statuses, hasLength(1));

    // Stop and change data
    monitor.stop();
    _statusJson['uptime'] = 300;
    await Future.delayed(const Duration(milliseconds: 300));

    // No new emissions while stopped
    expect(statuses, hasLength(1));

    // Resume
    monitor.start();
    await Future.delayed(const Duration(milliseconds: 200));

    // Should have picked up the change
    expect(statuses, hasLength(2));
    expect(statuses.last.uptime, equals(300));

    monitor.stop();
    await sub.cancel();
    monitor.dispose();
  });

  test('emits network status on first poll', () async {
    final monitor = HotspotMonitor.withClient(
      client: apiClient,
      interval: const Duration(seconds: 60),
    );

    final future = monitor.network.first;
    monitor.start();

    final net = await future.timeout(const Duration(seconds: 2));
    expect(net.mode, equals('wifi'));
    expect(net.ssid, equals('HomeNetwork'));
    expect(net.ip, equals('192.168.1.42'));
    expect(net.signalDbm, equals(-65));
    expect(net.connected, isTrue);
    expect(net.networkInterface, equals('wlan0'));

    monitor.dispose();
  });

  test('dispose closes all streams', () async {
    final monitor = HotspotMonitor.withClient(
      client: apiClient,
      interval: const Duration(seconds: 60),
    );

    monitor.dispose();

    // Streams should be closed — listening should complete
    expect(monitor.status.listen((_) {}).cancel(), completes);
    expect(monitor.hotspot.listen((_) {}).cancel(), completes);
    expect(monitor.clients.listen((_) {}).cancel(), completes);
    expect(monitor.network.listen((_) {}).cancel(), completes);
  });
}
