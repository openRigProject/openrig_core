import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

void main() {
  group('lookupDxcc', () {
    test('US callsigns', () {
      expect(lookupDxcc('W1AW'), equals('United States'));
      expect(lookupDxcc('K3LR'), equals('United States'));
      expect(lookupDxcc('N1MM'), equals('United States'));
      expect(lookupDxcc('AA1A'), equals('United States'));
      expect(lookupDxcc('AK7AZ'), equals('United States'));
    });

    test('Canadian callsigns', () {
      expect(lookupDxcc('VE3ABC'), equals('Canada'));
      expect(lookupDxcc('VA7XX'), equals('Canada'));
    });

    test('European callsigns', () {
      expect(lookupDxcc('G3ABC'), equals('England'));
      expect(lookupDxcc('M0ABC'), equals('England'));
      expect(lookupDxcc('DL1ABC'), equals('Fed. Rep. of Germany'));
      expect(lookupDxcc('F5ABC'), equals('France'));
      expect(lookupDxcc('SP9ABC'), equals('Poland'));
      expect(lookupDxcc('OH2ABC'), equals('Finland'));
      expect(lookupDxcc('SM5ABC'), equals('Sweden'));
      expect(lookupDxcc('PA3ABC'), equals('Netherlands'));
      expect(lookupDxcc('EA4ABC'), equals('Spain'));
      expect(lookupDxcc('UR5ABC'), equals('Ukraine'));
      expect(lookupDxcc('HB9ABC'), equals('Switzerland'));
      expect(lookupDxcc('OE1ABC'), equals('Austria'));
      expect(lookupDxcc('OZ1ABC'), equals('Denmark'));
      expect(lookupDxcc('HA5ABC'), equals('Hungary'));
      expect(lookupDxcc('OK1ABC'), equals('Czech Republic'));
      expect(lookupDxcc('OM3ABC'), equals('Slovak Republic'));
      expect(lookupDxcc('YO3ABC'), equals('Romania'));
      expect(lookupDxcc('LY2ABC'), equals('Lithuania'));
      expect(lookupDxcc('ES1ABC'), equals('Estonia'));
      expect(lookupDxcc('YL2ABC'), equals('Latvia'));
    });

    test('Asian callsigns', () {
      expect(lookupDxcc('JA1ABC'), equals('Japan'));
      expect(lookupDxcc('JH1ABC'), equals('Japan'));
      expect(lookupDxcc('HL5ABC'), equals('South Korea'));
      expect(lookupDxcc('BY1ABC'), equals('China'));
      expect(lookupDxcc('BV2ABC'), equals('Taiwan'));
      expect(lookupDxcc('VU2ABC'), equals('India'));
      expect(lookupDxcc('HS0ABC'), equals('Thailand'));
      expect(lookupDxcc('9V1ABC'), equals('Singapore'));
      expect(lookupDxcc('UN7ABC'), equals('Kazakhstan'));
    });

    test('Russian callsigns — European vs Asiatic', () {
      expect(lookupDxcc('UA3ABC'), equals('European Russia'));
      expect(lookupDxcc('UA9ABC'), equals('Asiatic Russia'));
      expect(lookupDxcc('UA0ABC'), equals('Asiatic Russia'));
    });

    test('South American callsigns', () {
      expect(lookupDxcc('PY2ABC'), equals('Brazil'));
      expect(lookupDxcc('LU1ABC'), equals('Argentina'));
      expect(lookupDxcc('CE3ABC'), equals('Chile'));
      expect(lookupDxcc('HC2ABC'), equals('Ecuador'));
      expect(lookupDxcc('OA4ABC'), equals('Peru'));
      expect(lookupDxcc('CX2ABC'), equals('Uruguay'));
    });

    test('African callsigns', () {
      expect(lookupDxcc('ZS6ABC'), equals('South Africa'));
      expect(lookupDxcc('5B4ABC'), equals('Cyprus'));
    });

    test('strips portable suffix /P', () {
      expect(lookupDxcc('W1AW/P'), equals('United States'));
    });

    test('strips portable suffix /QRP', () {
      expect(lookupDxcc('DL1ABC/QRP'), equals('Fed. Rep. of Germany'));
    });

    test('strips portable suffix /M', () {
      expect(lookupDxcc('G3ABC/M'), equals('England'));
    });

    test('case insensitive', () {
      expect(lookupDxcc('w1aw'), equals('United States'));
      expect(lookupDxcc('ja1abc'), equals('Japan'));
    });

    test('returns Unknown for unrecognized prefix', () {
      expect(lookupDxcc('XX9ZZZ'), equals('Unknown'));
    });
  });

  group('lookupDxccOrNull', () {
    test('returns null for unrecognized prefix', () {
      expect(lookupDxccOrNull('XX9ZZZ'), isNull);
    });

    test('returns null for empty string', () {
      expect(lookupDxccOrNull(''), isNull);
    });

    test('returns entity for known prefix', () {
      expect(lookupDxccOrNull('W1AW'), equals('United States'));
    });
  });
}
