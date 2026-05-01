/// Typed HTTP client for the openRig management REST API (port 7373).
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'openrig_api_models.dart';

/// Exception thrown on non-2xx API responses.
class OpenRigApiException implements Exception {
  final int statusCode;
  final String method;
  final String path;
  final String body;

  OpenRigApiException({
    required this.statusCode,
    required this.method,
    required this.path,
    required this.body,
  });

  @override
  String toString() =>
      'OpenRigApiException: $method $path returned $statusCode: $body';
}

/// HTTP client for the openRig device management API.
class OpenRigApiClient {
  final String host;
  final int port;
  final http.Client _http;
  late final Uri _baseUrl;

  OpenRigApiClient({required this.host, this.port = 7373})
      : _http = http.Client() {
    _baseUrl = Uri.parse('http://$host:$port');
  }

  /// Verify the device is reachable by fetching status.
  Future<void> connect() async {
    await getStatus();
  }

  /// Close the underlying HTTP client.
  void dispose() {
    _http.close();
  }

  // -- Internal helpers --

  Uri _uri(String path) => _baseUrl.resolve(path);

  Future<Map<String, dynamic>> _getJson(String path) async {
    final resp = await _http.get(_uri(path));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw OpenRigApiException(
        statusCode: resp.statusCode,
        method: 'GET',
        path: path,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getJsonList(String path) async {
    final resp = await _http.get(_uri(path));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw OpenRigApiException(
        statusCode: resp.statusCode,
        method: 'GET',
        path: path,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  Future<void> _putJson(String path, Object body) async {
    final resp = await _http.put(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw OpenRigApiException(
        statusCode: resp.statusCode,
        method: 'PUT',
        path: path,
        body: resp.body,
      );
    }
  }

  Future<void> _post(String path) async {
    final resp = await _http.post(_uri(path));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw OpenRigApiException(
        statusCode: resp.statusCode,
        method: 'POST',
        path: path,
        body: resp.body,
      );
    }
  }

  // -- Status --

  /// Get the device status.
  Future<DeviceStatus> getStatus() async {
    final json = await _getJson('/api/status');
    return DeviceStatus.fromJson(json);
  }

  // -- Config --

  /// Get the device configuration.
  Future<DeviceConfig> getConfig() async {
    final json = await _getJson('/api/config');
    return DeviceConfig.fromJson(json);
  }

  /// Update the device configuration.
  Future<void> updateConfig(DeviceConfig config) async {
    await _putJson('/api/config', config.toJson());
  }

  // -- Hotspot --

  /// Get the hotspot configuration.
  Future<HotspotConfig> getHotspot() async {
    final json = await _getJson('/api/hotspot');
    return HotspotConfig.fromJson(json);
  }

  /// Update the hotspot configuration.
  Future<void> updateHotspot(HotspotConfig config) async {
    await _putJson('/api/hotspot', config.toJson());
  }

  // -- WiFi --

  /// Get configured WiFi networks.
  Future<List<WifiNetwork>> getWifi() async {
    final json = await _getJsonList('/api/wifi');
    return json
        .map((e) => WifiNetwork.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Update configured WiFi networks.
  Future<void> updateWifi(List<WifiNetwork> networks) async {
    await _putJson('/api/wifi', networks.map((n) => n.toJson()).toList());
  }

  /// Scan for available WiFi networks. Returns sorted by signal strength (strongest first).
  Future<List<ScannedNetwork>> scanWifi() async {
    final json = await _getJson('/api/wifi/scan');
    final list = json['networks'] as List;
    return list
        .map((e) => ScannedNetwork.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -- Network --

  /// Get the current network connectivity status.
  Future<NetworkStatus> getNetworkStatus() async {
    final json = await _getJson('/api/network');
    return NetworkStatus.fromJson(json);
  }

  // -- Clients --

  /// Get the list of recently heard hotspot clients.
  Future<List<HotspotClient>> getClients() async {
    final json = await _getJsonList('/api/clients');
    return json
        .map((e) => HotspotClient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -- Rig --

  /// Get the rig configuration.
  Future<RigConfig> getRigConfig() async {
    final json = await _getJson('/api/rig');
    return RigConfig.fromJson(json);
  }

  /// Update the rig configuration.
  Future<void> updateRigConfig(RigConfig config) async {
    await _putJson('/api/rig', config.toJson());
  }

  // -- DMR ID --

  /// Get the operator's DMR ID.
  Future<int> getDmrId() async {
    final json = await _getJson('/api/dmrid');
    return json['dmr_id'] as int;
  }

  /// Update the operator's DMR ID (7-digit number).
  Future<void> updateDmrId(int dmrId) async {
    await _putJson('/api/dmrid', {'dmr_id': dmrId});
  }

  // -- Services --

  /// Restart a named service (dmr, ysf, ysf2dmr, dmr2ysf, wifi).
  Future<void> restartService(String name) async {
    await _post('/api/services/$name/restart');
  }

  // -- System --

  /// Reboot the device. Returns immediately (202 Accepted).
  Future<void> reboot() async {
    await _post('/api/reboot');
  }

  /// Shut down the device. Returns immediately (202 Accepted).
  Future<void> shutdown() async {
    await _post('/api/shutdown');
  }
}
