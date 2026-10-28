import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/damage_survey.dart';

class DamageSurveyService {
  static const _storageKey = 'damage_surveys_v1';
  static final DamageSurveyService _instance = DamageSurveyService._internal();
  factory DamageSurveyService() => _instance;
  DamageSurveyService._internal();

  Future<List<DamageSurveyRecord>> getSurveys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => DamageSurveyRecord.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('[DamageSurveyService] getSurveys error: $e');
      return [];
    }
  }

  Future<void> saveSurvey(DamageSurveyRecord record) async {
    final surveys = await getSurveys();
    final idx = surveys.indexWhere((s) => s.id == record.id);
    if (idx >= 0) {
      surveys[idx] = record;
    } else {
      surveys.insert(0, record);
    }
    await _persist(surveys);
  }

  Future<void> deleteSurvey(String id) async {
    final surveys = await getSurveys();
    final removed = surveys.where((s) => s.id == id).toList();
    for (final r in removed) {
      if (r.imagePath.isNotEmpty) {
        final f = File(r.imagePath);
        if (f.existsSync()) {
          try { f.deleteSync(); } catch (_) {}
        }
      }
    }
    surveys.removeWhere((s) => s.id == id);
    await _persist(surveys);
  }

  Future<String> saveEvidenceImage(File imageFile, String surveyId) async {
    final dir = await getApplicationDocumentsDirectory();
    final surveyDir = Directory(p.join(dir.path, 'surveys'));
    if (!await surveyDir.exists()) {
      await surveyDir.create(recursive: true);
    }
    final ext = p.extension(imageFile.path);
    final targetPath = p.join(surveyDir.path, '${surveyId}_evidence$ext');
    final copied = await imageFile.copy(targetPath);
    return copied.path;
  }

  String exportToCsv(List<DamageSurveyRecord> surveys) {
    final buffer = StringBuffer();
    // CSV Header matching SDMA / State Revenue Survey formats
    buffer.writeln(
      'Survey_ID,Timestamp,Latitude,Longitude,Accuracy_Meters,Landmark_Village,House_ID,Beneficiary_Name,Structure_Type,Damage_Severity,Water_Mark_Meters,Habitable,Notes',
    );

    for (final s in surveys) {
      buffer.writeln(
        '"${s.id}",'
        '"${s.timestamp.toIso8601String()}",'
        '${s.latitude.toStringAsFixed(5)},'
        '${s.longitude.toStringAsFixed(5)},'
        '${s.accuracy.toStringAsFixed(1)},'
        '"${_escape(s.landmarkAndVillage)}",'
        '"${_escape(s.houseId)}",'
        '"${_escape(s.beneficiaryName)}",'
        '"${s.structureType.labelEn}",'
        '"${s.damageSeverity.labelEn}",'
        '${s.waterMarkMeters ?? 0.0},'
        '${s.isHabitable ? "YES" : "NO"},'
        '"${_escape(s.notes)}"',
      );
    }
    return buffer.toString();
  }

  String exportToJson(List<DamageSurveyRecord> surveys) {
    return const JsonEncoder.withIndent('  ')
        .convert(surveys.map((s) => s.toJson()).toList());
  }

  String _escape(String value) {
    var v = value.replaceAll('"', '""').replaceAll('\n', ' ').replaceAll('\r', ' ');
    // Neutralize CSV injection (formula injection) for spreadsheet safety.
    if (v.isNotEmpty && ('=+-@\t'.contains(v[0]))) {
      v = "'$v";
    }
    return v;
  }

  Future<void> _persist(List<DamageSurveyRecord> surveys) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(surveys.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
