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

import 'package:multicast_dns/multicast_dns.dart';

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
}

/// Browses the local network for openRig devices.
class OpenRigDiscovery {
  final MDnsClient _client = MDnsClient();

  // TODO: implement start() — browse _openrig._tcp, resolve PTR→SRV→A/AAAA+TXT
  // TODO: implement stop()
  // TODO: expose Stream<OpenRigDevice> onDeviceFound
  // TODO: expose Stream<String> onDeviceLost (by host)
}
