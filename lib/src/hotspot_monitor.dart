/// Live streaming hotspot monitor.
///
/// Polls the openRig management API at a configurable interval and
/// emits streams of status, clients, and hotspot config. Only emits
/// when values change. Errors are silently swallowed to keep streams
/// alive.
library;

import 'dart:async';
import 'dart:convert';

import 'openrig_api_client.dart';
import 'openrig_api_models.dart';

/// Monitors a hotspot device by polling its REST API.
class HotspotMonitor {
  final OpenRigApiClient _client;
  final Duration _interval;

  Timer? _timer;
  bool _running = false;
  bool _disposed = false;

  final _statusController = StreamController<DeviceStatus>.broadcast();
  final _clientsController =
      StreamController<List<HotspotClient>>.broadcast();
  final _hotspotController = StreamController<HotspotConfig>.broadcast();
  final _networkController = StreamController<NetworkStatus>.broadcast();

  // Cached JSON strings for change detection
  String? _lastStatusJson;
  String? _lastClientsJson;
  String? _lastHotspotJson;

  HotspotMonitor({
    required String host,
    Duration interval = const Duration(seconds: 3),
  })  : _client = OpenRigApiClient(host: host),
        _interval = interval;

  /// Internal constructor for testing with a pre-built client.
  HotspotMonitor.withClient({
    required OpenRigApiClient client,
    Duration interval = const Duration(seconds: 3),
  })  : _client = client,
        _interval = interval;

  /// Stream of device status updates (emits only on change).
  Stream<DeviceStatus> get status => _statusController.stream;

  /// Stream of hotspot config updates (emits only on change).
  Stream<HotspotConfig> get hotspot => _hotspotController.stream;

  /// Stream of hotspot client list updates (emits only on change).
  Stream<List<HotspotClient>> get clients => _clientsController.stream;

  /// Stream of network status updates (emits every poll cycle).
  Stream<NetworkStatus> get network => _networkController.stream;

  /// Start polling. Does an immediate poll, then repeats at [interval].
  void start() {
    if (_running) return;
    _running = true;
    _poll();
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  /// Pause polling without disposing streams.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Stop polling, close all streams, and dispose the API client.
  void dispose() {
    _disposed = true;
    stop();
    _statusController.close();
    _clientsController.close();
    _hotspotController.close();
    _networkController.close();
    _client.dispose();
  }

  Future<void> _poll() async {
    await Future.wait([
      _pollStatus(),
      _pollClients(),
      _pollHotspot(),
      _pollNetwork(),
    ]);
  }

  Future<void> _pollStatus() async {
    try {
      final result = await _client.getStatus();
      if (_disposed) return;
      final json = jsonEncode(result.toJson());
      if (json != _lastStatusJson) {
        _lastStatusJson = json;
        _statusController.add(result);
      }
    } catch (_) {
      // Silently skip failed ticks.
    }
  }

  Future<void> _pollClients() async {
    try {
      final result = await _client.getClients();
      if (_disposed) return;
      final json = jsonEncode(result.map((c) => c.toJson()).toList());
      if (json != _lastClientsJson) {
        _lastClientsJson = json;
        _clientsController.add(result);
      }
    } catch (_) {
      // Silently skip failed ticks.
    }
  }

  Future<void> _pollHotspot() async {
    try {
      final config = await _client.getHotspot();
      if (_disposed) return;
      final json = jsonEncode(config.toJson());
      if (json != _lastHotspotJson) {
        _lastHotspotJson = json;
        _hotspotController.add(config);
      }
    } catch (_) {
      // Silently skip failed ticks.
    }
  }

  Future<void> _pollNetwork() async {
    try {
      final result = await _client.getNetworkStatus();
      if (_disposed) return;
      _networkController.add(result);
    } catch (_) {
      // Silently skip failed ticks.
    }
  }
}
