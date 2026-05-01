import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

void main() {
  group('parseTxtRecord', () {
    test('parses standard openRig TXT record', () {
      // multicast_dns concatenates length-prefixed entries with newlines
      const txt = 'provisioned=true\ntype=rigctl\ncallsign=W1AW\nversion=0.1.0\n';
      final map = parseTxtRecord(txt);

      expect(map['provisioned'], equals('true'));
      expect(map['type'], equals('rigctl'));
      expect(map['callsign'], equals('W1AW'));
      expect(map['version'], equals('0.1.0'));
    });

    test('lowercases keys', () {
      const txt = 'Provisioned=true\nTYPE=hotspot\n';
      final map = parseTxtRecord(txt);

      expect(map['provisioned'], equals('true'));
      expect(map['type'], equals('hotspot'));
    });

    test('handles empty string', () {
      final map = parseTxtRecord('');
      expect(map, isEmpty);
    });

    test('skips lines without equals sign', () {
      const txt = 'provisioned=true\nbadline\ntype=rigctl\n';
      final map = parseTxtRecord(txt);

      expect(map, hasLength(2));
      expect(map['provisioned'], equals('true'));
      expect(map['type'], equals('rigctl'));
    });

    test('handles value with equals sign in it', () {
      const txt = 'key=value=with=equals\n';
      final map = parseTxtRecord(txt);

      expect(map['key'], equals('value=with=equals'));
    });

    test('handles trailing whitespace and blank lines', () {
      const txt = '  provisioned=true  \n\n  type=rigctl  \n\n';
      final map = parseTxtRecord(txt);

      expect(map['provisioned'], equals('true'));
      expect(map['type'], equals('rigctl'));
    });
  });

  group('OpenRigDevice', () {
    test('constructs with required fields', () {
      const device = OpenRigDevice(
        name: 'openRig w1aw-rigctl',
        host: '192.168.1.100',
        port: 7373,
        provisioned: true,
        type: 'rigctl',
        callsign: 'W1AW',
        version: '0.1.0',
      );

      expect(device.name, equals('openRig w1aw-rigctl'));
      expect(device.hasRigctld, isFalse);
      expect(device.rigctldPort, isNull);
    });

    test('copyWith updates rigctld fields', () {
      const device = OpenRigDevice(
        name: 'test',
        host: '10.0.0.1',
        port: 7373,
        provisioned: true,
        type: 'rigctl',
        callsign: 'W1AW',
        version: '0.1.0',
      );

      final updated = device.copyWith(hasRigctld: true, rigctldPort: 4532);
      expect(updated.hasRigctld, isTrue);
      expect(updated.rigctldPort, equals(4532));
      // Original fields preserved
      expect(updated.host, equals('10.0.0.1'));
      expect(updated.callsign, equals('W1AW'));
    });
  });
}
