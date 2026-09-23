import 'package:flutter_test/flutter_test.dart';
import 'package:nexusfarm/core/districts.dart';
import 'package:nexusfarm/services/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('district list', () {
    test('has all 64 districts, no duplicates, across 8 divisions', () {
      expect(districts.length, 64);
      expect(districts.map((d) => d.name).toSet().length, 64);
      expect(districts.map((d) => d.division).toSet().length, 8);
    });

    test('ignores case, spacing and punctuation', () {
      expect(normalizeDistrict('bogura'), 'Bogura');
      expect(normalizeDistrict('  BOGURA '), 'Bogura');
      expect(normalizeDistrict("cox's bazar"), "Cox's Bazar");
      expect(normalizeDistrict('Coxs Bazar'), "Cox's Bazar");
      expect(normalizeDistrict('chapai nawabganj'), 'Chapai Nawabganj');
    });

    test('accepts the old English spellings', () {
      expect(normalizeDistrict('Bogra'), 'Bogura');
      expect(normalizeDistrict('Chittagong'), 'Chattogram');
      expect(normalizeDistrict('Comilla'), 'Cumilla');
      expect(normalizeDistrict('Barisal'), 'Barishal');
      expect(normalizeDistrict('Jessore'), 'Jashore');
    });

    test('an upazila used by early versions maps to its district', () {
      expect(normalizeDistrict('Savar'), 'Dhaka');
    });

    test('rejects anything that is not a district', () {
      expect(normalizeDistrict('Atlantis'), isNull);
      expect(normalizeDistrict(''), isNull);
      expect(isKnownDistrict('Dhaka'), isTrue);
    });

    test('every alias points at a real district', () {
      for (final d in districts) {
        expect(normalizeDistrict(d.name), d.name);
      }
    });
  });

  group('stored profile from older versions', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('old spelling is rewritten; phone number is deleted', () async {
      SharedPreferences.setMockInitialValues({
        'farmer_district': 'Bogra',
        'farmer_phone': '01700000000',
      });
      await Session.instance.load();
      final prefs = await SharedPreferences.getInstance();

      expect(Session.instance.district, 'Bogura');
      expect(Session.instance.districtNeedsReview, isFalse);
      expect(prefs.getString('farmer_district'), 'Bogura');
      expect(prefs.containsKey('farmer_phone'), isFalse,
          reason: 'an unused phone number must not stay on the device');
    });

    test('an unknown district falls back and asks to be chosen', () async {
      SharedPreferences.setMockInitialValues({'farmer_district': 'Atlantis'});
      await Session.instance.load();
      expect(Session.instance.district, Session.defaultDistrict);
      expect(Session.instance.districtNeedsReview, isTrue);
    });

    test('the old default "Savar" becomes Dhaka', () async {
      SharedPreferences.setMockInitialValues({'farmer_district': 'Savar'});
      await Session.instance.load();
      expect(Session.instance.district, 'Dhaka');
      expect(Session.instance.districtNeedsReview, isFalse);
    });
  });
}
