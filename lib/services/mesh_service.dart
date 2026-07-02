import 'dart:convert';
import 'package:archive/archive.dart';
import 'triage_engine.dart';
import 'patient_repository.dart';

class MeshService {
  static final MeshService _instance = MeshService._internal();
  factory MeshService() => _instance;
  MeshService._internal();

  final PatientRepository _repo = PatientRepository();

  /// Max QR v40 binary payload capacity (~2953 bytes, with safety margin).
  static const int _maxQrBytes = 2800;

  /// Encodes all triaged patients into a compressed Base64 string for QR sync.
  /// Returns null if the payload exceeds QR capacity.
  Future<String?> generateSyncPayload() async {
    final patients = await _repo.getAllPatients();
    final jsonList = patients.map((p) => p.toJson()).toList();
    final jsonStr = json.encode(jsonList);

    final bytes = utf8.encode(jsonStr);
    final compressed = GZipEncoder().encode(bytes);
    final payload = base64.encode(compressed);

    if (payload.length > _maxQrBytes) return null;
    return payload;
  }

  /// Decodes a sync payload and merges it into the local database.
  Future<int> processSyncPayload(String payload) async {
    try {
      final compressed = base64.decode(payload);
      final bytes = GZipDecoder().decodeBytes(compressed);
      final jsonStr = utf8.decode(bytes);
      final List<dynamic> jsonList = json.decode(jsonStr);
      
      int importedCount = 0;
      final existingPatients = await _repo.getAllPatients();
      final existingIds = existingPatients.map((p) => p.id).toSet();

      for (var item in jsonList) {
        final id = item['id'];
        if (!existingIds.contains(id)) {
          final patient = PatientAssessment(
            id: item['id'] as String,
            timestamp: DateTime.parse(item['timestamp'] as String),
            isWalking: item['is_walking'] == true,
            isBreathing: item['is_breathing'] == true,
            respiratoryRate: (item['respiratory_rate'] as num).toInt(),
            hasRadialPulse: item['has_radial_pulse'] == true,
            capillaryRefillSeconds: (item['capillary_refill_seconds'] as num).toInt(),
            respondsToVoice: item['responds_to_voice'] == true,
            respondsToPain: item['responds_to_pain'] == true,
            visibleInjuries: item['visible_injuries'] as String?,
            category: _parseCategory(item['category'] as String),
            confidenceScore: (item['confidence_score'] as num?)?.toDouble() ?? 0.0,
          );
          await _repo.insertPatient(patient);
          importedCount++;
        }
      }
      return importedCount;
    } catch (e) {
      return -1;
    }
  }

  TriageCategory _parseCategory(String code) {
    return TriageCategory.values.firstWhere((e) => e.code == code.toUpperCase(), orElse: () => TriageCategory.minimal);
  }
}
