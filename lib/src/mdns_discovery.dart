/// mDNS / DNS-SD discovery for openRig devices.
///
/// Browses the local network for:
///   _openrig._tcp  — all openRig devices (Console, hotspot, rigctl, operator)
///   _rigctld._tcp  — devices with an active rigctld (rigctl + hotspot types)
///
/// Uses the `multicast_dns` package which handles platform differences:
///   iOS/macOS — Bonjour (NSNetServiceBrowser)
///   Android   — NsdManager
///   Linux     — Avahi via multicast sockets
///   Windows   — Multicast DNS sockets
library;

import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';

const _openrigService = '_openrig._tcp';
const _rigctldService = '_rigctld._tcp';

/// An openRig device discovered via mDNS.
class OpenRigDevice {
  final String name;       // e.g. "openRig w1aw-rigctl"
  final String host;       // e.g. "w1aw-rigctl.local"
  final int port;          // _openrig._tcp port (7373)
  final bool provisioned;
  final String type;       // hotspot | rigctl | operator | unconfigured
  final String callsign;
  final String version;
  final bool hasRigctld;   // true if _rigctld._tcp also advertised
  final int? rigctldPort;  // 4532 if hasRigctld

  const OpenRigDevice({
    required this.name,
    required this.host,
    required this.port,
    required this.provisioned,
    required this.type,
    required this.callsign,
    required this.version,
    this.hasRigctld = false,
    this.rigctldPort,
  });

  OpenRigDevice copyWith({bool? hasRigctld, int? rigctldPort}) {
    return OpenRigDevice(
      name: name,
      host: host,
      port: port,
      provisioned: provisioned,
      type: type,
      callsign: callsign,
      version: version,
      hasRigctld: hasRigctld ?? this.hasRigctld,
      rigctldPort: rigctldPort ?? this.rigctldPort,
    );
  }

  @override
  String toString() => 'OpenRigDevice($name, $host:$port, type=$type)';
}

/// Parse a TXT record string into a key-value map.
///
/// The multicast_dns package decodes DNS-SD TXT records into a single string
/// with newline-separated "key=value" entries.
Map<String, String> parseTxtRecord(String text) {
  final result = <String, String>{};
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final eq = trimmed.indexOf('=');
    if (eq > 0) {
      result[trimmed.substring(0, eq).toLowerCase()] =
          trimmed.substring(eq + 1);
    }
  }
  return result;
}

/// Browses the local network for openRig devices.
class OpenRigDiscovery {
  final MDnsClient _client = MDnsClient();
  Timer? _scanTimer;
  bool _running = false;

  final _deviceController = StreamController<OpenRigDevice>.broadcast();
  final _lostController = StreamController<String>.broadcast();

  /// Devices found so far, keyed by host.
  final Map<String, OpenRigDevice> devices = {};

  /// Fires when a new device is discovered or an existing one is updated.
  Stream<OpenRigDevice> get onDeviceFound => _deviceController.stream;

  /// Fires when a device is no longer seen (by host).
  Stream<String> get onDeviceLost => _lostController.stream;

  /// Start browsing. Scans immediately and then every [interval].
  Future<void> start({Duration interval = const Duration(seconds: 10)}) async {
    if (_running) return;
    _running = true;
    await _client.start();
    await _scan();
    _scanTimer = Timer.periodic(interval, (_) => _scan());
  }

  /// Stop browsing and clean up.
  Future<void> stop() async {
    _running = false;
    _scanTimer?.cancel();
    _scanTimer = null;
    _client.stop();
    await _deviceController.close();
    await _lostController.close();
  }

  Future<void> _scan() async {
    final seen = <String>{};

    // Browse _openrig._tcp
    await for (final ptr in _client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(_openrigService),
    )) {
      await for (final srv in _client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
      )) {
        final host = srv.target;
        seen.add(host);

        // Resolve IP address
        String? ip;
        await for (final ip4 in _client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(host),
        )) {
          ip = ip4.address.address;
          break;
        }

        // Resolve TXT records
        final txt = <String, String>{};
        await for (final txtRecord in _client.lookup<TxtResourceRecord>(
          ResourceRecordQuery.text(ptr.domainName),
        )) {
          txt.addAll(parseTxtRecord(txtRecord.text));
          break;
        }

        final device = OpenRigDevice(
          name: ptr.domainName,
          host: ip ?? host,
          port: srv.port,
          provisioned: txt['provisioned'] == 'true',
          type: txt['type'] ?? 'unconfigured',
          callsign: txt['callsign'] ?? '',
          version: txt['version'] ?? '',
        );

        devices[host] = device;
        _deviceController.add(device);
      }
    }

    // Browse _rigctld._tcp to annotate devices that have rigctld
    await for (final ptr in _client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(_rigctldService),
    )) {
      await for (final srv in _client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
      )) {
        final host = srv.target;
        final existing = devices[host];
        if (existing != null) {
          final updated = existing.copyWith(
            hasRigctld: true,
            rigctldPort: srv.port,
          );
          devices[host] = updated;
          _deviceController.add(updated);
        }
      }
    }

    // Detect lost devices
    final lost = devices.keys.where((h) => !seen.contains(h)).toList();
    for (final h in lost) {
      devices.remove(h);
      _lostController.add(h);
    }
  }
}
