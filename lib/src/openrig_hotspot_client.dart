/// ConnectRPC client for the openRig HotspotService (port 7373).
///
/// Uses the Connect JSON protocol for unary calls and Connect streaming
/// (envelope-framed JSON over HTTP/1.1 chunked transfer) for server streams.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

// ── Data models ─────────────────────────────────────────────────────────────

/// A single entry from the last-heard stream.
class HotspotLastHeardEntry {
  final String callsign;
  final String mode;
  final String info;
  final String duration; // empty string = active QSO in progress
  final String timestamp; // RFC3339
  final String ber;
  final String loss;

  const HotspotLastHeardEntry({
    required this.callsign,
    required this.mode,
    required this.info,
    required this.duration,
    required this.timestamp,
    required this.ber,
    required this.loss,
  });

  bool get isActive => duration.isEmpty;

  factory HotspotLastHeardEntry.fromJson(Map<String, dynamic> j) =>
      HotspotLastHeardEntry(
        callsign: j['callsign'] as String? ?? '',
        mode: j['mode'] as String? ?? '',
        info: j['info'] as String? ?? '',
        duration: j['duration'] as String? ?? '',
        timestamp: j['timestamp'] as String? ?? '',
        ber: j['ber'] as String? ?? '',
        loss: j['loss'] as String? ?? '',
      );

  /// Two entries represent the same transmission if callsign+mode+timestamp match.
  bool sameTransmission(HotspotLastHeardEntry other) =>
      callsign == other.callsign &&
      mode == other.mode &&
      timestamp == other.timestamp;
}

/// Minimal YSF config fields we care about for the Reflector Manager.
class HotspotYsfState {
  final bool enabled;
  final String network; // "ysf"|"fcs"|"custom"
  final String reflector;
  final String linkState; // "linking"|"relinking"|"unlinked"|"" (linked = non-empty reflector + no state)

  const HotspotYsfState({
    required this.enabled,
    required this.network,
    required this.reflector,
    required this.linkState,
  });

  factory HotspotYsfState.fromJson(Map<String, dynamic> j) {
    final ysf = j['ysf'] as Map<String, dynamic>? ?? {};
    return HotspotYsfState(
      enabled: ysf['enabled'] as bool? ?? false,
      network: ysf['network'] as String? ?? 'ysf',
      reflector: ysf['reflector'] as String? ?? '',
      linkState: ysf['linkState'] as String? ?? '',
    );
  }
}

/// A YSF server entry returned by GetServers.
class YsfServer {
  final String server;
  final String label;

  const YsfServer({required this.server, required this.label});
}

// ── Client ───────────────────────────────────────────────────────────────────

/// Errors thrown by [OpenRigHotspotClient].
class HotspotClientException implements Exception {
  final String message;
  const HotspotClientException(this.message);
  @override
  String toString() => 'HotspotClientException: $message';
}

/// ConnectRPC client for openRig's HotspotService.
///
/// Connects to `http://<host>:7373` using the Connect JSON protocol.
/// The same port speaks both Connect-JSON (for this client) and legacy
/// REST (for [OpenRigApiClient]), so both can coexist.
class OpenRigHotspotClient {
  final String host;
  final int port;
  final http.Client _http;

  static const _base = '/openrig.v1.HotspotService';

  OpenRigHotspotClient({required this.host, this.port = 7373})
      : _http = http.Client();

  void dispose() => _http.close();

  Uri _uri(String path) => Uri.parse('http://$host:$port$path');

  // ── Unary helper ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _call(String method,
      [Map<String, dynamic>? body]) async {
    final resp = await _http.post(
      _uri('$_base/$method'),
      headers: {
        'Content-Type': 'application/json',
        'Connect-Protocol-Version': '1',
      },
      body: jsonEncode(body ?? {}),
    );
    if (resp.statusCode != 200) {
      throw HotspotClientException(
          '$method returned HTTP ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ── Hotspot ─────────────────────────────────────────────────────────────

  /// Returns the full raw hotspot config JSON from the device.
  /// Use [HotspotYsfState.fromJson] to extract YSF-specific fields.
  Future<Map<String, dynamic>> getHotspot() => _call('GetHotspot');

  /// Updates the hotspot config on the device.
  /// Pass the full config map (from [getHotspot]) with modifications applied.
  Future<void> updateHotspot(Map<String, dynamic> config) async {
    await _call('UpdateHotspot', {'config': config});
  }

  /// Links to a YSF reflector by fetching the current config, updating the
  /// reflector field, and saving. Returns the link state after the update.
  Future<void> linkYsf(String reflector) async {
    final config = await getHotspot();
    final ysf = Map<String, dynamic>.from(
        (config['ysf'] as Map<String, dynamic>?) ?? {});
    ysf['reflector'] = reflector;
    config['ysf'] = ysf;
    await updateHotspot(config);
  }

  /// Unlinks from the current YSF reflector.
  Future<void> unlinkYsf() async {
    final config = await getHotspot();
    final ysf = Map<String, dynamic>.from(
        (config['ysf'] as Map<String, dynamic>?) ?? {});
    ysf['reflector'] = '';
    config['ysf'] = ysf;
    await updateHotspot(config);
  }

  // ── Servers ─────────────────────────────────────────────────────────────

  /// Returns the list of YSF reflectors (or BrandMeister servers, etc.)
  /// for [network] ("ysf"|"fcs"|"brandmeister").
  Future<List<YsfServer>> getServers(String network) async {
    final resp = await _call('GetServers', {'network': network});
    final servers = (resp['servers'] as List?)?.cast<String>() ?? [];
    final labels = (resp['labels'] as List?)?.cast<String>() ?? [];
    return List.generate(servers.length, (i) {
      final label = i < labels.length && labels[i].isNotEmpty
          ? labels[i]
          : servers[i];
      return YsfServer(server: servers[i], label: label);
    });
  }

  // ── StreamLastHeard ─────────────────────────────────────────────────────

  /// Streams last-heard entries from the device in real time.
  ///
  /// The stream delivers the existing cache (oldest-first) followed by
  /// live entries as transmissions complete. The stream runs until the
  /// returned [StreamController] is cancelled or the connection drops,
  /// at which point it can be restarted.
  ///
  /// Uses the Connect streaming protocol over HTTP/1.1 (envelope-framed
  /// JSON messages, 5-byte header per message).
  Stream<HotspotLastHeardEntry> streamLastHeard() {
    final controller = StreamController<HotspotLastHeardEntry>();
    _runStream(controller);
    return controller.stream;
  }

  void _runStream(StreamController<HotspotLastHeardEntry> controller) async {
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        _uri('$_base/StreamLastHeard'),
      );
      request.headers['Content-Type'] = 'application/connect+json';
      request.headers['Connect-Protocol-Version'] = '1';
      request.body = '{}';

      final streamed = await client.send(request);
      if (streamed.statusCode != 200) {
        throw HotspotClientException(
            'StreamLastHeard HTTP ${streamed.statusCode}');
      }

      // Connect streaming protocol: each message is preceded by a 5-byte
      // envelope: [flags(1)] [length(4, big-endian)].
      // flags & 0x02 != 0  →  end-of-stream (trailers envelope)
      final buf = <int>[];
      await for (final chunk in streamed.stream) {
        if (controller.isClosed) break;
        buf.addAll(chunk);
        while (buf.length >= 5) {
          final flags = buf[0];
          final msgLen = ByteData.sublistView(
                  Uint8List.fromList(buf.sublist(1, 5)))
              .getUint32(0, Endian.big);
          if (buf.length < 5 + msgLen) break;

          final msgBytes = buf.sublist(5, 5 + msgLen);
          buf.removeRange(0, 5 + msgLen);

          if (flags & 0x02 != 0) {
            // Trailers / end-of-stream envelope
            if (!controller.isClosed) controller.close();
            return;
          }

          try {
            final map = jsonDecode(utf8.decode(msgBytes)) as Map<String, dynamic>;
            if (!controller.isClosed) {
              controller.add(HotspotLastHeardEntry.fromJson(map));
            }
          } catch (_) {
            // Malformed message — skip
          }
        }
      }
      if (!controller.isClosed) controller.close();
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
      if (!controller.isClosed) controller.close();
    } finally {
      client.close();
    }
  }
}
