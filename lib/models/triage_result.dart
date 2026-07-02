import '../services/triage_engine.dart';

class TriageResult {
  final PatientAssessment assessment;
  final String rawInput;
  final String? llmAnalysis;
  final double confidence;
  final DateTime createdAt;

  const TriageResult({
    required this.assessment,
    required this.rawInput,
    this.llmAnalysis,
    required this.confidence,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': assessment.id,
        'timestamp': createdAt.toIso8601String(),
        'raw_input': rawInput,
        'llm_analysis': llmAnalysis,
        'confidence': confidence,
        'category': assessment.category.code,
        'category_label': assessment.category.description,
      };

  factory TriageResult.fromJson(Map<String, dynamic> json) {
    return TriageResult(
      assessment: PatientAssessment(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isWalking: json['is_walking'] == true,
        isBreathing: json['is_breathing'] == true,
        respiratoryRate: (json['respiratory_rate'] as num?)?.toInt() ?? 20,
        hasRadialPulse: json['has_radial_pulse'] == true,
        capillaryRefillSeconds: (json['capillary_refill_seconds'] as num?)?.toInt() ?? 1,
        respondsToVoice: json['responds_to_voice'] == true,
        respondsToPain: json['responds_to_pain'] == true,
        visibleInjuries: json['visible_injuries'] as String?,
        category: TriageCategory.values.firstWhere(
          (e) => e.code == json['category'],
          orElse: () => TriageCategory.minimal,
        ),
        confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      ),
      rawInput: json['raw_input'] as String? ?? '',
      llmAnalysis: json['llm_analysis'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['timestamp'] as String),
    );
  }
}
