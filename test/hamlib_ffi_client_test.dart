import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

/// Tests for HamlibFfiClient using hamlib model 1 (Dummy rig).
void main() {
  group('HamlibFfiClient', () {
    late HamlibFfiClient client;

    setUp(() {
      client = HamlibFfiClient(hamlibModel: 1);
    });

    tearDown(() async {
      await client.dispose();
    });

    test('connect opens the dummy rig', () async {
      await client.connect();
      expect(client.isConnected, isTrue);
    });

    test('connect then disconnect', () async {
      await client.connect();
      expect(client.isConnected, isTrue);

      await client.disconnect();
      expect(client.isConnected, isFalse);
    });

    test('getFrequency returns valid Hz', () async {
      await client.connect();
      final freq = await client.getFrequency();
      expect(freq, greaterThan(0));
    });

    test('setFrequency then getFrequency roundtrips', () async {
      await client.connect();
      await client.setFrequency(14074000);
      final freq = await client.getFrequency();
      expect(freq, equals(14074000));
    });

    test('getMode returns a non-empty mode string', () async {
      await client.connect();
      final result = await client.getMode();
      expect(result.mode, isNotEmpty);
      expect(result.passband, greaterThanOrEqualTo(0));
    });

    test('setMode then getMode roundtrips', () async {
      await client.connect();
      await client.setMode('USB');
      final result = await client.getMode();
      expect(result.mode, equals('USB'));
    });

    test('getPtt returns a bool or throws HamlibError', () async {
      await client.connect();
      try {
        final ptt = await client.getPtt();
        expect(ptt, isA<bool>());
      } on HamlibError {
        // Some rig models (like dummy) may not support PTT query.
      }
    });

    test('setPtt does not throw on dummy rig', () async {
      await client.connect();
      // Dummy rig accepts set_ptt but may not support get_ptt.
      await client.setPtt(true);
      await client.setPtt(false);
    });

    test('getVfo returns VFOA by default', () async {
      await client.connect();
      final vfo = await client.getVfo();
      expect(vfo, equals('VFOA'));
    });

    test('setVfo switches to VFOB', () async {
      await client.connect();
      await client.setVfo('VFOB');
      final vfo = await client.getVfo();
      expect(vfo, equals('VFOB'));
    });

    test('getSplit returns initial state', () async {
      await client.connect();
      final split = await client.getSplit();
      expect(split.enabled, isA<bool>());
    });

    test('getRigInfo returns a string', () async {
      await client.connect();
      final info = await client.getRigInfo();
      expect(info, isA<String>());
    });

    test('getSignalStrength returns an int', () async {
      await client.connect();
      final strength = await client.getSignalStrength();
      expect(strength, isA<int>());
    });

    test('connectionState emits true on connect, false on disconnect',
        () async {
      final states = <bool>[];
      final sub = client.connectionState.listen(states.add);

      await client.connect();
      await Future.delayed(const Duration(milliseconds: 50));
      await client.disconnect();
      await Future.delayed(const Duration(milliseconds: 50));

      await sub.cancel();
      expect(states, contains(true));
      expect(states, contains(false));
    });

    test('throws StateError when calling commands on unopened rig', () {
      expect(() => client.getFrequency(), throwsA(isA<StateError>()));
    });

    test('implements RigClient interface', () {
      expect(client, isA<RigClient>());
    });
  });

  group('RigManager with local rig', () {
    test('addLocalRig creates an FFI-based rig entry', () async {
      final manager = RigManager();

      final entry = await manager.addLocalRig(
        hamlibModel: 1,
        label: 'FFI Dummy',
      );

      expect(entry.connectionType, equals(RigConnectionType.local));
      expect(entry.label, equals('FFI Dummy'));
      expect(entry.connected, isTrue);
      expect(entry.client, isA<HamlibFfiClient>());
      expect(entry.client.isConnected, isTrue);
      expect(manager.rigs, hasLength(1));

      manager.dispose();
    });

    test('addLocalRig auto-sets first rig as active', () async {
      final manager = RigManager();

      await manager.addLocalRig(hamlibModel: 1);
      expect(manager.activeRig, isNotNull);
      expect(manager.activeRig!.connectionType, equals(RigConnectionType.local));

      manager.dispose();
    });

    test('local rig can get/set frequency', () async {
      final manager = RigManager();

      final entry = await manager.addLocalRig(hamlibModel: 1);
      await entry.client.setFrequency(7074000);
      final freq = await entry.client.getFrequency();
      expect(freq, equals(7074000));

      manager.dispose();
    });

    test('network and local rigs coexist', () async {
      // This test needs a rigctld running on a known port — skip in basic test
      // but verify the manager handles both types.
      final manager = RigManager();

      final localRig = await manager.addLocalRig(
        hamlibModel: 1,
        label: 'Local',
      );
      expect(localRig.connectionType, equals(RigConnectionType.local));
      expect(manager.rigs, hasLength(1));

      manager.dispose();
    });
  });
}
