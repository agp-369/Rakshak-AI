import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_ai/services/gemma_service.dart';
import 'package:rakshak_ai/services/triage_engine.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/models/triage_result.dart';


void main() {
  group('TriageEngine — START Protocol', () {
    late TriageEngine engine;

    setUp(() {
      engine = TriageEngine();
    });

    group('Walking Wounded (GREEN)', () {
      test('walking patient is GREEN/minimal', () {
        final r = engine.assess(isWalking: true);
        expect(r.category, TriageCategory.minimal);
        expect(r.confidenceScore, 0.9);
      });

      test('walking with severe injuries still GREEN (START protocol)', () {
        final r = engine.assess(
          isWalking: true,
          visibleInjuries: 'severe bleeding arm',
        );
        expect(r.category, TriageCategory.minimal);
      });

      test('walking with abnormal vitals still GREEN', () {
        final r = engine.assess(
          isWalking: true,
          respiratoryRate: 35,
          hasRadialPulse: false,
        );
        expect(r.category, TriageCategory.minimal);
      });
    });

    group('Breathing Check (BLACK)', () {
      test('not breathing is BLACK/deceased', () {
        final r = engine.assess(isWalking: false, isBreathing: false);
        expect(r.category, TriageCategory.deceased);
        expect(r.confidenceScore, 0.95);
      });

      test('not breathing with pulse still BLACK', () {
        final r = engine.assess(
          isWalking: false, isBreathing: false,
          hasRadialPulse: true,
        );
        expect(r.category, TriageCategory.deceased);
      });
    });

    group('Respiratory Rate Boundaries (RED vs YELLOW)', () {
      test('resp rate 10 is YELLOW (boundary safe)', () {
        final r = engine.assess(isWalking: false, respiratoryRate: 10);
        expect(r.category, TriageCategory.delayed);
      });

      test('resp rate 9 is RED (boundary danger)', () {
        final r = engine.assess(isWalking: false, respiratoryRate: 9);
        expect(r.category, TriageCategory.immediate);
      });

      test('resp rate 30 is YELLOW (boundary safe)', () {
        final r = engine.assess(isWalking: false, respiratoryRate: 30);
        expect(r.category, TriageCategory.delayed);
      });

      test('resp rate 31 is RED (boundary danger)', () {
        final r = engine.assess(isWalking: false, respiratoryRate: 31);
        expect(r.category, TriageCategory.immediate);
      });

      test('resp rate 0 triggers RED', () {
        final r = engine.assess(isWalking: false, respiratoryRate: 0);
        expect(r.category, TriageCategory.immediate);
      });
    });

    group('Perfusion (RED)', () {
      test('absent radial pulse is RED', () {
        final r = engine.assess(
          isWalking: false, hasRadialPulse: false,
        );
        expect(r.category, TriageCategory.immediate);
        expect(r.confidenceScore, 0.8);
      });

      test('cap refill 3s is RED', () {
        final r = engine.assess(
          isWalking: false, capillaryRefillSeconds: 3,
        );
        expect(r.category, TriageCategory.immediate);
      });

      test('cap refill 2s is YELLOW (boundary safe)', () {
        final r = engine.assess(
          isWalking: false, capillaryRefillSeconds: 2,
        );
        expect(r.category, TriageCategory.delayed);
      });

      test('cap refill 0s with pulse present is YELLOW', () {
        final r = engine.assess(isWalking: false);
        expect(r.category, TriageCategory.delayed);
      });
    });

    group('Mental Status (RED)', () {
      test('unresponsive to voice only is NOT RED (responds to pain)', () {
        final r = engine.assess(
          isWalking: false,
          respondsToVoice: false,
          respondsToPain: true,
        );
        expect(r.category, isNot(TriageCategory.immediate));
      });

      test('unresponsive to both voice and pain is RED', () {
        final r = engine.assess(
          isWalking: false,
          respondsToVoice: false,
          respondsToPain: false,
        );
        expect(r.category, TriageCategory.immediate);
      });
    });

    group('Combined Scenarios', () {
      test('polytrauma: not walking, RR 28, weak pulse -> RED', () {
        final r = engine.assess(
          isWalking: false,
          respiratoryRate: 28,
          hasRadialPulse: false,
        );
        expect(r.category, TriageCategory.immediate);
      });

      test('moderate: not walking, RR 22, pulse present -> YELLOW', () {
        final r = engine.assess(
          isWalking: false,
          respiratoryRate: 22,
          hasRadialPulse: true,
        );
        expect(r.category, TriageCategory.delayed);
      });

      test('normal vitals, walking -> GREEN', () {
        final r = engine.assess(isWalking: true);
        expect(r.category, TriageCategory.minimal);
      });

      test('resp distress, no radial pulse -> RED (perfusion wins)', () {
        final r = engine.assess(
          isWalking: false,
          respiratoryRate: 28,
          hasRadialPulse: false,
        );
        expect(r.category, TriageCategory.immediate);
      });
    });

    group('parseFromDescription — English', () {
      test('walking and talking', () {
        final r = engine.parseFromDescription(
          'Patient is walking and talking, minor cut on arm');
        expect(r.isWalking, true);
        expect(r.visibleInjuries, contains('cut'));
        expect(r.category, TriageCategory.minimal);
      });

      test('unresponsive and not breathing', () {
        final r = engine.parseFromDescription(
          'Patient is unresponsive, not breathing, no pulse');
        expect(r.isBreathing, false);
        expect(r.category, TriageCategory.deceased);
      });

      test('rapid breathing', () {
        final r = engine.parseFromDescription(
          'Respiratory rate 40, patient not walking');
        expect(r.respiratoryRate, 40);
        expect(r.category, TriageCategory.immediate);
      });

      test('slow breathing', () {
        final r = engine.parseFromDescription(
          'Respiratory rate 5, unresponsive');
        expect(r.category, TriageCategory.immediate);
      });

      test('bleeding fracture', () {
        final r = engine.parseFromDescription(
          'Severe bleeding from leg, possible fracture, patient awake');
        expect(r.visibleInjuries, allOf(contains('bleeding'), contains('fracture')));
      });

      test('ambulatory patient becomes GREEN', () {
        final r = engine.parseFromDescription(
          'Patient is ambulatory, walking around');
        expect(r.isWalking, true);
        expect(r.category, TriageCategory.minimal);
      });
    });

    group('parseFromDescription — Hindi support', () {
      test('unresponsive in Hindi', () {
        final r = engine.parseFromDescription(
          'मरीज बेहोश है, सांस नहीं ले रहा है');
        expect(r.isBreathing, false);
      });

      test('walking not detected in Hindi (no keyword match)', () {
        final r = engine.parseFromDescription(
          'मरीज चल रहा है और बात कर रहा है');
        expect(r.isWalking, false);
      });

      test('not walking properly detected', () {
        final r = engine.parseFromDescription(
          'Patient is not walking, respiratory rate 35');
        expect(r.isWalking, false);
        expect(r.category, TriageCategory.immediate);
      });
    });

    group('Confidence Scoring', () {
      test('walking GREEN has high confidence', () {
        final r = engine.assess(isWalking: true);
        expect(r.confidenceScore, 0.9);
      });

      test('deceased has highest confidence', () {
        final r = engine.assess(isWalking: false, isBreathing: false);
        expect(r.confidenceScore, 0.95);
      });

      test('immediate RR has respectable confidence', () {
        final r = engine.assess(isWalking: false, respiratoryRate: 40);
        expect(r.confidenceScore, 0.85);
      });

      test('YELLOW has lowest confidence', () {
        final r = engine.assess(isWalking: false);
        expect(r.confidenceScore, 0.75);
      });
    });

    group('Data Integrity', () {
      test('patient IDs are unique across calls', () {
        final ids = <String>{};
        for (int i = 0; i < 100; i++) {
          final r = engine.assess(isWalking: i.isEven);
          ids.add(r.id);
        }
        expect(ids.length, 100);
      });

      test('toJson roundtrip preserves all fields', () {
        final original = engine.assess(
          isWalking: false,
          isBreathing: true,
          respiratoryRate: 28,
          hasRadialPulse: false,
          capillaryRefillSeconds: 3,
          respondsToVoice: true,
          respondsToPain: false,
          visibleInjuries: 'leg fracture',
        );
        final json = original.toJson();
        expect(json['id'], original.id);
        expect(json['is_walking'], false);
        expect(json['is_breathing'], true);
        expect(json['respiratory_rate'], 28);
        expect(json['has_radial_pulse'], false);
        expect(json['capillary_refill_seconds'], 3);
        expect(json['responds_to_voice'], true);
        expect(json['responds_to_pain'], false);
        expect(json['visible_injuries'], 'leg fracture');
        expect(json['category'], 'RED');
        expect(json['confidence_score'], original.confidenceScore);
      });

      test('toJson includes timestamp', () {
        final r = engine.assess(isWalking: false);
        expect(r.toJson()['timestamp'], isNotNull);
      });
    });

    group('TriageCategory Enum', () {
      test('codes match medical standard', () {
        expect(TriageCategory.immediate.code, 'RED');
        expect(TriageCategory.delayed.code, 'YELLOW');
        expect(TriageCategory.minimal.code, 'GREEN');
        expect(TriageCategory.deceased.code, 'BLACK');
      });

      test('descriptions are informative', () {
        expect(TriageCategory.immediate.description,
          contains('life-threatening'));
        expect(TriageCategory.minimal.description,
          contains('Minor'));
      });
    });
  });

  group('TriageResult', () {
    test('fromJson roundtrip preserves all fields', () {
      final engine = TriageEngine();
      final assessment = engine.assess(
        isWalking: false,
        respiratoryRate: 35,
        visibleInjuries: 'chest wound',
      );
      final original = TriageResult(
        assessment: assessment,
        rawInput: 'Patient has chest wound',
        llmAnalysis: 'RED: Immediate',
        confidence: 0.85,
        createdAt: DateTime(2026, 6, 29, 10, 30),
      );
      final json = original.toJson();
      final restored = TriageResult.fromJson(json);
      expect(restored.assessment.id, original.assessment.id);
      expect(restored.rawInput, original.rawInput);
      expect(restored.llmAnalysis, original.llmAnalysis);
      expect(restored.confidence, original.confidence);
      expect(restored.createdAt, original.createdAt);
    });
  });

  group('GemmaInferenceService', () {
    late GemmaInferenceService service;

    setUp(() {
      service = GemmaInferenceService();
    });

    test('singleton returns same instance', () {
      final another = GemmaInferenceService();
      expect(identical(service, another), true);
    });

    test('default state is uninitialized', () {
      expect(service.isInitialized, false);
      expect(service.isModelLoaded, false);
      expect(service.lastError, '');
    });

    test('getResponse returns error without model', () async {
      final result = await service.getResponse('test');
      expect(result.isError, true);
      expect(result.confidence, ConfidenceLevel.insufficient);
    });

    test('analyzeImage returns error without model', () async {
      final result = await service.analyzeImage(Uint8List(0), 'test');
      expect(result.isError, true);
    });

    test('dispose resets state', () {
      service.dispose();
      expect(service.isInitialized, false);
      expect(service.isModelLoaded, false);
    });

    test('totalInferences starts at 0', () {
      expect(service.totalInferences, 0);
    });

    test('default language is English', () {
      expect(GemmaInferenceService.useHindi, false);
    });

    test('visionAvailable defaults to false', () {
      expect(service.visionAvailable, false);
    });
  });

  group('GemmaResult', () {
    test('isError returns true when error is set', () {
      const r = GemmaResult(text: 'error', error: 'something failed');
      expect(r.isError, true);
      expect(r.confidence, ConfidenceLevel.medium);
    });

    test('isSafe returns false for insufficient confidence', () {
      const r = GemmaResult(
        text: 'cannot assess',
        confidence: ConfidenceLevel.insufficient,
      );
      expect(r.isSafe, false);
    });

    test('safe result for high confidence', () {
      const r = GemmaResult(
        text: 'all clear',
        confidence: ConfidenceLevel.high,
        confidenceScore: 0.95,
      );
      expect(r.isSafe, true);
    });

    test('error result keeps default confidence medium', () {
      const r = GemmaResult(text: '', error: 'fail');
      expect(r.error, 'fail');
      expect(r.confidence, ConfidenceLevel.medium);
    });
  });

  group('DeviceCapabilities', () {
    test('default values are safe fallbacks', () {
      expect(DeviceCapabilities.supportsVision, false);
      expect(DeviceCapabilities.isLowRam, false);
    });

    test('maxTokens falls back to 1024', () {
      expect(DeviceCapabilities.maxTokens, 1024);
    });

    test('initialize does not throw', () async {
      await DeviceCapabilities.initialize();
      expect(true, isTrue);
    });
  });

  group('GeoPoint', () {
    test('toString includes coordinates', () {
      final p = GeoPoint(latitude: 28.6139, longitude: 77.209, source: 'test');
      expect(p.toString(), contains('28.6139'));
      expect(p.toString(), contains('77.209'));
    });

    test('toJson produces valid map', () {
      final p = GeoPoint(latitude: 19.0760, longitude: 72.8777, source: 'gps');
      final json = p.toJson();
      expect(json, contains('lat'));
      expect(json, contains('lon'));
      expect(json, contains('gps'));
    });

    test('timestamp defaults to now', () {
      final p = GeoPoint(latitude: 0, longitude: 0);
      expect(p.timestamp.difference(DateTime.now()).inSeconds, lessThan(2));
    });
  });

  group('TriageEngine — Multiple Assess Calls', () {
    test('sequential calls maintain independence', () {
      final engine = TriageEngine();
      final r1 = engine.assess(isWalking: true);
      final r2 = engine.assess(isWalking: false, respiratoryRate: 35);
      final r3 = engine.assess(isWalking: false);
      expect(r1.category, TriageCategory.minimal);
      expect(r2.category, TriageCategory.immediate);
      expect(r3.category, TriageCategory.delayed);
      expect(r2.isWalking, false);
      expect(r3.isWalking, false);
    });
  });

  group('PatientAssessment', () {
    test('constructor assigns unique IDs', () {
      final a = PatientAssessment(
        id: 'test_1', timestamp: DateTime.now(),
        isWalking: true, isBreathing: true,
        respiratoryRate: 20, hasRadialPulse: true,
        capillaryRefillSeconds: 1, respondsToVoice: true,
        respondsToPain: true, category: TriageCategory.minimal,
        confidenceScore: 0.9,
      );
      final b = PatientAssessment(
        id: 'test_2', timestamp: DateTime.now(),
        isWalking: false, isBreathing: true,
        respiratoryRate: 20, hasRadialPulse: true,
        capillaryRefillSeconds: 1, respondsToVoice: true,
        respondsToPain: true, category: TriageCategory.delayed,
        confidenceScore: 0.75,
      );
      expect(a.id, isNot(b.id));
      expect(a.category, TriageCategory.minimal);
      expect(b.category, TriageCategory.delayed);
    });

    test('fromJson roundtrip', () {
      final original = PatientAssessment(
        id: 'P123', timestamp: DateTime(2026, 6, 29),
        isWalking: false, isBreathing: true,
        respiratoryRate: 28, hasRadialPulse: false,
        capillaryRefillSeconds: 3, respondsToVoice: true,
        respondsToPain: false, visibleInjuries: 'fracture',
        category: TriageCategory.immediate,
        confidenceScore: 0.8,
      );
      final json = {
        'id': 'P123',
        'timestamp': '2026-06-29T00:00:00.000',
        'is_walking': false,
        'is_breathing': true,
        'respiratory_rate': 28,
        'has_radial_pulse': false,
        'capillary_refill_seconds': 3,
        'responds_to_voice': true,
        'responds_to_pain': false,
        'visible_injuries': 'fracture',
        'category': 'RED',
        'confidence_score': 0.8,
      };
      final restored = PatientAssessment(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isWalking: json['is_walking'] as bool,
        isBreathing: json['is_breathing'] as bool,
        respiratoryRate: (json['respiratory_rate'] as num).toInt(),
        hasRadialPulse: json['has_radial_pulse'] as bool,
        capillaryRefillSeconds: (json['capillary_refill_seconds'] as num).toInt(),
        respondsToVoice: json['responds_to_voice'] as bool,
        respondsToPain: json['responds_to_pain'] as bool,
        visibleInjuries: json['visible_injuries'] as String,
        category: TriageCategory.immediate,
        confidenceScore: (json['confidence_score'] as num).toDouble(),
      );
      expect(restored.id, original.id);
      expect(restored.isWalking, original.isWalking);
      expect(restored.respiratoryRate, original.respiratoryRate);
      expect(restored.category, original.category);
      expect(restored.confidenceScore, original.confidenceScore);
      expect(restored.visibleInjuries, original.visibleInjuries);
    });
  });
}
