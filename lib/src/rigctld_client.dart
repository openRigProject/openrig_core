/// rigctld TCP client.
///
/// Connects to a hamlib rigctld daemon (local sidecar or remote openRigOS)
/// and exposes rig control as async Dart methods.
///
/// Uses the rigctld extended response protocol (commands prefixed with '+')
/// so that every response is terminated by 'RPRT <code>\n'.
///
/// Protocol: plain-text over TCP (default port 4532).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'rig_client.dart';

/// Error returned by rigctld when a command fails.
class RigctldError implements Exception {
  final int code;
  final String command;
  RigctldError(this.code, this.command);

  @override
  String toString() => 'RigctldError: command "$command" failed with code $code';
}

/// Strip "Label: " prefix from extended-protocol response lines.
String _stripLabel(String line) {
  final colon = line.indexOf(': ');
  return colon >= 0 ? line.substring(colon + 2) : line;
}

/// A single connection to a rigctld instance.
class RigctldClient implements RigClient {
  final String host;
  final int port;
  final bool autoReconnect;

  Socket? _socket;
  final StreamController<String> _lines = StreamController.broadcast();
  StreamSubscription<String>? _subscription;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  bool _reconnecting = false;
  bool _disposed = false;

  RigctldClient({
    required this.host,
    this.port = 4532,
    this.autoReconnect = false,
  });

  /// Emits true when connected, false when disconnected.
  Stream<bool> get connectionState => _connectionController.stream;

  Future<void> connect() async {
    _socket = await Socket.connect(host, port);
    _subscription = utf8.decoder
        .bind(_socket!)
        .transform(const LineSplitter())
        .listen(
          _lines.add,
          onError: (_) => _onConnectionLost(),
          onDone: _onConnectionLost,
        );
    if (!_disposed) _connectionController.add(true);
  }

  Future<void> disconnect() async {
    _reconnecting = false;
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
    if (!_disposed) _connectionController.add(false);
  }

  /// Stop polling and close all resources.
  Future<void> dispose() async {
    _disposed = true;
    _reconnecting = false;
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
    await _connectionController.close();
  }

  bool get isConnected => _socket != null;

  void _onConnectionLost() {
    _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
    if (!_disposed) _connectionController.add(false);
    if (autoReconnect && !_disposed) {
      _startReconnect();
    }
  }

  void _startReconnect() {
    if (_reconnecting) return;
    _reconnecting = true;
    _reconnectLoop();
  }

  Future<void> _reconnectLoop() async {
    var delay = const Duration(seconds: 1);
    const maxDelay = Duration(seconds: 30);

    while (_reconnecting && !_disposed) {
      await Future.delayed(delay);
      if (!_reconnecting || _disposed) break;
      try {
        await connect();
        _reconnecting = false;
        return;
      } catch (_) {
        // Back off: 1s, 2s, 4s, 8s, ..., max 30s
        delay = Duration(
          milliseconds: min(delay.inMilliseconds * 2, maxDelay.inMilliseconds),
        );
      }
    }
  }

  /// Send a command using the extended response protocol ('+' prefix).
  ///
  /// Collects response lines until RPRT. Skips the command echo header
  /// (e.g. "get_freq:") and strips "Label: " prefixes from value lines.
  Future<List<String>> _command(String cmd) async {
    if (_socket == null) throw StateError('Not connected');
    final completer = Completer<List<String>>();
    final values = <String>[];
    late StreamSubscription<String> sub;
    sub = _lines.stream.listen((line) {
      if (line.startsWith('RPRT ')) {
        sub.cancel();
        final code = int.tryParse(line.substring(5).trim()) ?? -1;
        if (code != 0) {
          completer.completeError(RigctldError(code, cmd));
        } else {
          completer.complete(values);
        }
      } else if (line.endsWith(':')) {
        // Command echo header (e.g. "get_freq:") — skip
      } else {
        values.add(_stripLabel(line));
      }
    });
    // '+' prefix enables extended response protocol
    _socket!.write('+$cmd\n');
    return completer.future;
  }

  /// Send a command that returns a single value.
  Future<String> _queryOne(String cmd) async {
    final lines = await _command(cmd);
    if (lines.isEmpty) return '';
    return lines.first;
  }

  // -- Frequency --

  /// Get the current VFO frequency in Hz.
  Future<int> getFrequency() async {
    final resp = await _queryOne(r'\get_freq');
    return int.parse(resp.trim());
  }

  /// Set the VFO frequency in Hz.
  Future<void> setFrequency(int hz) async {
    await _command('\\set_freq $hz');
  }

  // -- Mode --

  /// Get the current mode and passband width.
  Future<({String mode, int passband})> getMode() async {
    final lines = await _command(r'\get_mode');
    final mode = lines.isNotEmpty ? lines[0].trim() : '';
    final passband = lines.length > 1 ? int.tryParse(lines[1].trim()) ?? 0 : 0;
    return (mode: mode, passband: passband);
  }

  /// Set the mode and passband width.
  /// Pass passband 0 to let rigctld pick a default.
  Future<void> setMode(String mode, {int passband = 0}) async {
    await _command('\\set_mode $mode $passband');
  }

  // -- PTT --

  /// Get PTT state. Returns true if transmitting.
  Future<bool> getPtt() async {
    final resp = await _queryOne(r'\get_ptt');
    return resp.trim() != '0';
  }

  /// Set PTT state.
  Future<void> setPtt(bool on) async {
    await _command('\\set_ptt ${on ? 1 : 0}');
  }

  // -- VFO --

  /// Get the current VFO name (e.g. 'VFOA', 'VFOB').
  Future<String> getVfo() async {
    final resp = await _queryOne(r'\get_vfo');
    return resp.trim();
  }

  /// Set the current VFO.
  Future<void> setVfo(String vfo) async {
    await _command('\\set_vfo $vfo');
  }

  // -- Split --

  /// Get split status.
  Future<({bool enabled, String txVfo})> getSplit() async {
    final lines = await _command(r'\get_split_vfo');
    final enabled = lines.isNotEmpty && lines[0].trim() != '0';
    final txVfo = lines.length > 1 ? lines[1].trim() : '';
    return (enabled: enabled, txVfo: txVfo);
  }

  /// Set split mode.
  Future<void> setSplit(bool enabled, {String txVfo = 'VFOB'}) async {
    await _command('\\set_split_vfo ${enabled ? 1 : 0} $txVfo');
  }

  // -- Rig info --

  /// Get rig info string.
  Future<String> getRigInfo() async {
    final lines = await _command(r'\get_info');
    return lines.join('\n').trim();
  }

  /// Get signal strength in dBFS (S-meter).
  Future<int> getSignalStrength() async {
    final resp = await _queryOne(r'\get_level STRENGTH');
    return int.tryParse(resp.trim()) ?? 0;
  }
}
