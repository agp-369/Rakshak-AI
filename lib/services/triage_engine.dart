import 'dart:math';

/// START Triage categories
enum TriageCategory {
  immediate('RED', 'Immediate life-threatening, treat first'),
  delayed('YELLOW', 'Serious but stable, can wait short period'),
  minimal('GREEN', 'Minor injuries, walking wounded'),
  deceased('BLACK', 'Deceased or unsurvivable injuries');

  final String code;
  final String description;
  const TriageCategory(this.code, this.description);
}

/// Patient assessment record
class PatientAssessment {
  final String id;
  final DateTime timestamp;
  final bool isWalking;
  final bool isBreathing;
  final int respiratoryRate;
  final bool hasRadialPulse;
  final int capillaryRefillSeconds;
  final bool respondsToVoice;
  final bool respondsToPain;
  final String? visibleInjuries;
  final TriageCategory category;
  final double confidenceScore;

  const PatientAssessment({
    required this.id,
    required this.timestamp,
    required this.isWalking,
    required this.isBreathing,
    required this.respiratoryRate,
    required this.hasRadialPulse,
    required this.capillaryRefillSeconds,
    required this.respondsToVoice,
    required this.respondsToPain,
    this.visibleInjuries,
    required this.category,
    required this.confidenceScore,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'is_walking': isWalking,
        'is_breathing': isBreathing,
        'respiratory_rate': respiratoryRate,
        'has_radial_pulse': hasRadialPulse,
        'capillary_refill_seconds': capillaryRefillSeconds,
        'responds_to_voice': respondsToVoice,
        'responds_to_pain': respondsToPain,
        'visible_injuries': visibleInjuries,
        'category': category.code,
        'confidence_score': confidenceScore,
      };
}

/// Medical triage engine implementing START protocol.
///
/// Simple Triage and Rapid Treatment (START) is used by first responders
/// to quickly categorize patients in mass casualty incidents.
class TriageEngine {
  int _patientCounter = 0;

  String get _nextId =>
      'P${DateTime.now().millisecondsSinceEpoch}_${++_patientCounter}';

  /// Perform START triage based on assessment parameters.
  ///
  /// The algorithm follows this decision tree:
  /// 1. Walking? → GREEN (Minimal)
  /// 2. Breathing? → Open airway
  /// 3. Respiratory rate >30 or <10? → RED (Immediate)
  /// 4. Radial pulse absent or cap refill >2s? → RED (Immediate)
  /// 5. Can't follow commands? → RED (Immediate)
  /// 6. Otherwise → YELLOW (Delayed)
  PatientAssessment assess({
    required bool isWalking,
    bool isBreathing = true,
    int respiratoryRate = 20,
    bool hasRadialPulse = true,
    int capillaryRefillSeconds = 1,
    bool respondsToVoice = true,
    bool respondsToPain = true,
    String? visibleInjuries,
  }) {
    double confidence = 1.0;
    TriageCategory category;

    // START Algorithm
    // Step 1: Walking wounded
    if (isWalking) {
      category = TriageCategory.minimal;
      confidence = 0.9;
    }
    // Step 2: Check breathing
    else if (!isBreathing) {
      category = TriageCategory.deceased;
      confidence = 0.95;
    }
    // Step 3: Check respiratory rate
    else if (respiratoryRate > 30 || respiratoryRate < 10) {
      category = TriageCategory.immediate;
      confidence = 0.85;
    }
    // Step 4: Check perfusion (radial pulse or capillary refill)
    else if (!hasRadialPulse || capillaryRefillSeconds > 2) {
      category = TriageCategory.immediate;
      confidence = 0.8;
    }
    // Step 5: Check mental status
    else if (!respondsToVoice && !respondsToPain) {
      category = TriageCategory.immediate;
      confidence = 0.85;
    }
    // Step 6: Otherwise delayed
    else {
      category = TriageCategory.delayed;
      confidence = 0.75;
    }

    return PatientAssessment(
      id: _nextId,
      timestamp: DateTime.now(),
      isWalking: isWalking,
      isBreathing: isBreathing,
      respiratoryRate: respiratoryRate,
      hasRadialPulse: hasRadialPulse,
      capillaryRefillSeconds: capillaryRefillSeconds,
      respondsToVoice: respondsToVoice,
      respondsToPain: respondsToPain,
      visibleInjuries: visibleInjuries,
      category: category,
      confidenceScore: confidence,
    );
  }

  /// Parse natural language assessment into structured triage.
  /// Uses regex patterns to extract key indicators from text.
  PatientAssessment parseFromDescription(String description) {
    final lower = description.toLowerCase();

    return assess(
      isWalking: lower.contains('walking') || lower.contains('ambulatory'),
      isBreathing: !lower.contains('not breathing') &&
          !lower.contains('no breathing'),
      respiratoryRate: _extractNumber(lower, 'respiratory'),
      hasRadialPulse: !lower.contains('no pulse') &&
          !lower.contains('absent pulse'),
      capillaryRefillSeconds: _extractNumber(lower, 'capillary'),
      respondsToVoice: !lower.contains('unresponsive') &&
          !lower.contains('no response'),
      respondsToPain: !lower.contains('no pain response'),
      visibleInjuries: _extractInjuries(description),
    );
  }

  int _extractNumber(String text, String keyword) {
    final idx = text.indexOf(keyword);
    if (idx == -1) return 20;
    final around = text.substring(
        max(0, idx - 10), min(text.length, idx + 20));
    final match = RegExp(r'(\d+)').firstMatch(around);
    if (match != null) return int.tryParse(match.group(1)!) ?? 20;
    return 20;
  }

  String? _extractInjuries(String text) {
    final keywords = ['bleeding', 'fracture', 'burn', 'wound', 'laceration', 'cut'];
    final found = keywords.where((k) => text.contains(k)).toList();
    return found.isNotEmpty ? found.join(', ') : null;
  }
}
