import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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
    return TriageCategory.values.firstWhere((e) => e.code == code, orElse: () => TriageCategory.minimal);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('patients');
  }
}
