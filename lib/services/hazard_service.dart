import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/hazard_pin.dart';

class HazardService {
  static const _key = 'map_hazards_v1';

  Future<List<HazardPin>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => HazardPin.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<HazardPin> pins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(pins.map((p) => p.toJson()).toList()),
    );
  }

  Future<List<HazardPin>> add(HazardPin pin) async {
    final pins = await load();
    pins.add(pin);
    await save(pins);
    return pins;
  }

  Future<List<HazardPin>> remove(String id) async {
    final pins = await load();
    pins.removeWhere((p) => p.id == id);
    await save(pins);
    return pins;
  }
}
