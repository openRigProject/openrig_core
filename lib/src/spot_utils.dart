/// DX spot deduplication and expiry utilities.
library;

import 'dx_cluster_client.dart';

/// Deduplicate a list of DxSpots.
///
/// Spots are considered duplicates if they have the same [dxCall] and their
/// frequencies are within [freqToleranceKhz] of each other. Among duplicates,
/// the most recent spot (latest [time]) is kept.
///
/// [maxAge] — if non-null, spots older than this are removed before dedup.
List<DxSpot> deduplicateSpots(
  List<DxSpot> spots, {
  double freqToleranceKhz = 1.0,
  Duration? maxAge,
  DateTime? now,
}) {
  var input = spots;
  if (maxAge != null) {
    input = expireSpots(input, maxAge, now: now);
  }

  final kept = <DxSpot>[];
  for (final spot in input) {
    final idx = kept.indexWhere((s) =>
        s.dxCall == spot.dxCall &&
        (s.frequencyKhz - spot.frequencyKhz).abs() <= freqToleranceKhz);
    if (idx >= 0) {
      if (spot.time.isAfter(kept[idx].time)) {
        kept[idx] = spot;
      }
    } else {
      kept.add(spot);
    }
  }
  return kept;
}

/// Remove spots older than [maxAge].
/// [now] defaults to DateTime.now().toUtc() — injectable for testing.
List<DxSpot> expireSpots(
  List<DxSpot> spots,
  Duration maxAge, {
  DateTime? now,
}) {
  final cutoff = (now ?? DateTime.now().toUtc()).subtract(maxAge);
  return spots.where((s) => s.time.isAfter(cutoff) || s.time == cutoff).toList();
}

/// Merge a new spot into an existing list, replacing any duplicate.
/// Returns the updated list with the new spot at the front.
List<DxSpot> mergeSpot(
  List<DxSpot> existing,
  DxSpot newSpot, {
  double freqToleranceKhz = 1.0,
}) {
  final result = existing.where((s) =>
      !(s.dxCall == newSpot.dxCall &&
          (s.frequencyKhz - newSpot.frequencyKhz).abs() <=
              freqToleranceKhz)).toList();
  return [newSpot, ...result];
}
