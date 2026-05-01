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
import 'dart:math';

/// Regex for standard DX cluster spot lines.
///
/// Format: DX de SPOTTER:     FREQ.F  DXCALL       comment              HHMMZ
/// Example: DX de W3LPL:      14025.0 JA1ABC       up 1-2               1423Z
final _spotRegex = RegExp(
  r'^DX de\s+([A-Z0-9/]+):\s+'   // spotter callsign (followed by colon)
  r'(\d+\.?\d*)\s+'               // frequency in kHz
  r'([A-Z0-9/]+)\s+'              // DX callsign
  r'(.*?)\s+'                      // comment (non-greedy)
  r'(\d{4})Z\s*$',                // time HHMM Z
  caseSensitive: false,
);

/// Regex for prefixed spot lines (pota / dxsu record types).
///
/// Format: <prefix> DX de SPOTTER   FREQ.F  DXCALL   comment   HHMMZ [extra]
/// Example: pota DX de JH7CSU1-#   7006.5  JM1TBU   CW 27 dB  0529Z JP-0118
/// Example: dxsu DX de VK6KXW-@   50313.0  XU7O     :r-21      0534Z
final _prefixedSpotRegex = RegExp(
  r'^(pota|dxsu)\s+DX de\s+'    // source prefix (pota or dxsu)
  r'([A-Z0-9/\-#@]+)\s+'        // spotter (may have -#, -@, -N suffixes)
  r'(\d+\.?\d*)\s+'              // frequency in kHz
  r'([A-Z0-9/]+)\s+'             // DX callsign
  r'(.*?)\s+'                     // comment (non-greedy)
  r'(\d{4})Z',                   // time HHMM Z (no $ — park ref may follow)
  caseSensitive: false,
);

/// A parsed DX spot.
class DxSpot {
  final String spotter;
  final String dxCall;
  final double frequencyKhz;
  final String comment;
  final DateTime time;

  /// Record source: `'dx'` (standard), `'pota'` (POTA via cluster),
  /// `'dxsu'` (DXSummit via cluster).
  final String source;

  /// POTA park reference extracted from `pota`-prefixed lines (e.g. `K-1234`).
  /// Null for non-POTA spots.
  final String? parkRef;

  const DxSpot({
    required this.spotter,
    required this.dxCall,
    required this.frequencyKhz,
    required this.comment,
    required this.time,
    this.source = 'dx',
    this.parkRef,
  });

  /// Parse a DX cluster spot line. Returns null if the line is not a spot.
  /// Handles standard (`DX de ...`), POTA (`pota DX de ...`), and
  /// DXSummit (`dxsu DX de ...`) record formats.
  static DxSpot? fromLine(String line) {
    // Try standard format first
    final stdMatch = _spotRegex.firstMatch(line);
    if (stdMatch != null) {
      return _buildSpot(stdMatch, 1, 2, 3, 4, 5, 'dx');
    }

    // Try prefixed formats (pota / dxsu)
    final pfxMatch = _prefixedSpotRegex.firstMatch(line);
    if (pfxMatch != null) {
      final prefix = pfxMatch.group(1)!.toLowerCase();
      var spot = _buildSpot(pfxMatch, 2, 3, 4, 5, 6, prefix);
      if (spot != null && prefix == 'pota') {
        // Extract park reference that follows the time (e.g. "JP-0118")
        final afterTime = line.substring(pfxMatch.end).trim();
        final parkMatch =
            RegExp(r'^([A-Z]{1,4}-\d{3,6})', caseSensitive: false)
                .firstMatch(afterTime);
        if (parkMatch != null) {
          spot = DxSpot(
            spotter: spot.spotter,
            dxCall: spot.dxCall,
            frequencyKhz: spot.frequencyKhz,
            comment: spot.comment,
            time: spot.time,
            source: spot.source,
            parkRef: parkMatch.group(1)!.toUpperCase(),
          );
        }
      }
      return spot;
    }

    return null;
  }

  static DxSpot? _buildSpot(
    RegExpMatch m,
    int spotterIdx,
    int freqIdx,
    int dxIdx,
    int commentIdx,
    int timeIdx,
    String source,
  ) {
    final spotter = m.group(spotterIdx)!.toUpperCase();
    final freq = double.tryParse(m.group(freqIdx)!);
    if (freq == null) return null;
    final dxCall = m.group(dxIdx)!.toUpperCase();
    final comment = m.group(commentIdx)!.trim();
    final hhmm = m.group(timeIdx)!;

    final now = DateTime.now().toUtc();
    final hour = int.parse(hhmm.substring(0, 2));
    final minute = int.parse(hhmm.substring(2, 4));
    var time = DateTime.utc(now.year, now.month, now.day, hour, minute);
    if (time.isAfter(now)) {
      time = time.subtract(const Duration(days: 1));
    }

    return DxSpot(
      spotter: spotter,
      dxCall: dxCall,
      frequencyKhz: freq,
      comment: comment,
      time: time,
      source: source,
    );
  }

  @override
  String toString() =>
      'DxSpot($source: $spotter -> $dxCall @ ${frequencyKhz.toStringAsFixed(1)} kHz)';
}

/// Client for a single DX Cluster node.
class DxClusterClient {
  final String host;
  final int port;
  final String callsign;
  final bool autoReconnect;

  Socket? _socket;
  StreamSubscription<String>? _subscription;
  final StreamController<DxSpot> _spots = StreamController.broadcast();
  final StreamController<String> _rawLines = StreamController.broadcast();
  final StreamController<bool> _connectionState =
      StreamController<bool>.broadcast();

  bool _disposed = false;
  bool _reconnecting = false;

  DxClusterClient({
    required this.host,
    required this.callsign,
    this.port = 7300,
    this.autoReconnect = false,
  });

  /// Stream of parsed DX spots.
  Stream<DxSpot> get spots => _spots.stream;

  /// Stream of all raw lines from the cluster (for debug/display).
  Stream<String> get rawLines => _rawLines.stream;

  /// Stream of connection state changes (true = connected, false = disconnected).
  Stream<bool> get connectionState => _connectionState.stream;

  bool get isConnected => _socket != null;

  Future<void> connect() async {
    _socket = await Socket.connect(host, port);
    _subscription = utf8.decoder
        .bind(_socket!)
        .transform(const LineSplitter())
        .listen(
          _onLine,
          onDone: _onSocketDone,
          onError: (_) => _onSocketDone(),
        );
    // Authenticate — ignore write errors if socket was closed immediately
    try {
      _socket!.write('$callsign\r\n');
    } catch (_) {
      // Socket may have been destroyed before write completes
    }
    if (!_connectionState.isClosed) _connectionState.add(true);
  }

  Future<void> disconnect() async {
    _reconnecting = false;
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
    if (!_connectionState.isClosed) _connectionState.add(false);
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _spots.close();
    await _rawLines.close();
    await _connectionState.close();
  }

  void _onLine(String line) {
    _rawLines.add(line);
    final spot = DxSpot.fromLine(line);
    if (spot != null) {
      _spots.add(spot);
    }
  }

  void _onSocketDone() {
    _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
    if (!_connectionState.isClosed) _connectionState.add(false);
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
        delay = Duration(
          milliseconds: min(delay.inMilliseconds * 2, maxDelay.inMilliseconds),
        );
      }
    }
  }

  /// Send a raw command to the cluster (e.g. 'sh/dx 20').
  void send(String command) => _socket?.write('$command\r\n');
}
