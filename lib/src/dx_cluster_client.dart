/// DX Cluster Telnet client.
///
/// Connects to a DX Cluster node (e.g. k9ox.net:7300), authenticates with
/// the operator callsign, and exposes an incoming spot stream.
///
/// Protocol: plain-text Telnet. Authenticate by sending callsign on connect.
/// Spots arrive as unsolicited lines: "DX de <spotter>: <freq> <dx> <comment> <time>Z"
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A parsed DX spot.
class DxSpot {
  final String spotter;
  final String dxCall;
  final double frequencyKhz;
  final String comment;
  final DateTime time;

  const DxSpot({
    required this.spotter,
    required this.dxCall,
    required this.frequencyKhz,
    required this.comment,
    required this.time,
  });

  // TODO: implement fromLine() parser for the DX de ... line format
}

/// Client for a single DX Cluster node.
class DxClusterClient {
  final String host;
  final int port;
  final String callsign;

  Socket? _socket;
  final StreamController<DxSpot> _spots = StreamController.broadcast();

  DxClusterClient({
    required this.host,
    required this.callsign,
    this.port = 7300,
  });

  Stream<DxSpot> get spots => _spots.stream;

  Future<void> connect() async {
    _socket = await Socket.connect(host, port);
    _socket!
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine);
    // Authenticate
    _socket!.write('$callsign\r\n');
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }

  void _onLine(String line) {
    // TODO: parse spot lines and push to _spots stream
  }

  /// Send a raw command to the cluster (e.g. 'sh/dx 20').
  void send(String command) => _socket?.write('$command\r\n');
}
