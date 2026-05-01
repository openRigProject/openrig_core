/// DXCC prefix lookup.
///
/// Maps amateur radio callsign prefixes to DXCC entity names.
/// Strips portable suffixes and uses longest-prefix matching.
library;

/// Portable suffixes to strip before prefix lookup.
final _portableSuffixes = RegExp(r'/[PQMAM0-9]+$', caseSensitive: false);

/// DXCC prefix-to-entity map, ordered for longest-prefix-first matching.
///
/// Covers ~60 common DXCC entities. Longer prefixes must come before shorter
/// ones for correct matching (e.g. 'UA9' before 'UA').
const Map<String, String> _dxccPrefixes = {
  // Oceania
  'VK': 'Australia',
  'ZL': 'New Zealand',

  // Asia
  'JA': 'Japan',
  'JH': 'Japan',
  'JR': 'Japan',
  'JE': 'Japan',
  'JF': 'Japan',
  'JG': 'Japan',
  'JI': 'Japan',
  'JJ': 'Japan',
  'JK': 'Japan',
  'JL': 'Japan',
  'JM': 'Japan',
  'JN': 'Japan',
  'JO': 'Japan',
  'JP': 'Japan',
  'JQ': 'Japan',
  'JS': 'Japan',
  'UA9': 'Asiatic Russia',
  'UA0': 'Asiatic Russia',
  'RA9': 'Asiatic Russia',
  'RA0': 'Asiatic Russia',
  'UA': 'European Russia',
  'RA': 'European Russia',
  'HL': 'South Korea',
  'DS': 'South Korea',
  'BY': 'China',
  'BV': 'Taiwan',
  'JT': 'Mongolia',
  'HS': 'Thailand',
  '9V': 'Singapore',
  'VS6': 'Hong Kong',
  'VU': 'India',
  'UN': 'Kazakhstan',
  'A9': 'Bahrain',
  'A6': 'United Arab Emirates',

  // North America
  'VE': 'Canada',
  'VA': 'Canada',
  'VY': 'Canada',
  'VO': 'Canada',
  'XE': 'Mexico',
  'XF': 'Mexico',
  'AA': 'United States',
  'AB': 'United States',
  'AC': 'United States',
  'AD': 'United States',
  'AE': 'United States',
  'AF': 'United States',
  'AG': 'United States',
  'AH': 'United States',
  'AI': 'United States',
  'AJ': 'United States',
  'AK': 'United States',
  'AL': 'United States',
  'KP': 'United States',
  'W': 'United States',
  'K': 'United States',
  'N': 'United States',

  // South America
  'PY': 'Brazil',
  'PP': 'Brazil',
  'PR': 'Brazil',
  'PS': 'Brazil',
  'PT': 'Brazil',
  'PU': 'Brazil',
  'LU': 'Argentina',
  'LW': 'Argentina',
  'CE': 'Chile',
  'HC': 'Ecuador',
  'OA': 'Peru',
  'CP': 'Bolivia',
  'ZP': 'Paraguay',
  'CX': 'Uruguay',

  // Europe
  'G': 'England',
  'M': 'England',
  '2E': 'England',
  'DL': 'Fed. Rep. of Germany',
  'DA': 'Fed. Rep. of Germany',
  'DB': 'Fed. Rep. of Germany',
  'DC': 'Fed. Rep. of Germany',
  'DD': 'Fed. Rep. of Germany',
  'DE': 'Fed. Rep. of Germany',
  'DF': 'Fed. Rep. of Germany',
  'DG': 'Fed. Rep. of Germany',
  'DH': 'Fed. Rep. of Germany',
  'DI': 'Fed. Rep. of Germany',
  'DJ': 'Fed. Rep. of Germany',
  'DK': 'Fed. Rep. of Germany',
  'DO': 'Fed. Rep. of Germany',
  'F': 'France',
  'I': 'Italy',
  'IK': 'Italy',
  'IZ': 'Italy',
  'SP': 'Poland',
  'SQ': 'Poland',
  'OH': 'Finland',
  'SM': 'Sweden',
  'SA': 'Sweden',
  'PA': 'Netherlands',
  'PD': 'Netherlands',
  'PE': 'Netherlands',
  'PH': 'Netherlands',
  'EA': 'Spain',
  'EB': 'Spain',
  'EC': 'Spain',
  'UR': 'Ukraine',
  'UT': 'Ukraine',
  'UX': 'Ukraine',
  'OZ': 'Denmark',
  'OE': 'Austria',
  'HB9': 'Switzerland',
  'HB': 'Switzerland',
  'HA': 'Hungary',
  'OK': 'Czech Republic',
  'OL': 'Czech Republic',
  'OM': 'Slovak Republic',
  'YO': 'Romania',
  'LY': 'Lithuania',
  'ES': 'Estonia',
  'YL': 'Latvia',

  // Africa
  'ZS': 'South Africa',
  '5B': 'Cyprus',
};

/// Sorted prefix list, longest first, for matching.
final List<String> _sortedPrefixes = () {
  final keys = _dxccPrefixes.keys.toList();
  keys.sort((a, b) => b.length.compareTo(a.length));
  return keys;
}();

/// Strip portable suffixes from a callsign.
///
/// Examples: W1AW/P -> W1AW, VE3/W1AW -> VE3/W1AW (prefix stays),
/// W1AW/QRP -> W1AW, W1AW/M -> W1AW
String _stripSuffix(String call) {
  return call.replaceAll(_portableSuffixes, '');
}

/// Look up the DXCC entity name for a callsign.
///
/// Strips portable suffixes (/P, /QRP, /M, etc.) and tries longest
/// prefix match first. Returns the entity name or `'Unknown'`.
String lookupDxcc(String callsign) {
  return lookupDxccOrNull(callsign) ?? 'Unknown';
}

/// Look up the DXCC entity name for a callsign.
///
/// Returns `null` if no matching prefix is found.
String? lookupDxccOrNull(String callsign) {
  final call = _stripSuffix(callsign.toUpperCase().trim());
  if (call.isEmpty) return null;

  for (final prefix in _sortedPrefixes) {
    if (call.startsWith(prefix)) {
      return _dxccPrefixes[prefix];
    }
  }
  return null;
}
