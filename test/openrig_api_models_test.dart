import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceStatus', () {
    test('fromJson/toJson round-trips', () {
      final json = {
        'type': 'hotspot',
        'callsign': 'W1AW',
        'hostname': 'w1aw-hotspot',
        'version': '0.1.0',
        'uptime': 86400,
        'provisioned': true,
      };

      final status = DeviceStatus.fromJson(json);
      expect(status.type, equals('hotspot'));
      expect(status.callsign, equals('W1AW'));
      expect(status.hostname, equals('w1aw-hotspot'));
      expect(status.version, equals('0.1.0'));
      expect(status.uptime, equals(86400));
      expect(status.provisioned, isTrue);

      final roundTripped = DeviceStatus.fromJson(status.toJson());
      expect(roundTripped.type, equals(status.type));
      expect(roundTripped.callsign, equals(status.callsign));
      expect(roundTripped.uptime, equals(status.uptime));
    });

    test('system metrics default to zero when absent from JSON', () {
      final json = {
        'type': 'hotspot',
        'callsign': 'W1AW',
        'hostname': 'w1aw-hotspot',
        'version': '0.1.0',
        'provisioned': true,
      };
      final status = DeviceStatus.fromJson(json);
      expect(status.uptime, equals(0));
      expect(status.cpuPercent, equals(0.0));
      expect(status.memTotalMb, equals(0));
      expect(status.memUsedMb, equals(0));
      expect(status.diskTotalGb, equals(0.0));
      expect(status.diskUsedGb, equals(0.0));
    });

    test('system metrics round-trip via JSON', () {
      const status = DeviceStatus(
        type: 'hotspot',
        callsign: 'W1AW',
        hostname: 'w1aw-hotspot',
        version: '0.1.0',
        uptime: 9240,
        provisioned: true,
        cpuPercent: 42.5,
        memTotalMb: 1024,
        memUsedMb: 512,
        diskTotalGb: 32.0,
        diskUsedGb: 8.5,
      );
      final json = status.toJson();
      expect(json['cpu_percent'], equals(42.5));
      expect(json['mem_total_mb'], equals(1024));
      expect(json['mem_used_mb'], equals(512));
      expect(json['disk_total_gb'], equals(32.0));
      expect(json['disk_used_gb'], equals(8.5));

      final rt = DeviceStatus.fromJson(json);
      expect(rt.cpuPercent, equals(42.5));
      expect(rt.memTotalMb, equals(1024));
      expect(rt.memUsedMb, equals(512));
      expect(rt.diskTotalGb, equals(32.0));
      expect(rt.diskUsedGb, equals(8.5));
    });

    test('uptimeFormatted for various durations', () {
      const base = DeviceStatus(
        type: 'hotspot',
        callsign: 'W1AW',
        hostname: 'h',
        version: '0.1.0',
        provisioned: true,
      );

      // < 1 minute
      const s0 = DeviceStatus(
        type: 'hotspot', callsign: 'W1AW', hostname: 'h',
        version: '0.1.0', provisioned: true, uptime: 30,
      );
      expect(s0.uptimeFormatted, equals('< 1m'));

      // exactly 0 seconds
      expect(base.uptimeFormatted, equals('< 1m'));

      // 45 minutes
      const s45m = DeviceStatus(
        type: 'hotspot', callsign: 'W1AW', hostname: 'h',
        version: '0.1.0', provisioned: true, uptime: 2700,
      );
      expect(s45m.uptimeFormatted, equals('45m'));

      // 2h 34m
      const s2h34 = DeviceStatus(
        type: 'hotspot', callsign: 'W1AW', hostname: 'h',
        version: '0.1.0', provisioned: true, uptime: 9240,
      );
      expect(s2h34.uptimeFormatted, equals('2h 34m'));

      // 24h 0m
      const s24h = DeviceStatus(
        type: 'hotspot', callsign: 'W1AW', hostname: 'h',
        version: '0.1.0', provisioned: true, uptime: 86400,
      );
      expect(s24h.uptimeFormatted, equals('24h 0m'));
    });
  });

  group('DeviceConfig', () {
    test('fromJson/toJson round-trips', () {
      final json = {
        'callsign': 'W1AW',
        'hostname': 'w1aw-hotspot',
        'timezone': 'America/New_York',
        'operatorName': 'Hiram Maxim',
        'gridSquare': 'FN31pr',
      };

      final config = DeviceConfig.fromJson(json);
      expect(config.callsign, equals('W1AW'));
      expect(config.operatorName, equals('Hiram Maxim'));
      expect(config.gridSquare, equals('FN31pr'));

      expect(DeviceConfig.fromJson(config.toJson()).timezone,
          equals('America/New_York'));
    });
  });

  group('HotspotConfig', () {
    final fullJson = {
      'dmr': {
        'enabled': true,
        'colorcode': 1,
        'masterServer': 'tgif.network',
        'password': 'passw0rd',
        'talkgroups': [
          {'id': 91, 'slot': 1, 'name': 'Worldwide'},
          {'id': 3100, 'slot': 2, 'name': 'USA'},
        ],
      },
      'ysf': {
        'enabled': false,
        'reflector': 'US-openRig',
        'description': 'openRig YSF',
      },
      'ysf2dmr': {
        'enabled': true,
        'talkgroup': 3100,
      },
      'dmr2ysf': {
        'enabled': false,
        'room': 'US-openRig',
      },
    };

    test('fromJson/toJson round-trips with nested configs', () {
      final config = HotspotConfig.fromJson(fullJson);

      // DMR
      expect(config.dmr.enabled, isTrue);
      expect(config.dmr.colorcode, equals(1));
      expect(config.dmr.masterServer, equals('tgif.network'));
      expect(config.dmr.password, equals('passw0rd'));
      expect(config.dmr.talkgroups, hasLength(2));
      expect(config.dmr.talkgroups[0].id, equals(91));
      expect(config.dmr.talkgroups[0].slot, equals(1));
      expect(config.dmr.talkgroups[0].name, equals('Worldwide'));
      expect(config.dmr.talkgroups[1].id, equals(3100));

      // YSF
      expect(config.ysf.enabled, isFalse);
      expect(config.ysf.reflector, equals('US-openRig'));
      expect(config.ysf.description, equals('openRig YSF'));

      // Cross-mode
      expect(config.ysf2dmr.enabled, isTrue);
      expect(config.ysf2dmr.talkgroup, equals(3100));
      expect(config.ysf2dmr.room, isNull);

      expect(config.dmr2ysf.enabled, isFalse);
      expect(config.dmr2ysf.room, equals('US-openRig'));
      expect(config.dmr2ysf.talkgroup, isNull);

      // Round-trip
      final rt = HotspotConfig.fromJson(config.toJson());
      expect(rt.dmr.talkgroups, hasLength(2));
      expect(rt.ysf2dmr.talkgroup, equals(3100));
      expect(rt.dmr2ysf.room, equals('US-openRig'));
    });

    test('CrossModeConfig.toJson omits null fields', () {
      const cfg = CrossModeConfig(enabled: true, talkgroup: 91);
      final json = cfg.toJson();
      expect(json.containsKey('talkgroup'), isTrue);
      expect(json.containsKey('room'), isFalse);

      const cfg2 = CrossModeConfig(enabled: false);
      final json2 = cfg2.toJson();
      expect(json2.containsKey('talkgroup'), isFalse);
      expect(json2.containsKey('room'), isFalse);
    });

    test('DmrConfig.dmrId defaults to 0 when missing from JSON', () {
      final json = {
        'enabled': true,
        'colorcode': 1,
        'masterServer': 'tgif.network',
        'password': 'passw0rd',
        'talkgroups': <Map<String, dynamic>>[],
      };
      final dmr = DmrConfig.fromJson(json);
      expect(dmr.dmrId, equals(0));
    });

    test('DmrConfig.dmrId round-trips via JSON', () {
      const dmr = DmrConfig(
        enabled: true,
        colorcode: 1,
        masterServer: 'tgif.network',
        password: 'passw0rd',
        talkgroups: [],
        dmrId: 1234567,
      );
      final json = dmr.toJson();
      expect(json['dmr_id'], equals(1234567));

      final rt = DmrConfig.fromJson(json);
      expect(rt.dmrId, equals(1234567));
    });

    test('YsfConfig.suffix defaults to empty when missing from JSON', () {
      final json = {
        'enabled': false,
        'reflector': 'US-openRig',
        'description': 'openRig YSF',
      };
      final ysf = YsfConfig.fromJson(json);
      expect(ysf.suffix, equals(''));
    });

    test('YsfConfig.suffix round-trips via JSON', () {
      const ysf = YsfConfig(
        enabled: true,
        reflector: 'AMERICA',
        description: 'Test',
        suffix: 'RPT',
      );
      final json = ysf.toJson();
      expect(json['suffix'], equals('RPT'));

      final rt = YsfConfig.fromJson(json);
      expect(rt.suffix, equals('RPT'));
    });

  });

  group('WifiNetwork', () {
    test('toJson omits null password', () {
      const net = WifiNetwork(
        ssid: 'HomeWifi',
        security: 'WPA2',
        priority: 10,
      );
      final json = net.toJson();
      expect(json['ssid'], equals('HomeWifi'));
      expect(json['security'], equals('WPA2'));
      expect(json['priority'], equals(10));
      expect(json.containsKey('password'), isFalse);
    });

    test('toJson includes password when present', () {
      const net = WifiNetwork(
        ssid: 'HomeWifi',
        security: 'WPA2',
        priority: 10,
        password: 'secret123',
      );
      final json = net.toJson();
      expect(json['password'], equals('secret123'));
    });

    test('fromJson handles missing password', () {
      final json = {
        'ssid': 'OpenNet',
        'security': 'NONE',
        'priority': 5,
      };
      final net = WifiNetwork.fromJson(json);
      expect(net.ssid, equals('OpenNet'));
      expect(net.password, isNull);
    });
  });

  group('ScannedNetwork', () {
    test('fromJson parses all fields', () {
      final json = {
        'ssid': 'HomeWifi',
        'signal': 85,
        'security': 'WPA2',
      };
      final net = ScannedNetwork.fromJson(json);
      expect(net.ssid, equals('HomeWifi'));
      expect(net.signal, equals(85));
      expect(net.security, equals('WPA2'));
    });

    test('toJson round-trips correctly', () {
      const net = ScannedNetwork(
        ssid: 'GuestNet',
        signal: 42,
        security: 'OPEN',
      );
      final rt = ScannedNetwork.fromJson(net.toJson());
      expect(rt.ssid, equals('GuestNet'));
      expect(rt.signal, equals(42));
      expect(rt.security, equals('OPEN'));
    });
  });

  group('ApiRigEntry', () {
    test('fromJson/toJson round-trips', () {
      final json = {
        'enabled': true,
        'hamlibModelId': 3085,
        'port': '/dev/ttyUSB0',
        'baud': 115200,
        'dataBits': 8,
        'stopBits': 1,
        'parity': 'none',
        'handshake': 'none',
      };

      final entry = ApiRigEntry.fromJson(json);
      expect(entry.enabled, isTrue);
      expect(entry.hamlibModelId, equals(3085));
      expect(entry.port, equals('/dev/ttyUSB0'));
      expect(entry.baud, equals(115200));
      expect(entry.dataBits, equals(8));
      expect(entry.stopBits, equals(1));
      expect(entry.parity, equals('none'));
      expect(entry.handshake, equals('none'));

      final rt = ApiRigEntry.fromJson(entry.toJson());
      expect(rt.hamlibModelId, equals(3085));
      expect(rt.baud, equals(115200));
    });

    test('fromJson uses defaults for optional fields', () {
      final json = {
        'enabled': true,
        'hamlibModelId': 1,
        'port': '/dev/ttyUSB0',
        'baud': 9600,
      };

      final entry = ApiRigEntry.fromJson(json);
      expect(entry.dataBits, equals(8));
      expect(entry.stopBits, equals(1));
      expect(entry.parity, equals('none'));
      expect(entry.handshake, equals('none'));
    });
  });

  group('RigConfig', () {
    test('fromJson/toJson round-trips with multiple rigs', () {
      final json = {
        'rigs': [
          {
            'enabled': true,
            'hamlibModelId': 3085,
            'port': '/dev/ttyUSB0',
            'baud': 115200,
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

      final config = RigConfig.fromJson(json);
      expect(config.rigs, hasLength(2));
      expect(config.rigs[0].hamlibModelId, equals(3085));
      expect(config.rigs[1].parity, equals('even'));
      expect(config.rigs[1].stopBits, equals(2));

      final rt = RigConfig.fromJson(config.toJson());
      expect(rt.rigs, hasLength(2));
      expect(rt.rigs[1].handshake, equals('hardware'));
    });

    test('fromJson handles empty rigs list', () {
      final json = {'rigs': <Map<String, dynamic>>[]};
      final config = RigConfig.fromJson(json);
      expect(config.rigs, isEmpty);
    });
  });

  group('HotspotClient', () {
    test('fromJson parses lastHeard as DateTime', () {
      final json = {
        'callsign': 'W1AW',
        'mode': 'DMR',
        'lastHeard': '2025-03-15T14:30:00.000Z',
        'duration': 45,
      };

      final client = HotspotClient.fromJson(json);
      expect(client.callsign, equals('W1AW'));
      expect(client.mode, equals('DMR'));
      expect(client.lastHeard, equals(DateTime.utc(2025, 3, 15, 14, 30)));
      expect(client.duration, equals(45));
    });

    test('toJson serializes lastHeard as ISO 8601', () {
      final client = HotspotClient(
        callsign: 'VE3ABC',
        mode: 'YSF',
        lastHeard: DateTime.utc(2025, 6, 1, 12, 0, 0),
        duration: 120,
      );
      final json = client.toJson();
      expect(json['lastHeard'], equals('2025-06-01T12:00:00.000Z'));
    });
  });

  group('NetworkStatus', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'mode': 'wifi',
        'ssid': 'HomeNetwork',
        'ip': '192.168.1.42',
        'signal_dbm': -65,
        'connected': true,
        'interface': 'wlan0',
      };
      final status = NetworkStatus.fromJson(json);
      expect(status.mode, equals('wifi'));
      expect(status.ssid, equals('HomeNetwork'));
      expect(status.ip, equals('192.168.1.42'));
      expect(status.signalDbm, equals(-65));
      expect(status.connected, isTrue);
      expect(status.networkInterface, equals('wlan0'));
    });

    test('fromJson defaults missing fields', () {
      final json = <String, dynamic>{};
      final status = NetworkStatus.fromJson(json);
      expect(status.mode, equals('none'));
      expect(status.ssid, equals(''));
      expect(status.ip, equals(''));
      expect(status.signalDbm, equals(0));
      expect(status.connected, isFalse);
      expect(status.networkInterface, equals(''));
    });

    test('toJson round-trips', () {
      final json = {
        'mode': 'ethernet',
        'ssid': '',
        'ip': '10.0.0.5',
        'signal_dbm': 0,
        'connected': true,
        'interface': 'eth0',
      };
      final status = NetworkStatus.fromJson(json);
      final rt = NetworkStatus.fromJson(status.toJson());
      expect(rt.mode, equals('ethernet'));
      expect(rt.ip, equals('10.0.0.5'));
      expect(rt.connected, isTrue);
      expect(rt.networkInterface, equals('eth0'));
    });

    test('toJson serializes networkInterface as "interface"', () {
      const status = NetworkStatus(
        mode: 'ap',
        ssid: 'openRig-AP',
        ip: '192.168.4.1',
        signalDbm: 0,
        connected: true,
        networkInterface: 'wlan0',
      );
      final json = status.toJson();
      expect(json.containsKey('interface'), isTrue);
      expect(json['interface'], equals('wlan0'));
      expect(json.containsKey('networkInterface'), isFalse);
    });
  });
}
