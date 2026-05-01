/// Amateur radio band plan.
///
/// Defines HF and VHF/UHF bands with US sub-band segments.
/// Provides frequency-to-band lookup.
library;

/// A sub-band segment within a band.
class SubBand {
  final String name;
  final double lowerMhz;
  final double upperMhz;

  const SubBand({
    required this.name,
    required this.lowerMhz,
    required this.upperMhz,
  });

  bool contains(double mhz) => mhz >= lowerMhz && mhz <= upperMhz;
}

/// An amateur radio band.
class Band {
  final String name;
  final double lowerMhz;
  final double upperMhz;
  final List<SubBand> subBands;

  const Band({
    required this.name,
    required this.lowerMhz,
    required this.upperMhz,
    this.subBands = const [],
  });

  bool contains(double mhz) => mhz >= lowerMhz && mhz <= upperMhz;

  /// Find the sub-band for a given frequency, or null.
  SubBand? subBandFromMhz(double mhz) {
    for (final sb in subBands) {
      if (sb.contains(mhz)) return sb;
    }
    return null;
  }
}

/// HF bands (160m through 10m) with US sub-band segments.
const List<Band> hfBands = [
  Band(
    name: '160m',
    lowerMhz: 1.800,
    upperMhz: 2.000,
    subBands: [
      SubBand(name: 'Digital', lowerMhz: 1.800, upperMhz: 1.850),
      SubBand(name: 'CW', lowerMhz: 1.800, upperMhz: 1.850),
      SubBand(name: 'SSB', lowerMhz: 1.850, upperMhz: 2.000),
    ],
  ),
  Band(
    name: '80m',
    lowerMhz: 3.500,
    upperMhz: 4.000,
    subBands: [
      SubBand(name: 'Digital', lowerMhz: 3.570, upperMhz: 3.600),
      SubBand(name: 'CW', lowerMhz: 3.500, upperMhz: 3.600),
      SubBand(name: 'SSB', lowerMhz: 3.600, upperMhz: 4.000),
    ],
  ),
  Band(
    name: '60m',
    lowerMhz: 5.3305,
    upperMhz: 5.4064,
    subBands: [
      SubBand(name: 'USB', lowerMhz: 5.3305, upperMhz: 5.4064),
    ],
  ),
  Band(
    name: '40m',
    lowerMhz: 7.000,
    upperMhz: 7.300,
    subBands: [
      SubBand(name: 'Digital', lowerMhz: 7.070, upperMhz: 7.125),
      SubBand(name: 'CW', lowerMhz: 7.000, upperMhz: 7.125),
      SubBand(name: 'SSB', lowerMhz: 7.125, upperMhz: 7.300),
    ],
  ),
  Band(
    name: '30m',
    lowerMhz: 10.100,
    upperMhz: 10.150,
    subBands: [
      SubBand(name: 'Digital', lowerMhz: 10.130, upperMhz: 10.150),
      SubBand(name: 'CW', lowerMhz: 10.100, upperMhz: 10.140),
    ],
  ),
  Band(
    name: '20m',
    lowerMhz: 14.000,
    upperMhz: 14.350,
    subBands: [
      SubBand(name: 'Digital', lowerMhz: 14.070, upperMhz: 14.112),
      SubBand(name: 'CW', lowerMhz: 14.000, upperMhz: 14.150),
      SubBand(name: 'SSB', lowerMhz: 14.150, upperMhz: 14.350),
    ],
  ),
  Band(
    name: '17m',
    lowerMhz: 18.068,
    upperMhz: 18.168,
    subBands: [
      SubBand(name: 'Digital', lowerMhz: 18.095, upperMhz: 18.110),
      SubBand(name: 'CW', lowerMhz: 18.068, upperMhz: 18.110),
      SubBand(name: 'SSB', lowerMhz: 18.110, upperMhz: 18.168),
    ],
  ),
  Band(
    name: '15m',
    lowerMhz: 21.000,
    upperMhz: 21.450,
    subBands: [
      SubBand(name: 'Digital', lowerMhz: 21.070, upperMhz: 21.110),
      SubBand(name: 'CW', lowerMhz: 21.000, upperMhz: 21.200),
      SubBand(name: 'SSB', lowerMhz: 21.200, upperMhz: 21.450),
    ],
  ),
  Band(
    name: '12m',
    lowerMhz: 24.890,
    upperMhz: 24.990,
    subBands: [
      SubBand(name: 'Digital', lowerMhz: 24.915, upperMhz: 24.930),
      SubBand(name: 'CW', lowerMhz: 24.890, upperMhz: 24.930),
      SubBand(name: 'SSB', lowerMhz: 24.930, upperMhz: 24.990),
    ],
  ),
  Band(
    name: '10m',
    lowerMhz: 28.000,
    upperMhz: 29.700,
    subBands: [
      SubBand(name: 'Digital', lowerMhz: 28.070, upperMhz: 28.150),
      SubBand(name: 'CW', lowerMhz: 28.000, upperMhz: 28.300),
      SubBand(name: 'SSB', lowerMhz: 28.300, upperMhz: 29.700),
    ],
  ),
];

/// VHF/UHF bands.
const List<Band> vhfUhfBands = [
  Band(
    name: '6m',
    lowerMhz: 50.000,
    upperMhz: 54.000,
    subBands: [
      SubBand(name: 'CW', lowerMhz: 50.000, upperMhz: 50.100),
      SubBand(name: 'Digital', lowerMhz: 50.300, upperMhz: 50.400),
      SubBand(name: 'SSB', lowerMhz: 50.100, upperMhz: 50.300),
      SubBand(name: 'FM', lowerMhz: 51.000, upperMhz: 54.000),
    ],
  ),
  Band(
    name: '2m',
    lowerMhz: 144.000,
    upperMhz: 148.000,
    subBands: [
      SubBand(name: 'CW', lowerMhz: 144.000, upperMhz: 144.100),
      SubBand(name: 'SSB', lowerMhz: 144.100, upperMhz: 144.300),
      SubBand(name: 'Digital', lowerMhz: 144.300, upperMhz: 144.500),
      SubBand(name: 'FM', lowerMhz: 145.200, upperMhz: 148.000),
    ],
  ),
  Band(
    name: '70cm',
    lowerMhz: 420.000,
    upperMhz: 450.000,
    subBands: [
      SubBand(name: 'Digital', lowerMhz: 420.000, upperMhz: 432.000),
      SubBand(name: 'SSB', lowerMhz: 432.000, upperMhz: 432.100),
      SubBand(name: 'FM', lowerMhz: 440.000, upperMhz: 450.000),
    ],
  ),
];

/// All bands combined (HF + VHF/UHF).
final List<Band> _allBands = [...hfBands, ...vhfUhfBands];

/// Find the band for a given frequency in MHz, or null.
Band? bandFromMhz(double mhz) {
  for (final band in _allBands) {
    if (band.contains(mhz)) return band;
  }
  return null;
}

/// Find the band for a given frequency in kHz, or null.
Band? bandFromKhz(double khz) => bandFromMhz(khz / 1000.0);

/// Find the band for a given frequency in Hz, or null.
Band? bandFromHz(int hz) => bandFromMhz(hz / 1000000.0);
