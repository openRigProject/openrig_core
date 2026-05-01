import 'dart:io';
import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

/// Tests for RigManager using hamlib model 1 (Dummy rig).
void main() {
  late Process rigctld1;
  late Process rigctld2;
  const port1 = 14700;
  const port2 = 14701;

  setUpAll(() async {
    rigctld1 = await Process.start('rigctld', ['-m', '1', '-t', '$port1']);
    rigctld2 = await Process.start('rigctld', ['-m', '1', '-t', '$port2']);
    await Future.delayed(const Duration(milliseconds: 500));
  });

  tearDownAll(() async {
    rigctld1.kill();
    rigctld2.kill();
    await rigctld1.exitCode;
    await rigctld2.exitCode;
  });

  test('addRig creates a RigEntry and connects', () async {
    final manager = RigManager();

    final entry = await manager.addRig(
      host: 'localhost',
      port: port1,
      label: 'Dummy Rig 1',
    );

    expect(entry.id, equals('localhost:$port1'));
    expect(entry.label, equals('Dummy Rig 1'));
    expect(entry.connected, isTrue);
    expect(entry.client.isConnected, isTrue);
    expect(manager.rigs, hasLength(1));

    manager.dispose();
  });

  test('addRig auto-sets first rig as active', () async {
    final manager = RigManager();

    await manager.addRig(host: 'localhost', port: port1);

    expect(manager.activeRig, isNotNull);
    expect(manager.activeRig!.id, equals('localhost:$port1'));

    manager.dispose();
  });

  test('addRig uses host:port as default label', () async {
    final manager = RigManager();

    final entry = await manager.addRig(host: 'localhost', port: port1);
    expect(entry.label, equals('localhost:$port1'));

    manager.dispose();
  });

  test('addRig throws on duplicate id', () async {
    final manager = RigManager();

    await manager.addRig(host: 'localhost', port: port1);
    expect(
      () => manager.addRig(host: 'localhost', port: port1),
      throwsA(isA<StateError>()),
    );

    manager.dispose();
  });

  test('removeRig disconnects and removes', () async {
    final manager = RigManager();

    final entry = await manager.addRig(host: 'localhost', port: port1);
    expect(manager.rigs, hasLength(1));

    manager.removeRig(entry.id);

    expect(manager.rigs, isEmpty);
    expect(entry.connected, isFalse);
  });

  test('removeRig shifts active to next rig', () async {
    final manager = RigManager();

    final rig1 = await manager.addRig(
      host: 'localhost',
      port: port1,
      label: 'Rig 1',
    );
    await manager.addRig(
      host: 'localhost',
      port: port2,
      label: 'Rig 2',
    );

    expect(manager.activeRig!.id, equals(rig1.id));

    manager.removeRig(rig1.id);

    expect(manager.activeRig, isNotNull);
    expect(manager.activeRig!.id, equals('localhost:$port2'));

    manager.dispose();
  });

  test('removeRig clears active when last rig removed', () async {
    final manager = RigManager();

    final entry = await manager.addRig(host: 'localhost', port: port1);
    manager.removeRig(entry.id);

    expect(manager.activeRig, isNull);
  });

  test('setActiveRig updates activeRig', () async {
    final manager = RigManager();

    await manager.addRig(host: 'localhost', port: port1, label: 'Rig 1');
    await manager.addRig(host: 'localhost', port: port2, label: 'Rig 2');

    expect(manager.activeRig!.label, equals('Rig 1'));

    manager.setActiveRig('localhost:$port2');

    expect(manager.activeRig!.label, equals('Rig 2'));

    manager.dispose();
  });

  test('setActiveRig throws for unknown id', () async {
    final manager = RigManager();

    expect(
      () => manager.setActiveRig('nonexistent'),
      throwsA(isA<ArgumentError>()),
    );

    manager.dispose();
  });

  test('multiple rigs can be monitored simultaneously', () async {
    final manager = RigManager();

    final rig1 = await manager.addRig(
      host: 'localhost',
      port: port1,
      label: 'Rig 1',
    );
    final rig2 = await manager.addRig(
      host: 'localhost',
      port: port2,
      label: 'Rig 2',
    );

    expect(rig1.connected, isTrue);
    expect(rig2.connected, isTrue);
    expect(manager.rigs, hasLength(2));

    // Both rigs can be queried independently
    final freq1 = await rig1.client.getFrequency();
    final freq2 = await rig2.client.getFrequency();
    expect(freq1, isA<int>());
    expect(freq2, isA<int>());

    manager.dispose();
  });

  test('connectRig / disconnectRig individual rigs', () async {
    final manager = RigManager();

    final entry = await manager.addRig(host: 'localhost', port: port1);
    expect(entry.connected, isTrue);

    await manager.disconnectRig(entry.id);
    expect(entry.connected, isFalse);
    expect(entry.client.isConnected, isFalse);

    await manager.connectRig(entry.id);
    expect(entry.connected, isTrue);
    expect(entry.client.isConnected, isTrue);

    manager.dispose();
  });

  test('connectRig throws for unknown id', () async {
    final manager = RigManager();

    expect(
      () => manager.connectRig('nonexistent'),
      throwsA(isA<ArgumentError>()),
    );

    manager.dispose();
  });

  test('dispose closes all connections', () async {
    final manager = RigManager();

    final rig1 = await manager.addRig(host: 'localhost', port: port1);
    final rig2 = await manager.addRig(host: 'localhost', port: port2);

    expect(rig1.connected, isTrue);
    expect(rig2.connected, isTrue);

    manager.dispose();

    expect(rig1.connected, isFalse);
    expect(rig2.connected, isFalse);
    expect(manager.rigs, isEmpty);
    expect(manager.activeRig, isNull);
  });

  test('notifies listeners on add/remove/setActive', () async {
    final manager = RigManager();
    var notifyCount = 0;
    manager.addListener(() => notifyCount++);

    await manager.addRig(host: 'localhost', port: port1);
    expect(notifyCount, equals(1));

    await manager.addRig(host: 'localhost', port: port2);
    expect(notifyCount, equals(2));

    manager.setActiveRig('localhost:$port2');
    expect(notifyCount, equals(3));

    manager.removeRig('localhost:$port1');
    expect(notifyCount, equals(4));

    manager.dispose();
  });
}
