/// rigctld TCP client.
///
/// Connects to a hamlib rigctld daemon (local sidecar or remote openRigOS)
/// and exposes rig control as async Dart methods.
///
/// Protocol: plain-text over TCP (default port 4532).
/// Commands end with '\n'; responses end with 'RPRT <code>\n'.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A single connection to a rigctld instance.
class RigctldClient {
  final String host;
  final int port;

  Socket? _socket;
  final StreamController<String> _lines = StreamController.broadcast();

  RigctldClient({required this.host, this.port = 4532});

  Future<void> connect() async {
    _socket = await Socket.connect(host, port);
    _socket!
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_lines.add);
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }

  bool get isConnected => _socket != null;

  // TODO: implement set/get frequency, mode, PTT, etc.
}
