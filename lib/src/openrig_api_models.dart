/// Data models for the openRig management REST API.
library;

/// Device status information.
class DeviceStatus {
  final String type;
  final String callsign;
  final String hostname;
  final String version;
  final int uptime;
  final bool provisioned;
  final double cpuPercent;
  final int memTotalMb;
  final int memUsedMb;
  final double diskTotalGb;
  final double diskUsedGb;

  const DeviceStatus({
    required this.type,
    required this.callsign,
    required this.hostname,
    required this.version,
    this.uptime = 0,
    required this.provisioned,
    this.cpuPercent = 0.0,
    this.memTotalMb = 0,
    this.memUsedMb = 0,
    this.diskTotalGb = 0.0,
    this.diskUsedGb = 0.0,
  });

  /// Formats uptime as "2h 34m" or "45m" or "< 1m".
  String get uptimeFormatted {
    if (uptime < 60) return '< 1m';
    final hours = uptime ~/ 3600;
    final minutes = (uptime % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  factory DeviceStatus.fromJson(Map<String, dynamic> json) => DeviceStatus(
        type: json['type'] as String,
        callsign: json['callsign'] as String,
        hostname: json['hostname'] as String,
        version: json['version'] as String,
        uptime: json['uptime'] as int? ?? 0,
        provisioned: json['provisioned'] as bool,
        cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0.0,
        memTotalMb: json['mem_total_mb'] as int? ?? 0,
        memUsedMb: json['mem_used_mb'] as int? ?? 0,
        diskTotalGb: (json['disk_total_gb'] as num?)?.toDouble() ?? 0.0,
        diskUsedGb: (json['disk_used_gb'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'callsign': callsign,
        'hostname': hostname,
        'version': version,
        'uptime': uptime,
        'provisioned': provisioned,
        'cpu_percent': cpuPercent,
        'mem_total_mb': memTotalMb,
        'mem_used_mb': memUsedMb,
        'disk_total_gb': diskTotalGb,
        'disk_used_gb': diskUsedGb,
      };
}

/// Device configuration.
class DeviceConfig {
  final String callsign;
  final String hostname;
  final String timezone;
  final String operatorName;
  final String gridSquare;

  const DeviceConfig({
    required this.callsign,
    required this.hostname,
    required this.timezone,
    required this.operatorName,
    required this.gridSquare,
  });

  factory DeviceConfig.fromJson(Map<String, dynamic> json) => DeviceConfig(
        callsign: json['callsign'] as String,
        hostname: json['hostname'] as String,
        timezone: json['timezone'] as String,
        operatorName: json['operatorName'] as String,
        gridSquare: json['gridSquare'] as String,
      );

  Map<String, dynamic> toJson() => {
        'callsign': callsign,
        'hostname': hostname,
        'timezone': timezone,
        'operatorName': operatorName,
        'gridSquare': gridSquare,
      };
}

/// A DMR talkgroup entry.
class Talkgroup {
  final int id;
  final int slot;
  final String name;

  const Talkgroup({
    required this.id,
    required this.slot,
    required this.name,
  });

  factory Talkgroup.fromJson(Map<String, dynamic> json) => Talkgroup(
        id: json['id'] as int,
        slot: json['slot'] as int,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slot': slot,
        'name': name,
      };
}

/// DMR configuration.
class DmrConfig {
  final bool enabled;
  final int colorcode;
  final String masterServer;
  final String password;
  final List<Talkgroup> talkgroups;
  final int dmrId;

  const DmrConfig({
    required this.enabled,
    required this.colorcode,
    required this.masterServer,
    required this.password,
    required this.talkgroups,
    this.dmrId = 0,
  });

  factory DmrConfig.fromJson(Map<String, dynamic> json) => DmrConfig(
        enabled: json['enabled'] as bool,
        colorcode: json['colorcode'] as int,
        masterServer: json['masterServer'] as String,
        password: json['password'] as String,
        talkgroups: (json['talkgroups'] as List)
            .map((e) => Talkgroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        dmrId: json['dmr_id'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'colorcode': colorcode,
        'masterServer': masterServer,
        'password': password,
        'talkgroups': talkgroups.map((t) => t.toJson()).toList(),
        'dmr_id': dmrId,
      };
}

/// YSF configuration.
class YsfConfig {
  final bool enabled;
  final String reflector;
  final String description;
  final String suffix;

  const YsfConfig({
    required this.enabled,
    required this.reflector,
    required this.description,
    this.suffix = '',
  });

  factory YsfConfig.fromJson(Map<String, dynamic> json) => YsfConfig(
        enabled: json['enabled'] as bool,
        reflector: json['reflector'] as String,
        description: json['description'] as String,
        suffix: json['suffix'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'reflector': reflector,
        'description': description,
        'suffix': suffix,
      };
}

/// Cross-mode bridge configuration (YSF<->DMR).
class CrossModeConfig {
  final bool enabled;
  final int? talkgroup;
  final String? room;

  const CrossModeConfig({
    required this.enabled,
    this.talkgroup,
    this.room,
  });

  factory CrossModeConfig.fromJson(Map<String, dynamic> json) =>
      CrossModeConfig(
        enabled: json['enabled'] as bool,
        talkgroup: json['talkgroup'] as int?,
        room: json['room'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (talkgroup != null) 'talkgroup': talkgroup,
        if (room != null) 'room': room,
      };
}

/// Hotspot configuration (all modes).
class HotspotConfig {
  final DmrConfig dmr;
  final YsfConfig ysf;
  final CrossModeConfig ysf2dmr;
  final CrossModeConfig dmr2ysf;

  /// RF simplex frequency in MHz (e.g. 438.8000). Zero means not configured.
  final double rfFrequencyMhz;

  const HotspotConfig({
    required this.dmr,
    required this.ysf,
    required this.ysf2dmr,
    required this.dmr2ysf,
    this.rfFrequencyMhz = 0.0,
  });

  factory HotspotConfig.fromJson(Map<String, dynamic> json) => HotspotConfig(
        dmr: DmrConfig.fromJson(json['dmr'] as Map<String, dynamic>),
        ysf: YsfConfig.fromJson(json['ysf'] as Map<String, dynamic>),
        ysf2dmr:
            CrossModeConfig.fromJson(json['ysf2dmr'] as Map<String, dynamic>),
        dmr2ysf:
            CrossModeConfig.fromJson(json['dmr2ysf'] as Map<String, dynamic>),
        rfFrequencyMhz:
            (json['rf_frequency'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'dmr': dmr.toJson(),
        'ysf': ysf.toJson(),
        'ysf2dmr': ysf2dmr.toJson(),
        'dmr2ysf': dmr2ysf.toJson(),
        'rf_frequency': rfFrequencyMhz,
      };
}

/// A WiFi network entry.
class WifiNetwork {
  final String ssid;
  final String security;
  final int priority;
  final String? password; // write-only — not returned by GET

  const WifiNetwork({
    required this.ssid,
    required this.security,
    required this.priority,
    this.password,
  });

  factory WifiNetwork.fromJson(Map<String, dynamic> json) => WifiNetwork(
        ssid: json['ssid'] as String,
        security: json['security'] as String,
        priority: json['priority'] as int,
        password: json['password'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'security': security,
        'priority': priority,
        if (password != null) 'password': password,
      };
}

/// A WiFi network visible to the device (from a scan).
class ScannedNetwork {
  final String ssid;
  final int signal;
  final String security;

  const ScannedNetwork({
    required this.ssid,
    required this.signal,
    required this.security,
  });

  factory ScannedNetwork.fromJson(Map<String, dynamic> json) => ScannedNetwork(
        ssid: json['ssid'] as String,
        signal: json['signal'] as int,
        security: json['security'] as String,
      );

  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'signal': signal,
        'security': security,
      };
}

/// A rig serial-port configuration entry.
class ApiRigEntry {
  final bool enabled;
  final int hamlibModelId;
  final String port;
  final int baud;
  final int dataBits;
  final int stopBits;
  final String parity;
  final String handshake;

  const ApiRigEntry({
    required this.enabled,
    required this.hamlibModelId,
    required this.port,
    required this.baud,
    this.dataBits = 8,
    this.stopBits = 1,
    this.parity = 'none',
    this.handshake = 'none',
  });

  factory ApiRigEntry.fromJson(Map<String, dynamic> json) => ApiRigEntry(
        enabled: json['enabled'] as bool,
        hamlibModelId: json['hamlibModelId'] as int,
        port: json['port'] as String,
        baud: json['baud'] as int,
        dataBits: json['dataBits'] as int? ?? 8,
        stopBits: json['stopBits'] as int? ?? 1,
        parity: json['parity'] as String? ?? 'none',
        handshake: json['handshake'] as String? ?? 'none',
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hamlibModelId': hamlibModelId,
        'port': port,
        'baud': baud,
        'dataBits': dataBits,
        'stopBits': stopBits,
        'parity': parity,
        'handshake': handshake,
      };
}

/// Rig configuration — list of configured radios.
class RigConfig {
  final List<ApiRigEntry> rigs;

  const RigConfig({required this.rigs});

  factory RigConfig.fromJson(Map<String, dynamic> json) => RigConfig(
        rigs: (json['rigs'] as List)
            .map((e) => ApiRigEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'rigs': rigs.map((r) => r.toJson()).toList(),
      };
}

/// A hotspot client (recently heard station).
class HotspotClient {
  final String callsign;
  final String mode;
  final DateTime lastHeard;
  final int duration;

  const HotspotClient({
    required this.callsign,
    required this.mode,
    required this.lastHeard,
    required this.duration,
  });

  factory HotspotClient.fromJson(Map<String, dynamic> json) => HotspotClient(
        callsign: json['callsign'] as String,
        mode: json['mode'] as String,
        lastHeard: DateTime.parse(json['lastHeard'] as String),
        duration: json['duration'] as int,
      );

  Map<String, dynamic> toJson() => {
        'callsign': callsign,
        'mode': mode,
        'lastHeard': lastHeard.toIso8601String(),
        'duration': duration,
      };
}

/// Network connectivity status returned by GET /api/network.
class NetworkStatus {
  final String mode;
  final String ssid;
  final String ip;
  final int signalDbm;
  final bool connected;
  final String networkInterface;

  const NetworkStatus({
    required this.mode,
    required this.ssid,
    required this.ip,
    required this.signalDbm,
    required this.connected,
    required this.networkInterface,
  });

  factory NetworkStatus.fromJson(Map<String, dynamic> json) => NetworkStatus(
        mode: json['mode'] as String? ?? 'none',
        ssid: json['ssid'] as String? ?? '',
        ip: json['ip'] as String? ?? '',
        signalDbm: json['signal_dbm'] as int? ?? 0,
        connected: json['connected'] as bool? ?? false,
        networkInterface: json['interface'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'ssid': ssid,
        'ip': ip,
        'signal_dbm': signalDbm,
        'connected': connected,
        'interface': networkInterface,
      };
}
