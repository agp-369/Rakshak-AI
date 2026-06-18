import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_ai/services/gemma_service.dart';
import 'package:rakshak_ai/services/triage_engine.dart';
import 'package:rakshak_ai/services/gps_service.dart';

void main() {
  group('TriageEngine', () {
    late TriageEngine engine;

    setUp(() {
      engine = TriageEngine();
    });

    test('walking patient is GREEN/minimal', () {
      final result = engine.assess(isWalking: true);
      expect(result.category, TriageCategory.minimal);
      expect(result.isWalking, true);
    });

    test('not breathing patient is BLACK/deceased', () {
      final result = engine.assess(
        isWalking: false,
        isBreathing: false,
      );
      expect(result.category, TriageCategory.deceased);
    });

    test('respiratory rate > 30 is RED/immediate', () {
      final result = engine.assess(
        isWalking: false,
        respiratoryRate: 35,
      );
      expect(result.category, TriageCategory.immediate);
    });

    test('respiratory rate < 10 is RED/immediate', () {
      final result = engine.assess(
        isWalking: false,
        respiratoryRate: 6,
      );
      expect(result.category, TriageCategory.immediate);
    });

    test('absent radial pulse is RED/immediate', () {
      final result = engine.assess(
        isWalking: false,
        hasRadialPulse: false,
      );
      expect(result.category, TriageCategory.immediate);
    });

    test('capillary refill > 2s is RED/immediate', () {
      final result = engine.assess(
        isWalking: false,
        capillaryRefillSeconds: 4,
      );
      expect(result.category, TriageCategory.immediate);
    });

    test('unresponsive patient is RED/immediate', () {
      final result = engine.assess(
        isWalking: false,
        respondsToVoice: false,
        respondsToPain: false,
      );
      expect(result.category, TriageCategory.immediate);
    });

    test('stable non-walking patient is YELLOW/delayed', () {
      final result = engine.assess(isWalking: false);
      expect(result.category, TriageCategory.delayed);
    });

    test('parseFromDescription extracts walking', () {
      final result = engine.parseFromDescription(
          'Patient is walking and talking, minor cut on arm');
      expect(result.isWalking, true);
      expect(result.visibleInjuries, contains('cut'));
    });

    test('parseFromDescription detects unresponsive', () {
      final result = engine.parseFromDescription(
          'Patient is unresponsive, not breathing, no pulse');
      expect(result.isBreathing, false);
      expect(result.category, TriageCategory.deceased);
    });

    test('patient IDs are unique', () {
      final a = engine.assess(isWalking: true);
      final b = engine.assess(isWalking: false);
      expect(a.id, isNot(equals(b.id)));
    });

    test('toJson produces valid map', () {
      final result = engine.assess(isWalking: false);
      final json = result.toJson();
      expect(json['id'], result.id);
      expect(json['category'], result.category.code);
      expect(json['confidence'], result.confidenceScore);
    });
  });

  group('GemmaInferenceService', () {
    late GemmaInferenceService service;

    setUp(() {
      service = GemmaInferenceService();
    });

    test('singleton pattern works', () {
      final another = GemmaInferenceService();
      expect(identical(service, another), true);
    });

    test('not initialized by default', () {
      expect(service.isInitialized, false);
      expect(service.isModelLoaded, false);
    });

    test('getResponse returns error when not initialized', () async {
      final result = await service.getResponse('test');
      expect(result.isError, true);
      expect(result.confidence, ConfidenceLevel.insufficient);
    });

    test('analyzeImage returns error when not initialized', () async {
      final result = await service.analyzeImage(
        Uint8List(0),
        'test',
      );
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
  });

  group('GpsService', () {
    late GpsService gps;

    setUp(() {
      gps = GpsService();
    });

    test('singleton pattern', () {
      final another = GpsService();
      expect(identical(gps, another), true);
    });

    test('no location initially', () {
      expect(gps.hasLocation, false);
      expect(gps.lastKnown, isNull);
    });

    test('GeoPoint toString', () {
      final point = GeoPoint(
        latitude: 37.7749,
        longitude: -122.4194,
        source: 'test',
      );
      expect(point.toString(), contains('37.7749'));
      expect(point.toJson(), contains('37.7749'));
    });
  });
}
