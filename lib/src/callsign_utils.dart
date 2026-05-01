/// Amateur radio callsign utilities.
library;

/// Regex for a bare callsign (no prefix/suffix): 1-3 alphanumeric, 1 digit, 1-4 letters.
final _baseCallRegex = RegExp(r'^[A-Z0-9]{1,3}[0-9][A-Z]{1,4}$');

/// Known portable/operational suffixes.
final _knownSuffixes = RegExp(
  r'^(P|M|MM|AM|QRP|QRPP|A|B|R|[0-9])$',
  caseSensitive: false,
);

/// Returns true if the string looks like a valid amateur callsign.
bool isValidCallsign(String callsign) {
  final norm = callsign.trim().toUpperCase();
  if (norm.length < 3 || norm.length > 12) return false;
  final base = baseCallsign(norm);
  return _baseCallRegex.hasMatch(base);
}

/// Normalize a callsign: uppercase, strip leading/trailing whitespace.
String normalizeCallsign(String callsign) => callsign.trim().toUpperCase();

/// Extract the base callsign, stripping prefix and suffix.
/// e.g. "EA/W1AW/P" -> "W1AW"
String baseCallsign(String callsign) {
  final norm = callsign.trim().toUpperCase();
  final parts = norm.split('/');
  if (parts.length == 1) return parts[0];
  if (parts.length == 2) {
    // Either PREFIX/CALL or CALL/SUFFIX
    if (_knownSuffixes.hasMatch(parts[1])) return parts[0];
    // Shorter part is the prefix
    if (parts[0].length < parts[1].length) return parts[1];
    return parts[0];
  }
  if (parts.length == 3) {
    // PREFIX/CALL/SUFFIX — middle part is the base
    return parts[1];
  }
  return norm;
}

/// Returns the prefix portion if present (e.g. "EA/W1AW" -> "EA"), else null.
String? callsignPrefix(String callsign) {
  final norm = callsign.trim().toUpperCase();
  final parts = norm.split('/');
  if (parts.length == 2) {
    // PREFIX/CALL: shorter part is the prefix, and it's not a known suffix
    if (!_knownSuffixes.hasMatch(parts[1]) && parts[0].length < parts[1].length) {
      return parts[0];
    }
    return null;
  }
  if (parts.length == 3) {
    return parts[0];
  }
  return null;
}

/// Returns the suffix portion if present (e.g. "W1AW/P" -> "P"), else null.
String? callsignSuffix(String callsign) {
  final norm = callsign.trim().toUpperCase();
  final parts = norm.split('/');
  if (parts.length == 2 && _knownSuffixes.hasMatch(parts[1])) {
    return parts[1];
  }
  if (parts.length == 3) {
    return parts[2];
  }
  return null;
}
