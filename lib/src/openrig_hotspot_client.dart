/// ConnectRPC client for the openRig HotspotService (port 7373).
///
/// Uses the Connect JSON protocol for unary calls and Connect streaming
/// (envelope-framed JSON over HTTP/1.1 chunked transfer) for server streams.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'openrig_api_models.dart';

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

  static const _hotspotBase = '/openrig.v1.HotspotService';
  static const _deviceBase = '/openrig.v1.DeviceService';
  static const _wifiBase = '/openrig.v1.WifiService';

  OpenRigHotspotClient({required this.host, this.port = 7373})
      : _http = http.Client();

  void dispose() => _http.close();

  Uri _uri(String path) => Uri.parse('http://$host:$port$path');

  // ── Unary helper ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _callAt(String serviceBase, String method,
      [Map<String, dynamic>? body]) async {
    final resp = await _http.post(
      _uri('$serviceBase/$method'),
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

  Future<Map<String, dynamic>> _call(String method,
      [Map<String, dynamic>? body]) =>
      _callAt(_hotspotBase, method, body);

  // ── DeviceService ────────────────────────────────────────────────────────

  Future<DeviceStatus> getStatus() async {
    final j = await _callAt(_deviceBase, 'GetStatus');
    return DeviceStatus(
      type: j['deviceType'] as String? ?? '',
      callsign: j['callsign'] as String? ?? '',
      hostname: j['hostname'] as String? ?? '',
      version: j['version'] as String? ?? '',
      uptime: (j['uptime'] as num?)?.toInt() ?? 0,
      provisioned: j['provisioned'] as bool? ?? false,
      cpuPercent: (j['cpuPercent'] as num?)?.toDouble() ?? 0.0,
      memTotalMb: (j['memTotalMb'] as num?)?.toInt() ?? 0,
      memUsedMb: (j['memUsedMb'] as num?)?.toInt() ?? 0,
      diskTotalGb: (j['diskTotalGb'] as num?)?.toDouble() ?? 0.0,
      diskUsedGb: (j['diskUsedGb'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Future<void> restartService(String service) async {
    await _callAt(_deviceBase, 'RestartService', {'service': service});
  }

  Future<void> reboot() async {
    await _callAt(_deviceBase, 'Reboot', {});
  }

  // ── WifiService ──────────────────────────────────────────────────────────

  Future<NetworkStatus> getNetworkStatus() async {
    final j = await _callAt(_wifiBase, 'GetNetwork');
    return NetworkStatus(
      mode: j['mode'] as String? ?? 'none',
      ssid: j['ssid'] as String? ?? '',
      ip: j['ip'] as String? ?? '',
      signalDbm: (j['signalDbm'] as num?)?.toInt() ?? 0,
      connected: j['connected'] as bool? ?? false,
      networkInterface: j['interface'] as String? ?? '',
    );
  }

  Future<List<WifiNetwork>> getWifi() async {
    final j = await _callAt(_wifiBase, 'GetWifi');
    final networks =
        (j['networks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return networks
        .map((n) => WifiNetwork(
              ssid: n['ssid'] as String? ?? '',
              security: n['security'] as String? ?? '',
              priority: (n['priority'] as num?)?.toInt() ?? 0,
              password: n['password'] as String?,
            ))
        .toList();
  }

  Future<void> updateWifi(List<WifiNetwork> networks) async {
    await _callAt(_wifiBase, 'UpdateWifi', {
      'config': {
        'networks': networks
            .map((n) => {
                  'ssid': n.ssid,
                  'security': n.security,
                  'priority': n.priority,
                  if (n.password != null && n.password!.isNotEmpty)
                    'password': n.password,
                })
            .toList(),
      },
    });
  }

  Future<List<ScannedNetwork>> scanWifi() async {
    final j = await _callAt(_wifiBase, 'ScanWifi');
    final networks =
        (j['networks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return networks.map((n) {
      final dbm = (n['signalDbm'] as num?)?.toInt() ?? -90;
      // Convert dBm to rough percentage: -30 dBm = 100%, -90 dBm = 0%
      final pct = ((dbm + 90) * 100 ~/ 60).clamp(0, 100);
      return ScannedNetwork(
        ssid: n['ssid'] as String? ?? '',
        security: n['security'] as String? ?? '',
        signal: pct,
      );
    }).toList();
  }

  // ── HotspotConfig (rich model) ───────────────────────────────────────────

  /// Returns the hotspot config mapped to the [HotspotConfig] model.
  Future<HotspotConfig> getHotspotConfig() async {
    final j = await _call('GetHotspot');
    return _hotspotFromProto(j);
  }

  /// Fetches current config, merges [config] fields, and saves via UpdateHotspot.
  Future<void> saveHotspotConfig(HotspotConfig config) async {
    final raw = await _call('GetHotspot');
    await _call('UpdateHotspot', {'config': _mergeHotspot(raw, config)});
  }

  static HotspotConfig _hotspotFromProto(Map<String, dynamic> j) {
    final dmr = j['dmr'] as Map<String, dynamic>? ?? {};
    final ysf = j['ysf'] as Map<String, dynamic>? ?? {};
    final cm = j['crossMode'] as Map<String, dynamic>? ?? {};
    return HotspotConfig(
      rfFrequencyMhz: (j['rfFrequency'] as num?)?.toDouble() ?? 0.0,
      dmr: DmrConfig(
        enabled: dmr['enabled'] as bool? ?? false,
        colorcode: (dmr['colorcode'] as num?)?.toInt() ?? 1,
        masterServer: dmr['server'] as String? ?? '',
        password: dmr['password'] as String? ?? '',
        dmrId: (dmr['dmrId'] as num?)?.toInt() ?? 0,
        talkgroups: ((dmr['talkgroups'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map((t) => Talkgroup(
                  id: (t['tg'] as num?)?.toInt() ?? 0,
                  slot: (t['slot'] as num?)?.toInt() ?? 1,
                  name: t['name'] as String? ?? '',
                ))
            .toList(),
      ),
      ysf: YsfConfig(
        enabled: ysf['enabled'] as bool? ?? false,
        reflector: ysf['reflector'] as String? ?? '',
        description: ysf['description'] as String? ?? '',
      ),
      ysf2dmr: CrossModeConfig(enabled: cm['ysf2dmrEnabled'] as bool? ?? false),
      dmr2ysf: CrossModeConfig(enabled: cm['dmr2ysfEnabled'] as bool? ?? false),
    );
  }

  static Map<String, dynamic> _mergeHotspot(
      Map<String, dynamic> raw, HotspotConfig config) {
    final j = Map<String, dynamic>.from(raw);
    j['rfFrequency'] = config.rfFrequencyMhz;

    final dmr = Map<String, dynamic>.from(
        (j['dmr'] as Map<String, dynamic>?) ?? {});
    dmr['enabled'] = config.dmr.enabled;
    dmr['colorcode'] = config.dmr.colorcode;
    dmr['server'] = config.dmr.masterServer;
    dmr['password'] = config.dmr.password;
    dmr['dmrId'] = config.dmr.dmrId;
    dmr['talkgroups'] = config.dmr.talkgroups
        .map((t) => {'tg': t.id, 'slot': t.slot, 'name': t.name})
        .toList();
    j['dmr'] = dmr;

    final ysf = Map<String, dynamic>.from(
        (j['ysf'] as Map<String, dynamic>?) ?? {});
    ysf['enabled'] = config.ysf.enabled;
    ysf['reflector'] = config.ysf.reflector;
    ysf['description'] = config.ysf.description;
    j['ysf'] = ysf;

    final cm = Map<String, dynamic>.from(
        (j['crossMode'] as Map<String, dynamic>?) ?? {});
    cm['ysf2dmrEnabled'] = config.ysf2dmr.enabled;
    cm['dmr2ysfEnabled'] = config.dmr2ysf.enabled;
    j['crossMode'] = cm;

    return j;
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
        _uri('$_hotspotBase/StreamLastHeard'),
      );
      request.headers['Content-Type'] = 'application/connect+json';
      request.headers['Connect-Protocol-Version'] = '1';
      // Connect streaming protocol: request body must also be envelope-framed.
      // 5-byte header: flags=0x00, length=2 (big-endian), then '{}'.
      request.bodyBytes =
          Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x02, 0x7B, 0x7D]);

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
