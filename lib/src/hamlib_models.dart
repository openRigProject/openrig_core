/// Common hamlib radio models for use in UI pickers.
///
/// Model IDs verified against hamlib 4.7.0 (2026-02-15).
library;

/// A hamlib rig model entry.
typedef HamlibModel = ({int id, String name, String manufacturer});

/// Common hamlib models used in the openRig UI.
const List<HamlibModel> kCommonHamlibModels = [
  // Special
  (id: 1,    name: 'Dummy',    manufacturer: 'None'),
  (id: 2,    name: 'NET rigctl', manufacturer: 'None'),

  // Yaesu
  (id: 1020, name: 'FT-817',       manufacturer: 'Yaesu'),
  (id: 1022, name: 'FT-857',       manufacturer: 'Yaesu'),
  (id: 1023, name: 'FT-897',       manufacturer: 'Yaesu'),
  (id: 1027, name: 'FT-450',       manufacturer: 'Yaesu'),
  (id: 1028, name: 'FT-950',       manufacturer: 'Yaesu'),
  (id: 1029, name: 'FT-2000',      manufacturer: 'Yaesu'),
  (id: 1032, name: 'FTDX-5000',    manufacturer: 'Yaesu'),
  (id: 1034, name: 'FTDX-1200',    manufacturer: 'Yaesu'),
  (id: 1035, name: 'FT-991',       manufacturer: 'Yaesu'),
  (id: 1036, name: 'FT-891',       manufacturer: 'Yaesu'),
  (id: 1037, name: 'FTDX-3000',    manufacturer: 'Yaesu'),
  (id: 1040, name: 'FTDX-101D',    manufacturer: 'Yaesu'),
  (id: 1041, name: 'FT-818',       manufacturer: 'Yaesu'),
  (id: 1042, name: 'FTDX-10',      manufacturer: 'Yaesu'),
  (id: 1044, name: 'FTDX-101MP',   manufacturer: 'Yaesu'),
  (id: 1046, name: 'FT-450D',      manufacturer: 'Yaesu'),
  (id: 1049, name: 'FT-710',       manufacturer: 'Yaesu'),
  (id: 1051, name: 'FTX-1',        manufacturer: 'Yaesu'),

  // Kenwood
  (id: 2001, name: 'TS-50S',   manufacturer: 'Kenwood'),
  (id: 2002, name: 'TS-440S',  manufacturer: 'Kenwood'),
  (id: 2004, name: 'TS-570D',  manufacturer: 'Kenwood'),
  (id: 2014, name: 'TS-2000',  manufacturer: 'Kenwood'),
  (id: 2028, name: 'TS-480',   manufacturer: 'Kenwood'),
  (id: 2031, name: 'TS-590S',  manufacturer: 'Kenwood'),
  (id: 2037, name: 'TS-590SG', manufacturer: 'Kenwood'),
  (id: 2039, name: 'TS-990S',  manufacturer: 'Kenwood'),
  (id: 2041, name: 'TS-890S',  manufacturer: 'Kenwood'),

  // Elecraft
  (id: 2021, name: 'K2',  manufacturer: 'Elecraft'),
  (id: 2029, name: 'K3',  manufacturer: 'Elecraft'),
  (id: 2043, name: 'K3S', manufacturer: 'Elecraft'),
  (id: 2044, name: 'KX2', manufacturer: 'Elecraft'),
  (id: 2045, name: 'KX3', manufacturer: 'Elecraft'),
  (id: 2047, name: 'K4',  manufacturer: 'Elecraft'),

  // Icom
  (id: 3013, name: 'IC-718',      manufacturer: 'Icom'),
  (id: 3044, name: 'IC-910',      manufacturer: 'Icom'),
  (id: 3057, name: 'IC-756PROIII', manufacturer: 'Icom'),
  (id: 3060, name: 'IC-7000',     manufacturer: 'Icom'),
  (id: 3061, name: 'IC-7200',     manufacturer: 'Icom'),
  (id: 3062, name: 'IC-7700',     manufacturer: 'Icom'),
  (id: 3063, name: 'IC-7600',     manufacturer: 'Icom'),
  (id: 3070, name: 'IC-7100',     manufacturer: 'Icom'),
  (id: 3073, name: 'IC-7300',     manufacturer: 'Icom'),
  (id: 3075, name: 'IC-7850/7851', manufacturer: 'Icom'),
  (id: 3078, name: 'IC-7610',     manufacturer: 'Icom'),
  (id: 3081, name: 'IC-9700',     manufacturer: 'Icom'),
  (id: 3085, name: 'IC-705',      manufacturer: 'Icom'),
  (id: 3090, name: 'IC-905',      manufacturer: 'Icom'),
  (id: 3092, name: 'IC-7760',     manufacturer: 'Icom'),
  (id: 3094, name: 'IC-7300MK2',  manufacturer: 'Icom'),

  // Ten-Tec
  (id: 16002, name: 'TT-538 Jupiter',     manufacturer: 'Ten-Tec'),
  (id: 16007, name: 'TT-516 Argonaut V',  manufacturer: 'Ten-Tec'),
  (id: 16008, name: 'TT-565/566 Orion',   manufacturer: 'Ten-Tec'),
  (id: 16011, name: 'TT-588 Omni VII',    manufacturer: 'Ten-Tec'),
  (id: 16013, name: 'TT-599 Eagle',       manufacturer: 'Ten-Tec'),

  // Alinco
  (id: 17002, name: 'DX-SR8', manufacturer: 'Alinco'),

  // FlexRadio
  (id: 2036,  name: '6xxx Series',     manufacturer: 'FlexRadio'),
  (id: 2048,  name: 'PowerSDR',        manufacturer: 'FlexRadio'),
  (id: 23005, name: 'SmartSDR Slice A', manufacturer: 'FlexRadio'),
  (id: 23006, name: 'SmartSDR Slice B', manufacturer: 'FlexRadio'),
  (id: 23007, name: 'SmartSDR Slice C', manufacturer: 'FlexRadio'),
  (id: 23008, name: 'SmartSDR Slice D', manufacturer: 'FlexRadio'),
];
