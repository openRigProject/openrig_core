/// Multi-radio manager.
///
/// Manages multiple simultaneous rig connections. The active rig
/// is used for QSO logging and spot tuning. Supports both network
/// (TCP/rigctld) and local (FFI/libhamlib) connections.
library;

import 'dart:async';

import 'hamlib_ffi_client.dart';
import 'rig_client.dart';
import 'rigctld_client.dart';

/// Lightweight ChangeNotifier for pure Dart (no Flutter dependency).
///
/// Matches Flutter's ChangeNotifier interface so widgets can consume
/// it seamlessly via ListenableBuilder.
mixin class ChangeNotifier {
  final List<void Function()> _listeners = [];
  bool _disposed = false;

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    if (_disposed) return;
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  void dispose() {
    _disposed = true;
    _listeners.clear();
  }
}

/// How a rig is connected.
enum RigConnectionType {
  /// Network connection via TCP to a rigctld daemon.
  network,

  /// Local connection via FFI to libhamlib.
  local,
}

/// A managed rig connection.
class RigEntry {
  final String id;
  String label;
  final String host;
  final int port;
  final RigConnectionType connectionType;
  final RigClient client;
  bool connected;
  StreamSubscription<bool>? _connectionSub;

  RigEntry({
    required this.id,
    required this.label,
    required this.host,
    required this.port,
    required this.connectionType,
    required this.client,
    this.connected = false,
  });
}

/// Manages multiple simultaneous rig connections.
///
/// The active rig is the one used for QSO logging and spot tuning.
/// All rigs can be monitored simultaneously.
class RigManager with ChangeNotifier {
  final List<RigEntry> _rigs = [];
  String? _activeRigId;

  /// All managed rigs.
  List<RigEntry> get rigs => List.unmodifiable(_rigs);

  /// The active rig for TX/logging, or null if none set.
  RigEntry? get activeRig {
    if (_activeRigId == null) return null;
    return _findRig(_activeRigId!);
  }

  /// Add a network rig (TCP/rigctld) and connect to it.
  Future<RigEntry> addRig({
    required String host,
    required int port,
    String? label,
  }) async {
    final id = '$host:$port';
    if (_findRig(id) != null) {
      throw StateError('Rig $id already exists');
    }

    final client = RigctldClient(
      host: host,
      port: port,
      autoReconnect: true,
    );
    final entry = RigEntry(
      id: id,
      label: label ?? id,
      host: host,
      port: port,
      connectionType: RigConnectionType.network,
      client: client,
    );

    entry._connectionSub = client.connectionState.listen((connected) {
      if (entry.connected != connected) {
        entry.connected = connected;
        notifyListeners();
      }
    });

    _rigs.add(entry);

    try {
      await client.connect();
      entry.connected = true;
    } catch (_) {
      entry.connected = false;
    }

    // Auto-set first rig as active
    _activeRigId ??= id;

    notifyListeners();
    return entry;
  }

  /// Add a local rig via FFI (direct libhamlib) and connect to it.
  Future<RigEntry> addLocalRig({
    required int hamlibModel,
    String serialPort = '',
    int baudRate = 9600,
    int dataBits = 8,
    int stopBits = 1,
    String parity = 'none',
    String handshake = 'none',
    String? label,
  }) async {
    final id = 'local:$hamlibModel:$serialPort';
    if (_findRig(id) != null) {
      throw StateError('Rig $id already exists');
    }

    final client = HamlibFfiClient(
      hamlibModel: hamlibModel,
      serialPort: serialPort,
      baudRate: baudRate,
      dataBits: dataBits,
      stopBits: stopBits,
      parity: parity,
      handshake: handshake,
    );
    final entry = RigEntry(
      id: id,
      label: label ?? 'Local (model $hamlibModel)',
      host: 'local',
      port: 0,
      connectionType: RigConnectionType.local,
      client: client,
    );

    entry._connectionSub = client.connectionState.listen((connected) {
      if (entry.connected != connected) {
        entry.connected = connected;
        notifyListeners();
      }
    });

    _rigs.add(entry);

    try {
      await client.connect();
      entry.connected = true;
    } catch (_) {
      entry.connected = false;
    }

    _activeRigId ??= id;

    notifyListeners();
    return entry;
  }

  /// Remove a rig by id. Disconnects if connected.
  void removeRig(String id) {
    final entry = _findRig(id);
    if (entry == null) return;

    entry._connectionSub?.cancel();
    entry.client.dispose();
    entry.connected = false;

    _rigs.remove(entry);

    if (_activeRigId == id) {
      _activeRigId = _rigs.isNotEmpty ? _rigs.first.id : null;
    }

    notifyListeners();
  }

  /// Rename a rig.
  void renameRig(String id, String label) {
    final entry = _findRig(id);
    if (entry == null) throw ArgumentError('No rig with id $id');
    entry.label = label;
    notifyListeners();
  }

  /// Set the active rig by id.
  void setActiveRig(String id) {
    if (_findRig(id) == null) {
      throw ArgumentError('No rig with id $id');
    }
    _activeRigId = id;
    notifyListeners();
  }

  /// Connect an individual rig.
  Future<void> connectRig(String id) async {
    final entry = _findRig(id);
    if (entry == null) throw ArgumentError('No rig with id $id');
    if (entry.connected) return;

    await entry.client.connect();
    entry.connected = true;
    notifyListeners();
  }

  /// Disconnect an individual rig.
  Future<void> disconnectRig(String id) async {
    final entry = _findRig(id);
    if (entry == null) throw ArgumentError('No rig with id $id');
    if (!entry.connected) return;

    await entry.client.disconnect();
    entry.connected = false;
    notifyListeners();
  }

  /// Disconnect all rigs and clean up.
  @override
  void dispose() {
    for (final entry in _rigs) {
      entry._connectionSub?.cancel();
      entry.client.dispose();
      entry.connected = false;
    }
    _rigs.clear();
    _activeRigId = null;
    super.dispose();
  }

  RigEntry? _findRig(String id) {
    for (final rig in _rigs) {
      if (rig.id == id) return rig;
    }
    return null;
  }
}
