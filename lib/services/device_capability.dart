import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class DeviceCapability {
  static final DeviceCapability _instance = DeviceCapability._internal();
  factory DeviceCapability() => _instance;
  DeviceCapability._internal();

  int _totalRamMb = 4096;
  bool _loaded = false;

  int get totalRamMb => _totalRamMb;
  bool get isLowRam => _totalRamMb <= 4096;
  bool get isVeryLowRam => _totalRamMb <= 3072;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getInt('device_ram_mb');
      if (cached != null && cached > 0) {
        _totalRamMb = cached;
        _loaded = true;
        return;
      }
    } catch (_) {}
    _totalRamMb = Platform.isAndroid ? 4096 : 8192;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('device_ram_mb', _totalRamMb);
    } catch (_) {}
  }

  Future<void> setTotalRamMb(int mb) async {
    _totalRamMb = mb;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('device_ram_mb', mb);
  }

  String recommendedTier() {
    if (_totalRamMb >= 6144) return 'full';
    if (_totalRamMb >= 4096) return 'small';
    return 'tiny';
  }
}
