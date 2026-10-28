import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/model_pack.dart';

class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double progress; // 0.0 to 1.0
  final bool isDownloading;
  final bool isCompleted;
  final String? error;

  const DownloadProgress({
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.progress = 0.0,
    this.isDownloading = false,
    this.isCompleted = false,
    this.error,
  });

  String get receivedMb => (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
  String get totalMb => totalBytes > 0
      ? (totalBytes / (1024 * 1024)).toStringAsFixed(1)
      : 'Unknown';
}

class DiscoveredModelFile {
  final String path;
  final String fileName;
  final int sizeBytes;
  final bool isInAppStorage;
  final bool isInDownloadFolder;
  final ModelTier? matchedTier;

  const DiscoveredModelFile({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.isInAppStorage,
    required this.isInDownloadFolder,
    this.matchedTier,
  });

  String get sizeMb => (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
}

class ModelDownloadService {
  static final ModelDownloadService _instance = ModelDownloadService._internal();
  factory ModelDownloadService() => _instance;
  ModelDownloadService._internal();

  final Map<ModelTier, StreamController<DownloadProgress>> _progressControllers = {};
  final Map<ModelTier, http.Client?> _activeClients = {};
  final Map<ModelTier, bool> _cancelFlags = {};

  Stream<DownloadProgress> progressStream(ModelTier tier) {
    if (!_progressControllers.containsKey(tier)) {
      _progressControllers[tier] = StreamController<DownloadProgress>.broadcast();
    }
    return _progressControllers[tier]!.stream;
  }

  /// Strict URL validation for model downloads: only http/https with a host.
  static bool _isValidDownloadUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return false;
      }
      if (uri.host.trim().isEmpty) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Directory> getAppModelsDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(docDir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// Scan both app storage and mobile storage Download directories
  Future<List<DiscoveredModelFile>> scanForModels() async {
    final list = <DiscoveredModelFile>[];
    final seenPaths = <String>{};

    final appDir = await getAppModelsDirectory();
    if (await appDir.exists()) {
      try {
        final files = appDir.listSync();
        for (final entity in files) {
          if (entity is File && _isModelExtension(entity.path)) {
            final len = entity.lengthSync();
            final name = p.basename(entity.path);
            list.add(DiscoveredModelFile(
              path: entity.path,
              fileName: name,
              sizeBytes: len,
              isInAppStorage: true,
              isInDownloadFolder: false,
              matchedTier: _matchTier(name),
            ));
            seenPaths.add(entity.path);
          }
        }
      } catch (e) {
        debugPrint('[ModelScan] app dir list error: $e');
      }
    }

    final downloadDirs = <String>[
      '/sdcard/Download',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
    ];

    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        downloadDirs.add(ext.path);
      }
    } catch (_) {}

    for (final dirPath in downloadDirs) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        try {
          final files = dir.listSync();
          for (final entity in files) {
            if (entity is File && _isModelExtension(entity.path)) {
              if (seenPaths.contains(entity.path)) continue;
              final len = entity.lengthSync();
              final name = p.basename(entity.path);
              list.add(DiscoveredModelFile(
                path: entity.path,
                fileName: name,
                sizeBytes: len,
                isInAppStorage: false,
                isInDownloadFolder: true,
                matchedTier: _matchTier(name),
              ));
              seenPaths.add(entity.path);
            }
          }
        } catch (_) {}
      }
    }

    return list;
  }

  bool _isModelExtension(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.litertlm') ||
        lower.endsWith('.bin') ||
        lower.endsWith('.task') ||
        lower.endsWith('.tflite');
  }

  ModelTier? _matchTier(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('270m')) return ModelTier.tiny;
    if (lower.contains('1b')) return ModelTier.small;
    if (lower.contains('e2b') || lower.contains('gemma-4')) return ModelTier.full;
    return null;
  }

  /// Check if a model file is present in app storage
  Future<File?> getInstalledFile(ModelTier tier) async {
    final appDir = await getAppModelsDirectory();
    final f = File(p.join(appDir.path, tier.modelFile));
    if (await f.exists() && (await f.length()) > 1048576) {
      return f;
    }
    return null;
  }

  /// Check if a model file is detected in mobile Download folder
  Future<File?> getDownloadFolderFile(ModelTier tier) async {
    final candidates = [
      '/sdcard/Download/${tier.modelFile}',
      '/storage/emulated/0/Download/${tier.modelFile}',
      '/storage/emulated/0/Downloads/${tier.modelFile}',
    ];
    for (final c in candidates) {
      final f = File(c);
      if (await f.exists() && (await f.length()) > 1048576) {
        return f;
      }
    }
    return null;
  }

  /// Import/copy a file from Download folder into app storage
  Future<File> importFromDownloads(ModelTier tier, {void Function(double)? onProgress}) async {
    final src = await getDownloadFolderFile(tier);
    if (src == null) {
      throw StateError('File not found in Download folder');
    }

    final appDir = await getAppModelsDirectory();
    final dest = File(p.join(appDir.path, tier.modelFile));

    final totalBytes = await src.length();
    var copiedBytes = 0;

    final reader = src.openRead();
    final sink = dest.openWrite();

    await for (final chunk in reader) {
      sink.add(chunk);
      copiedBytes += chunk.length;
      if (totalBytes > 0 && onProgress != null) {
        onProgress(copiedBytes / totalBytes);
      }
    }
    await sink.flush();
    await sink.close();

    return dest;
  }

  /// Download model file from URL with chunked streaming and cancellation
  Future<File> downloadModel(
    ModelTier tier, {
    String? urlOverride,
    String? authToken,
  }) async {
    final resolvedUrl = (urlOverride != null && urlOverride.trim().isNotEmpty)
        ? urlOverride.trim()
        : tier.defaultDownloadUrl;
    if (!_isValidDownloadUrl(resolvedUrl)) {
      throw ArgumentError('Download URL must be a valid http(s) URL');
    }
    final urlStr = resolvedUrl;
    final uri = Uri.parse(urlStr);

    final appDir = await getAppModelsDirectory();
    final targetFile = File(p.join(appDir.path, tier.modelFile));
    final tempFile = File(p.join(appDir.path, '${tier.modelFile}.download'));

    if (!_progressControllers.containsKey(tier)) {
      _progressControllers[tier] = StreamController<DownloadProgress>.broadcast();
    }
    final controller = _progressControllers[tier]!;

    _cancelFlags[tier] = false;
    final client = http.Client();
    _activeClients[tier] = client;

    try {
      final request = http.Request('GET', uri);
      if (authToken != null && authToken.trim().isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${authToken.trim()}';
      }

      final response = await client.send(request);
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException(
          'Server returned HTTP ${response.statusCode}: ${response.reasonPhrase}',
          uri: uri,
        );
      }

      final totalBytes = response.contentLength ?? (tier.sizeMb * 1024 * 1024);
      var receivedBytes = 0;

      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      final sink = tempFile.openWrite();

      controller.add(DownloadProgress(
        receivedBytes: 0,
        totalBytes: totalBytes,
        progress: 0.0,
        isDownloading: true,
      ));

      await for (final chunk in response.stream) {
        if (_cancelFlags[tier] == true) {
          await sink.close();
          if (await tempFile.exists()) await tempFile.delete();
          throw StateError('Download cancelled by user');
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        final prog = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
        controller.add(DownloadProgress(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          progress: prog,
          isDownloading: true,
        ));
      }

      await sink.flush();
      await sink.close();

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);

      controller.add(DownloadProgress(
        receivedBytes: receivedBytes,
        totalBytes: receivedBytes,
        progress: 1.0,
        isDownloading: false,
        isCompleted: true,
      ));

      return targetFile;
    } catch (e) {
      if (await tempFile.exists()) {
        try { await tempFile.delete(); } catch (_) {}
      }
      controller.add(DownloadProgress(
        isDownloading: false,
        error: e.toString(),
      ));
      rethrow;
    } finally {
      client.close();
      _activeClients[tier] = null;
    }
  }

  void cancelDownload(ModelTier tier) {
    _cancelFlags[tier] = true;
    _activeClients[tier]?.close();
    _activeClients[tier] = null;
  }

  Future<void> deleteModel(ModelTier tier) async {
    final f = await getInstalledFile(tier);
    if (f != null && await f.exists()) {
      await f.delete();
    }
  }
}
