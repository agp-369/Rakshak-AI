import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_ai/models/damage_survey.dart';
import 'package:rakshak_ai/models/model_pack.dart';
import 'package:rakshak_ai/services/contacts_service.dart';
import 'package:rakshak_ai/services/damage_survey_service.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/services/location_descriptor_service.dart';

void main() {
  group('LocationDescriptorService', () {
    final descriptor = LocationDescriptorService();

    test('accurately identifies Dehradun Clock Tower and direction in offline mode', () async {
      // Point 500m North of Clock Tower (30.3255, 78.0413)
      final point = GeoPoint(latitude: 30.3300, longitude: 78.0413, accuracy: 5);
      final desc = await descriptor.describeLocation(point, forceOffline: true);

      expect(desc.landmarkEn.contains('Clock Tower'), true);
      expect(desc.districtEn, 'Dehradun');
      expect(desc.stateEn, 'Uttarakhand');
      expect(desc.stateHi, 'उत्तराखंड');
      expect(desc.compassDirectionEn, 'North');
      expect(desc.compassDirectionHi, 'उत्तर');
      expect(desc.distanceMeters > 300 && desc.distanceMeters < 800, true);

      final formattedEn = desc.formattedEn();
      expect(formattedEn.contains('Clock Tower'), true);
      expect(formattedEn.contains('Dehradun'), true);
      expect(formattedEn.contains('Uttarakhand'), true);

      final radioEn = desc.radioScriptEn();
      expect(radioEn.contains('Coordinates'), true);
      expect(radioEn.contains('Dehradun'), true);

      final radioHi = desc.radioScriptHi();
      expect(radioHi.contains('देहरादून'), true);
      expect(radioHi.contains('उत्तराखंड'), true);
    });

    test('accurately identifies Wayanad disaster zone in offline mode', () async {
      // Chooralmala (11.5362, 76.1751)
      final point = GeoPoint(latitude: 11.5370, longitude: 76.1760, accuracy: 10);
      final desc = await descriptor.describeLocation(point, forceOffline: true);

      expect(desc.districtEn, 'Wayanad');
      expect(desc.districtHi, 'वायनाड');
      expect(desc.stateEn, 'Kerala');
      expect(desc.stateHi, 'केरल');
    });

    test('accurately identifies Guwahati / Brahmaputra zone in offline mode', () async {
      // Near Guwahati (26.1859, 91.7478)
      final point = GeoPoint(latitude: 26.1870, longitude: 91.7500, accuracy: 8);
      final desc = await descriptor.describeLocation(point, forceOffline: true);

      expect(desc.stateEn, 'Assam');
      expect(desc.stateHi, 'असम');
    });
  });

  group('ModelTier Architecture', () {
    test('defines small to big tiers with correct files and RAM requirements', () {
      expect(ModelTier.values.length, 3);

      final tiny = ModelTier.tiny;
      expect(tiny.sizeMb, 304);
      expect(tiny.minRamMb, 1024);
      expect(tiny.modelFile.contains('270m'), true);
      expect(tiny.recommendedForLowRam, true);

      final small = ModelTier.small;
      expect(small.sizeMb, 584);
      expect(small.minRamMb, 2048);
      expect(small.modelFile.contains('1b'), true);
      expect(small.recommendedForLowRam, true);

      final full = ModelTier.full;
      expect(full.sizeMb, 2560);
      expect(full.minRamMb, 6144);
      expect(full.modelFile.contains('E2B'), true);
      expect(full.recommendedForLowRam, false);
    });

    test('default download URLs point to valid repository targets', () {
      for (final tier in ModelTier.values) {
        expect(tier.defaultDownloadUrl.startsWith('https://'), true);
        expect(tier.defaultDownloadUrl.contains(tier.modelFile), true);
      }
    });
  });

  group('ContactEntry', () {
    test('computes initials correctly for single and multi-word names', () {
      const c1 = ContactEntry(id: '1', name: 'Papa', phone: '9876543210');
      expect(c1.initials, 'P');

      const c2 = ContactEntry(id: '2', name: 'Dr. Ramesh Sharma', phone: '9123456780');
      expect(c2.initials, 'DR');

      const c3 = ContactEntry(id: '3', name: '', phone: '112');
      expect(c3.initials, '?');
    });
  });

  group('DamageSurveyRecord & Service', () {
    test('round-trips damage survey through JSON correctly', () {
      final survey = DamageSurveyRecord(
        id: 'survey_12345',
        imagePath: '/data/user/0/com.example.rakshak_ai/surveys/test.jpg',
        timestamp: DateTime(2026, 10, 24, 15, 30),
        latitude: 30.3255,
        longitude: 78.0413,
        accuracy: 4.5,
        landmarkAndVillage: '~800m NE of Clock Tower, Dehradun',
        beneficiaryName: 'Suraj Pal Singh',
        houseId: 'UK-DDN-402',
        structureType: StructureType.residential,
        damageSeverity: DamageSeverity.severe,
        waterMarkMeters: 1.8,
        isHabitable: false,
        notes: 'Roof partially blown away and structural cracks on eastern wall',
      );

      final json = survey.toJson();
      final parsed = DamageSurveyRecord.fromJson(json);

      expect(parsed.id, 'survey_12345');
      expect(parsed.beneficiaryName, 'Suraj Pal Singh');
      expect(parsed.damageSeverity, DamageSeverity.severe);
      expect(parsed.isHabitable, false);
      expect(parsed.waterMarkMeters, 1.8);
      expect(parsed.structureType, StructureType.residential);
    });

    test('generates valid standard CSV with headers and escaped fields', () {
      final svc = DamageSurveyService();
      final survey = DamageSurveyRecord(
        id: 'survey_999',
        imagePath: '/tmp/test.jpg',
        timestamp: DateTime(2026, 10, 24, 12, 0),
        latitude: 11.5362,
        longitude: 76.1751,
        accuracy: 6.0,
        landmarkAndVillage: 'Chooralmala Bridge, Wayanad',
        beneficiaryName: 'Mohammad Rafiq',
        houseId: 'KL-WYD-101',
        structureType: StructureType.commercial,
        damageSeverity: DamageSeverity.destroyed,
        waterMarkMeters: 3.2,
        isHabitable: false,
        notes: 'Shop washed away by flash flood',
      );

      final csv = svc.exportToCsv([survey]);
      expect(csv.contains('Survey_ID,Timestamp,Latitude'), true);
      expect(csv.contains('survey_999'), true);
      expect(csv.contains('Chooralmala Bridge, Wayanad'), true);
      expect(csv.contains('Mohammad Rafiq'), true);
      expect(csv.contains('Completely Destroyed'), true);
      expect(csv.contains('11.53620'), true);
    });
  });
}
