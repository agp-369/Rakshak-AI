import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_ai/data/disaster_knowledge.dart';
import 'package:rakshak_ai/services/ai_engine.dart';
import 'package:rakshak_ai/services/alert_service.dart';
import 'package:rakshak_ai/services/beacon_service.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/services/voice_intent.dart';
import 'package:rakshak_ai/data/survival_scenarios.dart';

void main() {
  group('BeaconType', () {
    test('has three life-safety states with bilingual labels', () {
      expect(BeaconType.values.length, 3);
      for (final t in BeaconType.values) {
        expect(t.labelEn.isNotEmpty, true);
        expect(t.labelHi.isNotEmpty, true);
      }
    });
  });

  group('BeaconService.composeMessage', () {
    final svc = BeaconService();

    test('includes type, GPS and timestamp when location present', () {
      final msg = svc.composeMessage(
        BeaconType.needHelp,
        location: GeoPoint(latitude: 30.12345, longitude: 78.54321),
      );
      expect(msg.contains('NEED HELP'), true);
      expect(msg.contains('30.12345'), true);
      expect(msg.contains('78.54321'), true);
      expect(msg.contains('[RAKSHAK]'), true);
    });

    test('states location unavailable when no GPS', () {
      final msg = svc.composeMessage(BeaconType.safe);
      expect(msg.contains('location unavailable'), true);
    });

    test('includes the note when provided', () {
      final msg = svc.composeMessage(BeaconType.safe, note: 'trapped on roof');
      expect(msg.contains('trapped on roof'), true);
    });
  });

  group('BeaconRecord serialization', () {
    test('round-trips through JSON', () {
      final record = BeaconRecord(
        id: '1',
        type: BeaconType.evacuate,
        message: 'test',
        recipients: ['999', '108'],
        timestamp: DateTime(2026, 8, 26, 2, 30),
        delivered: false,
        latitude: 12.3,
        longitude: 45.6,
      );
      final back = BeaconRecord.fromJson(record.toJson());
      expect(back.type, BeaconType.evacuate);
      expect(back.recipients, ['999', '108']);
      expect(back.delivered, false);
      expect(back.latitude, 12.3);
    });

    test('parses unknown type defensively', () {
      final back = BeaconRecord.fromJson({
        'id': 'x',
        'type': 'bogus',
        'message': 'm',
        'recipients': <String>[],
        'timestamp': DateTime.now().toIso8601String(),
      });
      expect(back.type, BeaconType.needHelp);
    });
  });

  group('VoiceIntentParser', () {
    test('detects safe beacon (English + Hindi)', () {
      expect(VoiceIntentParser.parse('I am safe').action, 'beacon_safe');
      expect(VoiceIntentParser.parse('मैं सुरक्षित हूँ').action, 'beacon_safe');
      expect(VoiceIntentParser.parse('sab theek hai').action, 'beacon_safe');
    });

    test('detects help beacon', () {
      expect(VoiceIntentParser.parse('I need help').action, 'beacon_help');
      expect(VoiceIntentParser.parse('बचाओ मुझे').action, 'beacon_help');
      expect(VoiceIntentParser.parse('I am injured').action, 'beacon_help');
    });

    test('detects evacuation beacon', () {
      expect(VoiceIntentParser.parse('evacuate now').action, 'beacon_evac');
      expect(VoiceIntentParser.parse('भागो यहाँ से').action, 'beacon_evac');
    });

    test('routes survival questions to guides', () {
      expect(VoiceIntentParser.parse('what do i do in a landslide').action,
          'open_survival');
    });

    test('detects where am i', () {
      expect(VoiceIntentParser.parse('where am i').action, 'where_am_i');
    });

    test('detects family', () {
      expect(VoiceIntentParser.parse('is my family ok').action, 'open_family');
    });

    test('empty input is unknown', () {
      expect(VoiceIntentParser.parse('').action, 'unknown');
    });
  });

  group('AlertTranslator', () {
    test('red flood gives move-to-higher-ground advice', () {
      final t = AlertTranslator.translate(
        hazardType: 'flood',
        severity: AlertSeverity.red,
        officialText: 'extremely heavy rainfall warning',
        hindi: false,
      );
      expect(t.toLowerCase().contains('higher ground'), true);
    });

    test('hindi translation is non-empty', () {
      final t = AlertTranslator.translate(
        hazardType: 'landslide',
        severity: AlertSeverity.orange,
        officialText: '',
        hindi: true,
      );
      expect(t.isNotEmpty, true);
    });

    test('every hazard type returns actionable text', () {
      for (final h in [
        'rain',
        'flood',
        'landslide',
        'earthquake',
        'cyclone',
        'heatwave',
        'lightning',
        'unknown'
      ]) {
        final t = AlertTranslator.translate(
          hazardType: h,
          severity: AlertSeverity.red,
          officialText: '',
          hindi: false,
        );
        expect(t.length > 10, true, reason: 'hazard $h');
      }
    });
  });

  group('Survival scenarios', () {
    test('library covers the highest-fatality Indian hazards', () {
      final ids = survivalScenarios.map((s) => s.id).toList();
      expect(ids.contains('flash_flood'), true);
      expect(ids.contains('landslide'), true);
      expect(ids.contains('earthquake'), true);
      expect(ids.contains('bleeding'), true);
      expect(ids.contains('trapped'), true);
      expect(ids.contains('night_evac'), true);
    });

    test('every scenario has steps, donts and speech in both languages', () {
      for (final s in survivalScenarios) {
        expect(s.immediateStepsEn.isNotEmpty, true, reason: s.id);
        expect(s.immediateStepsHi.length, s.immediateStepsEn.length,
            reason: s.id);
        expect(s.dontsEn.isNotEmpty, true, reason: s.id);
        expect(s.speakEn.isNotEmpty, true, reason: s.id);
        expect(s.speakHi.isNotEmpty, true, reason: s.id);
      }
    });

    test('findScenario resolves keywords and bilingual terms', () {
      expect(findScenario('flood')?.id, 'flash_flood');
      expect(findScenario('भूकंप')?.id, 'earthquake');
      expect(findScenario('bleeding badly')?.id, 'bleeding');
      expect(findScenario('nonsense xyz'), isNull);
    });
  });

  group('FamilyStatus labels', () {
    test('each status has both labels', () {
      for (final s in [
        AlertSeverity.red,
        AlertSeverity.orange,
        AlertSeverity.yellow,
        AlertSeverity.green,
      ]) {
        expect(s.label.isNotEmpty, true);
      }
    });
  });

  group('Offline knowledge base', () {
    test('every chunk is bilingual and sourced', () {
      expect(disasterKnowledge.isNotEmpty, true);
      for (final c in disasterKnowledge) {
        expect(c.id.isNotEmpty, true);
        expect(c.textEn.length > 30, true, reason: c.id);
        expect(c.textHi.length > 20, true, reason: c.id);
        expect(c.source.isNotEmpty, true, reason: c.id);
        expect(c.tags.isNotEmpty, true, reason: c.id);
      }
    });

    test('retriever finds flood guidance in English', () {
      final hits = KnowledgeRetriever.search('water is rising in my room');
      expect(hits.isNotEmpty, true);
      expect(hits.first.hazard, 'flood');
    });

    test('retriever finds bleeding guidance in Hindi', () {
      final hits = KnowledgeRetriever.search('खून बह रहा है');
      expect(hits.isNotEmpty, true);
      expect(hits.any((c) => c.id == 'bleeding_control'), true);
    });

    test('retriever honours a hazard hint', () {
      final hits =
          KnowledgeRetriever.search('what should I do', hazardHint: 'landslide');
      expect(hits.first.hazard, 'landslide');
    });

    test('retriever returns nothing for nonsense', () {
      expect(KnowledgeRetriever.search('xyzzy plugh quux'), isEmpty);
    });
  });

  group('AiEngine safety fallbacks (no model present)', () {
    test('alert interpretation falls back to a verified rule', () async {
      final r = await AiEngine().interpretAlert(
        officialText: 'extremely heavy rainfall expected',
        severity: AlertSeverity.red,
        hazardHint: 'flood',
        hindi: false,
      );
      expect(r.source, AiSource.rule);
      expect(r.actions.isNotEmpty, true);
      expect(r.speakText.isNotEmpty, true);
    });

    test('survival answer is cited even without the model', () async {
      final a = await AiEngine()
          .answerSurvival('flood water is rising', hindi: false);
      expect(a.source, AiSource.rule);
      expect(a.text.isNotEmpty, true);
      expect(a.citations.isNotEmpty, true);
    });

    test('survival answer is honest when nothing matches', () async {
      final a = await AiEngine()
          .answerSurvival('quantum chromodynamics', hindi: false);
      expect(a.source, AiSource.rule);
      expect(a.confidence < 0.5, true);
    });

    test('distress parsing extracts injury, trapped and people', () async {
      final d = await AiEngine().parseDistress(
          'I need help, 3 people, bleeding and trapped',
          hindi: false);
      expect(d.source, AiSource.rule);
      expect(d.intent, 'beacon_help');
      expect(d.injured, true);
      expect(d.trapped, true);
      expect(d.people, 3);
    });

    test('situation brief prioritises family needing help', () async {
      final a = await AiEngine().synthesizeSituation(
        activeHazards: ['flood'],
        familyNeedingHelp: 2,
        familyUnknown: 0,
        night: true,
        hindi: false,
      );
      expect(a.source, AiSource.rule);
      expect(a.text.toLowerCase().contains('help'), true);
    });
  });
}
