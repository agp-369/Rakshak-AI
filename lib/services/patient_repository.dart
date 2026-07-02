import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'triage_engine.dart';

class PatientRepository {
  static final PatientRepository _instance = PatientRepository._internal();
  factory PatientRepository() => _instance;
  PatientRepository._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'patients.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE patients(
            id TEXT PRIMARY KEY,
            timestamp TEXT,
            is_walking INTEGER,
            is_breathing INTEGER,
            respiratory_rate INTEGER,
            has_radial_pulse INTEGER,
            capillary_refill_seconds INTEGER,
            responds_to_voice INTEGER,
            responds_to_pain INTEGER,
            visible_injuries TEXT,
            category TEXT,
            confidence_score REAL
          )
        ''');
      },
    );
  }

  Future<void> insertPatient(PatientAssessment patient) async {
    final db = await database;
    await db.insert(
      'patients',
      patient.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PatientAssessment>> getAllPatients() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('patients', orderBy: 'timestamp DESC');

    return List.generate(maps.length, (i) {
      return PatientAssessment(
        id: maps[i]['id'],
        timestamp: DateTime.parse(maps[i]['timestamp']),
        isWalking: maps[i]['is_walking'] == 1,
        isBreathing: maps[i]['is_breathing'] == 1,
        respiratoryRate: maps[i]['respiratory_rate'],
        hasRadialPulse: maps[i]['has_radial_pulse'] == 1,
        capillaryRefillSeconds: maps[i]['capillary_refill_seconds'],
        respondsToVoice: maps[i]['responds_to_voice'] == 1,
        respondsToPain: maps[i]['responds_to_pain'] == 1,
        visibleInjuries: maps[i]['visible_injuries'],
        category: _parseCategory(maps[i]['category']),
        confidenceScore: maps[i]['confidence_score'],
      );
    });
  }

  TriageCategory _parseCategory(String code) {
    return TriageCategory.values.firstWhere((e) => e.code == code.toUpperCase(), orElse: () => TriageCategory.minimal);
  }

  Future<void> deletePatient(String id) async {
    final db = await database;
    await db.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePatient(PatientAssessment patient) async {
    final db = await database;
    await db.update(
      'patients',
      patient.toJson(),
      where: 'id = ?',
      whereArgs: [patient.id],
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('patients');
  }

  Future<String> exportToJson() async {
    final patients = await getAllPatients();
    final data = {
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'Rakshak AI',
      'version': '1.0.0',
      'total_patients': patients.length,
      'patients': patients.map((p) => p.toJson()).toList(),
    };
    final dir = await getApplicationDocumentsDirectory();
    final file = File(join(dir.path, 'rakshak_patients_export_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  Future<int> importFromJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final list = data['patients'] as List;
      int count = 0;
      for (final item in list) {
        final assessment = PatientAssessment(
          id: item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.tryParse(item['timestamp'] ?? '') ?? DateTime.now(),
          isWalking: item['is_walking'] == true || item['is_walking'] == 1,
          isBreathing: item['is_breathing'] == true || item['is_breathing'] == 1,
          respiratoryRate: (item['respiratory_rate'] ?? 20) as int,
          hasRadialPulse: item['has_radial_pulse'] == true || item['has_radial_pulse'] == 1,
          capillaryRefillSeconds: (item['capillary_refill_seconds'] ?? 2) as int,
          respondsToVoice: item['responds_to_voice'] == true || item['responds_to_voice'] == 1,
          respondsToPain: item['responds_to_pain'] == true || item['responds_to_pain'] == 1,
          visibleInjuries: item['visible_injuries'] as String?,
          category: _parseCategory(item['category'] as String? ?? 'MIN'),
          confidenceScore: (item['confidence_score'] ?? 0.5) as double,
        );
        await insertPatient(assessment);
        count++;
      }
      return count;
    } catch (e) {
      return -1;
    }
  }
}
