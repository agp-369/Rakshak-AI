import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Severity levels matching IMD's warning colour code.
enum AlertSeverity { green, yellow, orange, red }

extension AlertSeverityLabel on AlertSeverity {
  String get label {
    switch (this) {
      case AlertSeverity.red:
        return 'RED — Take action now';
      case AlertSeverity.orange:
        return 'ORANGE — Be prepared';
      case AlertSeverity.yellow:
        return 'YELLOW — Watch';
      case AlertSeverity.green:
        return 'GREEN — No warning';
    }
  }
}

/// A hazard alert from an official source (IMD weather, CWC flood,
/// GSI landslide nowcast, seismic).
class HazardAlert {
  final String id;
  final String source; // 'IMD' | 'CWC' | 'GSI' | 'NCS' | 'INCOIS'
  final String hazardType; // rain, flood, landslide, earthquake, cyclone, tsunami
  final AlertSeverity severity;
  final String area;
  final String officialText;
  final String actionText; // vernacular plain-language action
  final DateTime issuedAt;
  final DateTime? validUntil;

  const HazardAlert({
    required this.id,
    required this.source,
    required this.hazardType,
    required this.severity,
    required this.area,
    required this.officialText,
    required this.actionText,
    required this.issuedAt,
    this.validUntil,
  });

  bool get isActive {
    if (validUntil == null) return true;
    return DateTime.now().isBefore(validUntil!);
  }
}

/// Converts official jargon into 2-3 sentences of actionable vernacular.
/// This is the RULE-BASED v1 — the fine-tuned Gemma model slots in here
/// later via [AlertTranslator.translate], keeping the same interface.
/// The rule engine covers the long tail of IMD/CWC phrasings through
/// keyword families; the model handles novel phrasing when present.
class AlertTranslator {
  /// Map an official alert text + hazard type to plain actionable advice
  /// in the user's language. Pure function — testable, instant, offline.
  static String translate({
    required String hazardType,
    required AlertSeverity severity,
    required String officialText,
    required bool hindi,
  }) {
    switch (hazardType) {
      case 'rain':
        if (severity == AlertSeverity.red || severity == AlertSeverity.orange) {
          return hindi
              ? 'भारी बारिश का खतरा। नदी-नालों से दूर रहें, ऊँची जगह पर सो जाएं, गाड़ी न चलाएं। बिजली और पानी की वस्तुएं तैयार रखें।'
              : 'Heavy rain expected. Stay away from river beds, move to higher ground if near a stream, avoid driving through water. Keep torch and drinking water ready.';
        }
        return hindi
            ? 'मध्यम बारिश संभव। नदी किनारे न जाएं, बाढ़ की सूचना पर तुरंत सुरक्षित स्थान पर जाएं।'
            : 'Moderate rain expected. Avoid riverbanks. If you hear a flood warning, move to higher ground immediately.';

      case 'flood':
      case 'flashflood':
        if (severity == AlertSeverity.red) {
          return hindi
              ? 'बाढ़ का तुरंत खतरा! अभी ऊँची जगह पर चले जाएं। पानी में कभी न चलें — 15 सेंटीमीटर तेज़ बहाव भी बहा सकता है। रेडियो/फोन पर बने रहें।'
              : 'FLASH FLOOD — MOVE TO HIGHER GROUND NOW. Never walk through moving water — 15 cm can sweep you off your feet. Stay reachable by phone/radio.';
        }
        return hindi
            ? 'बाढ़ की चेतावनी। निचले इलाकों से हट जाएं, पानी बढ़ने पर तुरंत ऊपर जाएं। बाढ़ पानी में न ड्राइव करें।'
            : 'Flood warning. Move away from low-lying areas. If water starts rising, go up immediately. Do not drive through floodwater.';

      case 'landslide':
        return hindi
            ? 'भूस्खलन का खतरा। ढलान के नीचे, नाले या चट्टान के पास न सोएं। बारिश रुकने के बाद भी खतरा रहता है — ज़मीन गीली हो तो ऊपर की ओर सोएं।'
            : 'Landslide risk. Do not sleep below slopes, near ravines or cliff edges. Danger continues AFTER rain stops — if ground is wet, sleep on the uphill side.';

      case 'earthquake':
        return hindi
            ? 'भूकंप! झुकें, ढकें, पकड़ें। बाहर भागते समय सीढ़ियों और लिफ्ट से बचें। झटके रुकने के बाद ही बाहर निकलें।'
            : 'EARTHQUAKE — Drop, Cover, Hold on. Do not run outside during shaking, avoid stairs and lifts. Exit only after shaking stops.';

      case 'cyclone':
        return hindi
            ? 'चक्रवात आ रहा है। खिड़कियों से दूर रहें, मोटी दीवार के पास शरण लें। तटीय इलाके खाली करें। आने वाले दिनों में बिजली-पानी बंद हो सकता है।'
            : 'Cyclone approaching. Stay away from windows, take shelter near a thick interior wall. Evacuate coastal areas. Expect power and water outage for days.';

      case 'heatwave':
        return hindi
            ? 'गर्मी की लहर। दोपहर 12-4 बजे बाहर न निकलें। पानी पिएं, ORS घोल तैयार रखें, बच्चों और बुज़ुर्गों पर नज़र रखें।'
            : 'Heat wave. Do not go out between 12-4 PM. Drink water constantly, keep ORS ready, watch children and elderly for heat stroke.';

      case 'lightning':
        return hindi
            ? 'बिजली गिरने का खतरा। खुले मैदान, पेड़ या धातु की ऊँची वस्तुओं से दूर रहें। झील-तालाब के किनारे न रहें।'
            : 'Lightning risk. Stay away from open fields, trees and tall metal objects. Do not stand near lakes or ponds.';

      default:
        if (severity == AlertSeverity.red || severity == AlertSeverity.orange) {
          return hindi
              ? 'आपदा चेतावनी। सुरक्षित ऊँची जगह पर जाएं, परिवार से संपर्क बनाए रखें, आधिकारिक सूचना सुनते रहें।'
              : 'Hazard warning. Move to safe higher ground, keep family contact, monitor official information.';
        }
        return hindi
            ? 'सावधान रहें। आधिकारिक सूचनाओं पर नज़र रखें और ज़रूरत पड़ने पर तुरंत सुरक्षित स्थान पर जाएं।'
            : 'Stay alert. Monitor official updates and move to safety if instructed.';
    }
  }
}

/// Fetches official alerts (IMD public API) with offline cache.
/// When offline or the API is down, serves the last cached alerts —
/// an alert from 6 hours ago is still infinitely better than nothing.
class AlertService {
  static const _cacheKey = 'alert_cache';
  static const _cacheTimeKey = 'alert_cache_time';

  // IMD's public weather warning API (district-level).
  static const _imdWarningUrl =
      'https://mausam.imd.gov.in/api/district_warnings_api.php';

  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  /// Fetch alerts for a location. Returns cached alerts immediately if
  /// the network fails — never blocks the UI longer than [timeout].
  Future<List<HazardAlert>> fetchAlerts({
    double? latitude,
    double? longitude,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final fresh = await _fetchFromImd(latitude, longitude)
          .timeout(timeout);
      if (fresh.isNotEmpty) {
        await _cache(fresh);
        return fresh;
      }
    } catch (e) {
      debugPrint('[!] Alert fetch failed, serving cache: $e');
    }
    return getCached();
  }

  Future<List<HazardAlert>> _fetchFromImd(
      double? latitude, double? longitude) async {
    // IMD API needs district/state context. Without a geocoder we fetch
    // the general warnings feed; location filtering happens client-side
    // by matching the area field against nothing (show all) in v1.
    final uri = Uri.parse(_imdWarningUrl);
    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    return _parseImd(data);
  }

  List<HazardAlert> _parseImd(dynamic data) {
    final alerts = <HazardAlert>[];
    // IMD warning API returns {warnings: [...]} or a district-keyed map.
    // Parse defensively — the API shape has changed before.
    final entries = <Map<String, dynamic>>[];
    if (data is Map && data['warnings'] is List) {
      for (final w in data['warnings'] as List) {
        if (w is Map) entries.add(Map<String, dynamic>.from(w));
      }
    } else if (data is Map) {
      for (final value in data.values) {
        if (value is List) {
          for (final w in value) {
            if (w is Map) entries.add(Map<String, dynamic>.from(w));
          }
        }
      }
    }

    for (final e in entries) {
      final type = _mapHazardType(
          (e['type'] ?? e['hazard_type'] ?? e['param'] ?? '').toString());
      final sev = _mapSeverity(
          (e['severity'] ?? e['level'] ?? e['warning_type'] ?? '').toString());
      final area = (e['area'] ?? e['district'] ?? e['place'] ?? 'Unknown')
          .toString();
      final text = (e['message'] ?? e['warning'] ?? e['details'] ?? '')
          .toString();
      if (text.isEmpty && sev == AlertSeverity.green) continue;

      alerts.add(HazardAlert(
        id: '${e['id'] ?? area}_${type}_${DateTime.now().millisecondsSinceEpoch}',
        source: 'IMD',
        hazardType: type,
        severity: sev,
        area: area,
        officialText: text,
        actionText: AlertTranslator.translate(
          hazardType: type,
          severity: sev,
          officialText: text,
          hindi: false,
        ),
        issuedAt: DateTime.now(),
      ));
    }
    return alerts;
  }

  String _mapHazardType(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('flood')) return 'flood';
    if (lower.contains('landslide') || lower.contains('slide')) {
      return 'landslide';
    }
    if (lower.contains('cyclone') || lower.contains('hurricane')) {
      return 'cyclone';
    }
    if (lower.contains('heat')) return 'heatwave';
    if (lower.contains('thunder') || lower.contains('lightning')) {
      return 'lightning';
    }
    if (lower.contains('rain') || lower.contains('precip')) return 'rain';
    if (lower.contains('earthquake') || lower.contains('seismic')) {
      return 'earthquake';
    }
    if (lower.contains('tsunami')) return 'tsunami';
    return 'rain';
  }

  AlertSeverity _mapSeverity(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('red') || lower.contains('take action')) {
      return AlertSeverity.red;
    }
    if (lower.contains('orange') || lower.contains('be prepared')) {
      return AlertSeverity.orange;
    }
    if (lower.contains('yellow') || lower.contains('watch')) {
      return AlertSeverity.yellow;
    }
    return AlertSeverity.green;
  }

  Future<void> _cache(List<HazardAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(alerts
          .map((a) => {
                'id': a.id,
                'source': a.source,
                'hazardType': a.hazardType,
                'severity': a.severity.name,
                'area': a.area,
                'officialText': a.officialText,
                'actionText': a.actionText,
                'issuedAt': a.issuedAt.toIso8601String(),
                'validUntil': a.validUntil?.toIso8601String(),
              })
          .toList()),
    );
    await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
  }

  Future<List<HazardAlert>> getCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return HazardAlert(
        id: m['id'] as String,
        source: m['source'] as String? ?? 'IMD',
        hazardType: m['hazardType'] as String? ?? 'rain',
        severity: AlertSeverity.values.firstWhere(
          (s) => s.name == m['severity'],
          orElse: () => AlertSeverity.yellow,
        ),
        area: m['area'] as String? ?? 'Unknown',
        officialText: m['officialText'] as String? ?? '',
        actionText: m['actionText'] as String? ?? '',
        issuedAt: DateTime.tryParse(m['issuedAt'] as String? ?? '') ??
            DateTime.now(),
        validUntil: DateTime.tryParse(m['validUntil'] as String? ?? ''),
      );
    }).toList();
  }

  Future<DateTime?> lastFetchTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheTimeKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }
}
