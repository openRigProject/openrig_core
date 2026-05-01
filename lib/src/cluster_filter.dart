/// DX Cluster spot filtering.
library;

import 'band_plan.dart';
import 'duplicate_checker.dart';
import 'dx_cluster_client.dart';

/// Filters DX Cluster spots by band, mode, and dupe status.
class ClusterFilter {
  final List<String> bands;
  final List<String> modes;
  final bool neededOnly;
  final bool newBandOnly;
  final DuplicateChecker? dupeChecker;

  ClusterFilter({
    this.bands = const [],
    this.modes = const [],
    this.neededOnly = false,
    this.newBandOnly = false,
    this.dupeChecker,
  });

  /// Returns true if the spot passes all active filters.
  bool passes(DxSpot spot) {
    final band = bandFromKhz(spot.frequencyKhz);
    final bandName = band?.name;
    final subBand = band?.subBandFromMhz(spot.frequencyKhz / 1000.0);
    final modeName = subBand?.name;

    // Band filter
    if (bands.isNotEmpty) {
      if (bandName == null || !bands.contains(bandName)) return false;
    }

    // Mode filter
    if (modes.isNotEmpty) {
      if (modeName == null) return false;
      final modesUpper = modes.map((m) => m.toUpperCase()).toSet();
      if (!modesUpper.contains(modeName.toUpperCase())) return false;
    }

    // Dupe filters require both a checker and a resolved band
    if (dupeChecker != null && bandName != null) {
      final mode = modeName ?? '';

      if (neededOnly && mode.isNotEmpty) {
        if (dupeChecker!.isWorkedOnBandMode(spot.dxCall, bandName, mode)) {
          return false;
        }
      }

      if (newBandOnly) {
        if (dupeChecker!.isWorkedOnBand(spot.dxCall, bandName)) {
          return false;
        }
      }
    }

    return true;
  }

  /// Copy with updated fields.
  ClusterFilter copyWith({
    List<String>? bands,
    List<String>? modes,
    bool? neededOnly,
    bool? newBandOnly,
    DuplicateChecker? dupeChecker,
  }) {
    return ClusterFilter(
      bands: bands ?? this.bands,
      modes: modes ?? this.modes,
      neededOnly: neededOnly ?? this.neededOnly,
      newBandOnly: newBandOnly ?? this.newBandOnly,
      dupeChecker: dupeChecker ?? this.dupeChecker,
    );
  }
}
