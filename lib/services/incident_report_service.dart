import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

enum IncidentType {
  fire('Fire', 'आग', Icons.local_fire_department, AppTheme.red),
  collapsedBuilding('Collapsed Building', 'भवन ढह गया', Icons.architecture, AppTheme.saffronDark),
  flood('Flood', 'बाढ़', Icons.water, AppTheme.chakraBlue),
  earthquake('Earthquake', 'भूकंप', Icons.terrain, AppTheme.saffron),
  gasLeak('Gas Leak', 'गैस रिसाव', Icons.propane_tank, AppTheme.yellow),
  chemicalSpill('Chemical Spill', 'रासायनिक रिसाव', Icons.science, AppTheme.tealLight),
  powerOutage('Power Outage', 'बिजली कटौती', Icons.electrical_services, AppTheme.grey),
  roadBlockage('Road Blockage', 'सड़क अवरुद्ध', Icons.block, AppTheme.grey),
  other('Other', 'अन्य', Icons.report_problem, AppTheme.saffronLight);

  final String label;
  final String labelHindi;
  final IconData icon;
  final Color color;
  const IncidentType(this.label, this.labelHindi, this.icon, this.color);
}

class IncidentReport {
  final String id;
  final IncidentType type;
  final String description;
  final double? latitude;
  final double? longitude;
  final String? photoPath;
  final DateTime timestamp;
  final bool resolved;

  IncidentReport({
    required this.id,
    required this.type,
    required this.description,
    this.latitude,
    this.longitude,
    this.photoPath,
    DateTime? timestamp,
    this.resolved = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'photoPath': photoPath,
    'timestamp': timestamp.toIso8601String(),
    'resolved': resolved,
  };

  factory IncidentReport.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'other';
    return IncidentReport(
      id: json['id'] as String,
      type: IncidentType.values.firstWhere((e) => e.name == typeName, orElse: () => IncidentType.other),
      description: json['description'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      photoPath: json['photoPath'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
      resolved: json['resolved'] as bool? ?? false,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class IncidentReportService {
  static const _key = 'incident_reports';

  Future<List<IncidentReport>> getReports() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => IncidentReport.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> addReport(IncidentReport report) async {
    final reports = await getReports();
    reports.insert(0, report);
    await _save(reports);
  }

  Future<void> updateReport(String id, {bool? resolved}) async {
    final reports = await getReports();
    final idx = reports.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final old = reports[idx];
    reports[idx] = IncidentReport(
      id: old.id, type: old.type, description: old.description,
      latitude: old.latitude, longitude: old.longitude, photoPath: old.photoPath,
      timestamp: old.timestamp, resolved: resolved ?? old.resolved,
    );
    await _save(reports);
  }

  Future<void> deleteReport(String id) async {
    final reports = await getReports();
    reports.removeWhere((r) => r.id == id);
    await _save(reports);
  }

  Future<void> _save(List<IncidentReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(reports.map((r) => r.toJson()).toList()));
  }
}
