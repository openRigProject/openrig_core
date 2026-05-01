import 'dart:convert';
import 'dart:io';
import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

/// Mock HTTP server fixture data.
final _statusJson = {
  'type': 'hotspot',
  'callsign': 'W1AW',
  'hostname': 'w1aw-hotspot',
  'version': '0.1.0',
  'uptime': 86400,
  'provisioned': true,
};

final _configJson = {
  'callsign': 'W1AW',
  'hostname': 'w1aw-hotspot',
  'timezone': 'America/New_York',
  'operatorName': 'Hiram Maxim',
  'gridSquare': 'FN31pr',
};

final _hotspotJson = {
  'dmr': {
    'enabled': true,
    'colorcode': 1,
    'masterServer': 'tgif.network',
    'password': 'passw0rd',
    'talkgroups': [
      {'id': 91, 'slot': 1, 'name': 'Worldwide'},
    ],
  },
  'ysf': {
    'enabled': false,
    'reflector': 'US-openRig',
    'description': 'openRig YSF',
  },
  'ysf2dmr': {'enabled': true, 'talkgroup': 3100},
  'dmr2ysf': {'enabled': false, 'room': 'US-openRig'},
};

final _wifiJson = [
  {'ssid': 'HomeWifi', 'security': 'WPA2', 'priority': 10},
  {'ssid': 'MobileHotspot', 'security': 'WPA3', 'priority': 5},
];

final _clientsJson = [
  {
    'callsign': 'W1AW',
    'mode': 'DMR',
    'lastHeard': '2025-03-15T14:30:00.000Z',
    'duration': 45,
  },
  {
    'callsign': 'VE3ABC',
    'mode': 'YSF',
    'lastHeard': '2025-03-15T14:25:00.000Z',
    'duration': 120,
  },
];

final _rigJson = {
  'rigs': [
    {
      'enabled': true,
      'hamlibModelId': 3085,
      'port': '/dev/ttyUSB0',
      'baud': 115200,
      'dataBits': 8,
      'stopBits': 1,
      'parity': 'none',
      'handshake': 'none',
    },
    {
      'enabled': false,
      'hamlibModelId': 1035,
      'port': '/dev/ttyUSB1',
      'baud': 38400,
      'dataBits': 8,
      'stopBits': 2,
      'parity': 'even',
      'handshake': 'hardware',
    },
  ],
};

/// Tracks the last PUT/POST request for verification.
String? _lastPutPath;
String? _lastPutBody;
String? _lastPostPath;

void main() {
  late HttpServer server;
  late OpenRigApiClient client;

  setUpAll(() async {
    server = await HttpServer.bind('localhost', 0);
    server.listen((request) async {
      final path = request.uri.path;
      final method = request.method;

      if (method == 'GET') {
        switch (path) {
          case '/api/status':
            _respond(request, _statusJson);
          case '/api/config':
            _respond(request, _configJson);
          case '/api/hotspot':
            _respond(request, _hotspotJson);
          case '/api/wifi':
            _respond(request, _wifiJson);
          case '/api/clients':
            _respond(request, _clientsJson);
          case '/api/rig':
            _respond(request, _rigJson);
          case '/api/dmrid':
            _respond(request, {'dmr_id': 3123456});
          case '/api/not-found':
            request.response.statusCode = 404;
            request.response.write('not found');
            await request.response.close();
          case '/api/server-error':
            request.response.statusCode = 500;
            request.response.write('internal error');
            await request.response.close();
          default:
            request.response.statusCode = 404;
            request.response.write('unknown path');
            await request.response.close();
        }
      } else if (method == 'PUT') {
        _lastPutPath = path;
        _lastPutBody = await utf8.decoder.bind(request).join();
        request.response.statusCode = 200;
        await request.response.close();
      } else if (method == 'POST') {
        _lastPostPath = path;
        if (path.contains('/restart')) {
          request.response.statusCode = 200;
          await request.response.close();
        } else if (path == '/api/reboot') {
          request.response.statusCode = 202;
          await request.response.close();
        } else {
          request.response.statusCode = 404;
          request.response.write('unknown');
          await request.response.close();
        }
      } else {
        request.response.statusCode = 405;
        await request.response.close();
      }
    });
  });

  tearDownAll(() async {
    await server.close();
  });

  setUp(() {
    _lastPutPath = null;
    _lastPutBody = null;
    _lastPostPath = null;
    client = OpenRigApiClient(host: 'localhost', port: server.port);
  });

  tearDown(() {
    client.dispose();
  });

  group('getStatus', () {
    test('deserializes all fields correctly', () async {
      final status = await client.getStatus();
      expect(status.type, equals('hotspot'));
      expect(status.callsign, equals('W1AW'));
      expect(status.hostname, equals('w1aw-hotspot'));
      expect(status.version, equals('0.1.0'));
      expect(status.uptime, equals(86400));
      expect(status.provisioned, isTrue);
    });
  });

  group('getConfig / updateConfig', () {
    test('getConfig deserializes correctly', () async {
      final config = await client.getConfig();
      expect(config.callsign, equals('W1AW'));
      expect(config.hostname, equals('w1aw-hotspot'));
      expect(config.timezone, equals('America/New_York'));
      expect(config.operatorName, equals('Hiram Maxim'));
      expect(config.gridSquare, equals('FN31pr'));
    });

    test('updateConfig sends correct JSON body', () async {
      const config = DeviceConfig(
        callsign: 'K1ABC',
        hostname: 'k1abc-rigctl',
        timezone: 'US/Pacific',
        operatorName: 'John Doe',
        gridSquare: 'CM87',
      );
      await client.updateConfig(config);

      expect(_lastPutPath, equals('/api/config'));
      final sent = jsonDecode(_lastPutBody!) as Map<String, dynamic>;
      expect(sent['callsign'], equals('K1ABC'));
      expect(sent['hostname'], equals('k1abc-rigctl'));
      expect(sent['timezone'], equals('US/Pacific'));
      expect(sent['operatorName'], equals('John Doe'));
      expect(sent['gridSquare'], equals('CM87'));
    });
  });

  group('getHotspot / updateHotspot', () {
    test('getHotspot deserializes nested DMR/YSF/cross-mode', () async {
      final hs = await client.getHotspot();
      expect(hs.dmr.enabled, isTrue);
      expect(hs.dmr.colorcode, equals(1));
      expect(hs.dmr.masterServer, equals('tgif.network'));
      expect(hs.dmr.talkgroups, hasLength(1));
      expect(hs.dmr.talkgroups[0].id, equals(91));

      expect(hs.ysf.enabled, isFalse);
      expect(hs.ysf.reflector, equals('US-openRig'));

      expect(hs.ysf2dmr.enabled, isTrue);
      expect(hs.ysf2dmr.talkgroup, equals(3100));

      expect(hs.dmr2ysf.enabled, isFalse);
      expect(hs.dmr2ysf.room, equals('US-openRig'));
    });

    test('updateHotspot sends correct JSON body', () async {
      const config = HotspotConfig(
        dmr: DmrConfig(
          enabled: false,
          colorcode: 3,
          masterServer: 'brandmeister.network',
          password: 'secret',
          talkgroups: [Talkgroup(id: 3100, slot: 2, name: 'USA')],
        ),
        ysf: YsfConfig(
          enabled: true,
          reflector: 'YSF-Test',
          description: 'Test',
        ),
        ysf2dmr: CrossModeConfig(enabled: false),
        dmr2ysf: CrossModeConfig(enabled: false),
      );
      await client.updateHotspot(config);

      expect(_lastPutPath, equals('/api/hotspot'));
      final sent = jsonDecode(_lastPutBody!) as Map<String, dynamic>;
      final dmr = sent['dmr'] as Map<String, dynamic>;
      expect(dmr['enabled'], isFalse);
      expect(dmr['colorcode'], equals(3));
      expect(dmr['masterServer'], equals('brandmeister.network'));
      final tgs = dmr['talkgroups'] as List;
      expect(tgs, hasLength(1));
      expect((tgs[0] as Map)['id'], equals(3100));
    });
  });

  group('getWifi / updateWifi', () {
    test('getWifi returns list of networks', () async {
      final networks = await client.getWifi();
      expect(networks, hasLength(2));
      expect(networks[0].ssid, equals('HomeWifi'));
      expect(networks[0].security, equals('WPA2'));
      expect(networks[0].priority, equals(10));
      expect(networks[1].ssid, equals('MobileHotspot'));
    });

    test('updateWifi sends correct JSON body', () async {
      const networks = [
        WifiNetwork(
          ssid: 'NewNet',
          security: 'WPA2',
          priority: 1,
          password: 'hunter2',
        ),
      ];
      await client.updateWifi(networks);

      expect(_lastPutPath, equals('/api/wifi'));
      final sent = jsonDecode(_lastPutBody!) as List<dynamic>;
      expect(sent, hasLength(1));
      final net = sent[0] as Map<String, dynamic>;
      expect(net['ssid'], equals('NewNet'));
      expect(net['password'], equals('hunter2'));
    });
  });

  group('getClients', () {
    test('returns client list with DateTime parsing', () async {
      final clients = await client.getClients();
      expect(clients, hasLength(2));
      expect(clients[0].callsign, equals('W1AW'));
      expect(clients[0].mode, equals('DMR'));
      expect(clients[0].lastHeard, equals(DateTime.utc(2025, 3, 15, 14, 30)));
      expect(clients[0].duration, equals(45));
      expect(clients[1].callsign, equals('VE3ABC'));
    });
  });

  group('getRigConfig / updateRigConfig', () {
    test('getRigConfig deserializes rig list', () async {
      final config = await client.getRigConfig();
      expect(config.rigs, hasLength(2));
      expect(config.rigs[0].enabled, isTrue);
      expect(config.rigs[0].hamlibModelId, equals(3085));
      expect(config.rigs[0].port, equals('/dev/ttyUSB0'));
      expect(config.rigs[0].baud, equals(115200));
      expect(config.rigs[0].dataBits, equals(8));
      expect(config.rigs[0].stopBits, equals(1));
      expect(config.rigs[0].parity, equals('none'));
      expect(config.rigs[0].handshake, equals('none'));

      expect(config.rigs[1].enabled, isFalse);
      expect(config.rigs[1].hamlibModelId, equals(1035));
      expect(config.rigs[1].stopBits, equals(2));
      expect(config.rigs[1].parity, equals('even'));
      expect(config.rigs[1].handshake, equals('hardware'));
    });

    test('updateRigConfig sends correct JSON body', () async {
      final config = RigConfig(rigs: [
        const ApiRigEntry(
          enabled: true,
          hamlibModelId: 3073,
          port: '/dev/ttyACM0',
          baud: 9600,
        ),
      ]);
      await client.updateRigConfig(config);

      expect(_lastPutPath, equals('/api/rig'));
      final sent = jsonDecode(_lastPutBody!) as Map<String, dynamic>;
      final rigs = sent['rigs'] as List;
      expect(rigs, hasLength(1));
      final rig = rigs[0] as Map<String, dynamic>;
      expect(rig['enabled'], isTrue);
      expect(rig['hamlibModelId'], equals(3073));
      expect(rig['port'], equals('/dev/ttyACM0'));
      expect(rig['baud'], equals(9600));
      expect(rig['dataBits'], equals(8));
      expect(rig['stopBits'], equals(1));
      expect(rig['parity'], equals('none'));
      expect(rig['handshake'], equals('none'));
    });
  });

  group('restartService', () {
    test('sends POST to correct path', () async {
      await client.restartService('dmr');
      expect(_lastPostPath, equals('/api/services/dmr/restart'));
    });

    test('sends POST with different service names', () async {
      await client.restartService('ysf');
      expect(_lastPostPath, equals('/api/services/ysf/restart'));

      await client.restartService('wifi');
      expect(_lastPostPath, equals('/api/services/wifi/restart'));
    });
  });

  group('getDmrId / updateDmrId', () {
    test('getDmrId returns parsed int', () async {
      final id = await client.getDmrId();
      expect(id, equals(3123456));
    });

    test('updateDmrId sends correct JSON body', () async {
      await client.updateDmrId(3123456);
      expect(_lastPutPath, equals('/api/dmrid'));
      final sent = jsonDecode(_lastPutBody!) as Map<String, dynamic>;
      expect(sent['dmr_id'], equals(3123456));
    });

    test('updateDmrId sends value as-is (no client validation)', () async {
      await client.updateDmrId(0);
      expect(_lastPutPath, equals('/api/dmrid'));
      final sent = jsonDecode(_lastPutBody!) as Map<String, dynamic>;
      expect(sent['dmr_id'], equals(0));
    });
  });

  group('reboot', () {
    test('completes without throwing on 202', () async {
      await client.reboot();
      expect(_lastPostPath, equals('/api/reboot'));
    });
  });

  group('OpenRigApiException', () {
    test('thrown on 404 response', () async {
      // We need a client that hits an unknown path — use a custom _getJson
      // by hitting the mock server's /api/not-found via getStatus won't work,
      // so we test with a raw HTTP call through a second client pointing to
      // a path we know returns 404.
      final badClient = OpenRigApiClient(host: 'localhost', port: server.port);
      try {
        // Trick: call getConfig but our mock only serves specific paths;
        // we'll test the exception by calling a method that hits a known 404.
        // Override: let's just verify via the exception type.
        // Actually, all our mock paths return 200. We need to trigger a 404.
        // Let's test via connect() against a server that returns 404 for /api/status.
        // Instead, let's directly test with a custom server port that's closed.
        // Simplest: spin up a tiny server that always returns 404.
        final errorServer = await HttpServer.bind('localhost', 0);
        errorServer.listen((req) async {
          req.response.statusCode = 404;
          req.response.write('not found');
          await req.response.close();
        });

        final errClient =
            OpenRigApiClient(host: 'localhost', port: errorServer.port);
        try {
          await errClient.getStatus();
          fail('Expected OpenRigApiException');
        } on OpenRigApiException catch (e) {
          expect(e.statusCode, equals(404));
          expect(e.method, equals('GET'));
          expect(e.path, equals('/api/status'));
          expect(e.body, equals('not found'));
        }

        errClient.dispose();
        await errorServer.close();
      } finally {
        badClient.dispose();
      }
    });

    test('thrown on 500 response', () async {
      final errorServer = await HttpServer.bind('localhost', 0);
      errorServer.listen((req) async {
        req.response.statusCode = 500;
        req.response.write('internal error');
        await req.response.close();
      });

      final errClient =
          OpenRigApiClient(host: 'localhost', port: errorServer.port);
      try {
        await errClient.getConfig();
        fail('Expected OpenRigApiException');
      } on OpenRigApiException catch (e) {
        expect(e.statusCode, equals(500));
        expect(e.method, equals('GET'));
        expect(e.path, equals('/api/config'));
        expect(e.body, equals('internal error'));
      }

      errClient.dispose();
      await errorServer.close();
    });

    test('includes useful toString', () {
      final ex = OpenRigApiException(
        statusCode: 404,
        method: 'GET',
        path: '/api/status',
        body: 'not found',
      );
      expect(ex.toString(),
          contains('GET /api/status returned 404: not found'));
    });
  });
}

void _respond(HttpRequest request, Object json) {
  request.response
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(json));
  request.response.close();
}
