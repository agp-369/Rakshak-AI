import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/map_pack.dart';

class MapPackService {
  static final MapPackService _instance = MapPackService._internal();
  factory MapPackService() => _instance;
  MapPackService._internal();

  static const _activePackKey = 'active_map_pack_id';

  Future<Directory> get _mapsDir async {
    final dir = await getApplicationDocumentsDirectory();
    final mapsDir = Directory(p.join(dir.path, 'maps'));
    if (!await mapsDir.exists()) {
      await mapsDir.create(recursive: true);
    }
    return mapsDir;
  }

  Future<List<MapPack>> availablePacks() async {
    final mapsDir = await _mapsDir;
    final manifestFile = File(p.join(mapsDir.path, 'packs.json'));
    if (!await manifestFile.exists()) {
      final bundled = MapPack(
        id: 'dehradun-pilot',
        name: 'Dehradun Pilot',
        fileName: 'dehradun_pilot.mbtiles',
        region: 'Dehradun, Uttarakhand',
        bounds: '77.96,30.25,78.12,30.37',
        minZoom: 12,
        maxZoom: 15,
        attribution: '(c) OpenStreetMap contributors, ODbL 1.0',
        license: 'ODbL 1.0',
        sizeBytes: await _fileSize(p.join('assets', 'maps', 'dehradun_pilot.mbtiles')),
      );
      return [bundled];
    }
    try {
      final content = await manifestFile.readAsString();
      final list = jsonDecode(content) as List;
      final packs = list.map((e) => MapPack.fromJson(e as Map<String, dynamic>)).toList();
      for (final pack in packs) {
        final f = File(p.join(mapsDir.path, pack.fileName));
        if (await f.exists()) {
          // sizeBytes not persisted in all cases; leave as-is
        }
      }
      return packs;
    } catch (e) {
      debugPrint('[MapPackService] manifest parse error: $e');
      return [];
    }
  }

  Future<String?> getActivePackId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activePackKey);
  }

  Future<void> setActivePackId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activePackKey);
    } else {
      await prefs.setString(_activePackKey, id);
    }
  }

  Future<String?> resolvePathForPack(MapPack pack) async {
    final mapsDir = await _mapsDir;
    final localFile = File(p.join(mapsDir.path, pack.fileName));
    if (await localFile.exists()) {
      return localFile.path;
    }

    // If not local, check if it's a bundled asset and copy it over.
    final assetPath = p.join('assets', 'maps', pack.fileName);
    if (await rootBundle.loadString(assetPath, cache: false).then((_) => true).catchError((_) => false)) {
      try {
        final byteData = await rootBundle.load(assetPath);
        final buffer = byteData.buffer;
        await localFile.writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
        debugPrint('[MapPackService] Copied bundled map pack ${pack.fileName} to ${localFile.path}');
        return localFile.path;
      } catch (e) {
        debugPrint('[MapPackService] Error copying bundled map pack: $e');
        return null;
      }
    }
    return null;
  }

  Future<int?> _fileSize(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) {
        return await f.length();
      }
    } catch (_) {}
    return null;
  }
}
