import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrackService {
  static const _key = 'gps_track_v1';
  static const _maxPoints = 600;

  Future<List<LatLng>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => LatLng(
                (e['lat'] as num).toDouble(),
                (e['lon'] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<LatLng> points) async {
    final trimmed = points.length > _maxPoints
        ? points.sublist(points.length - _maxPoints)
        : points;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(trimmed.map((p) => {'lat': p.latitude, 'lon': p.longitude}).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
