import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/model_pack.dart';
import '../../services/ai_engine.dart';
import '../../services/device_capability.dart';
import '../../services/localization.dart';
import '../../services/model_download_service.dart';
import '../../theme/app_theme.dart';

class AiPackManagerScreen extends StatefulWidget {
  const AiPackManagerScreen({super.key});

  @override
  State<AiPackManagerScreen> createState() => _AiPackManagerScreenState();
}

class _AiPackManagerScreenState extends State<AiPackManagerScreen> {
  final _cap = DeviceCapability();
  final _engine = AiEngine();
  final _downloadService = ModelDownloadService();

  String _recommended = 'small';
  bool _loading = true;
  String? _busyTierId;
  String? _busyMessage;

  final Map<ModelTier, File?> _installedFiles = {};
  final Map<ModelTier, File?> _downloadFolderFiles = {};
  final Map<ModelTier, DownloadProgress> _downloadProgress = {};
  final Map<ModelTier, StreamSubscription> _downloadSubs = {};
  List<DiscoveredModelFile> _discoveredModels = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    for (final sub in _downloadSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _cap.load();
    _recommended = _cap.recommendedTier();

    // Scan files for all tiers
    for (final tier in ModelTier.values) {
      _installedFiles[tier] = await _downloadService.getInstalledFile(tier);
      _downloadFolderFiles[tier] = await _downloadService.getDownloadFolderFile(tier);

      // Setup download progress stream listener
      if (!_downloadSubs.containsKey(tier)) {
        _downloadSubs[tier] = _downloadService.progressStream(tier).listen((p) {
          if (mounted) {
            setState(() {
              _downloadProgress[tier] = p;
              if (p.isCompleted) {
                _busyTierId = null;
                _busyMessage = null;
                _refreshFilesOnly();
              }
            });
          }
        });
      }
    }

    _discoveredModels = await _downloadService.scanForModels();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshFilesOnly() async {
    for (final tier in ModelTier.values) {
      _installedFiles[tier] = await _downloadService.getInstalledFile(tier);
      _downloadFolderFiles[tier] = await _downloadService.getDownloadFolderFile(tier);
    }
    _discoveredModels = await _downloadService.scanForModels();
    if (mounted) setState(() {});
  }

  Future<void> _loadModel(ModelTier tier, {String? customPath}) async {
    final hi = AppLang.hindi;
    setState(() {
      _busyTierId = tier.id;
      _busyMessage = hi ? 'मॉडल RAM में लोड हो रहा है…' : 'Loading model into RAM…';
    });

    try {
      await _engine.loadModelTier(tier, customPath: customPath);
      await _refreshFilesOnly();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hi
                  ? '${tier.displayNameHi} सफलतापूर्वक लोड हुआ!'
                  : '${tier.displayNameEn} loaded successfully into RAM!',
            ),
            backgroundColor: AppTheme.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Load failed: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyTierId = null;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _unloadModel() async {
    final hi = AppLang.hindi;
    setState(() {
      _busyMessage = hi ? 'मॉडल अनलोड किया जा रहा है…' : 'Unloading model…';
    });

    await _engine.unloadModel();

    if (mounted) {
      setState(() {
        _busyMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hi
                ? 'AI अनलोड हो गया। 0 MB RAM का उपयोग हो रहा है।'
                : 'AI unloaded. Running deterministic safety rules (0 MB RAM).',
          ),
          backgroundColor: AppTheme.saffron,
        ),
      );
    }
  }

  Future<void> _importFromDownloads(ModelTier tier) async {
    final hi = AppLang.hindi;
    setState(() {
      _busyTierId = tier.id;
      _busyMessage = hi ? 'Download फ़ोल्डर से कॉपी हो रहा है…' : 'Copying from Download folder…';
    });

    try {
      await _downloadService.importFromDownloads(tier);
      await _refreshFilesOnly();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hi
                  ? '${tier.displayNameHi} ऐप स्टोरेज में कॉपी हो गया!'
                  : '${tier.displayNameEn} imported to app storage!',
            ),
            backgroundColor: AppTheme.tealLight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyTierId = null;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _startDownload(ModelTier tier) async {
    final hi = AppLang.hindi;
    final urlCtrl = TextEditingController(text: tier.defaultDownloadUrl);
    final tokenCtrl = TextEditingController();

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          hi ? 'मॉडल डाउनलोड करें' : 'Download Model Pack',
          style: const TextStyle(color: AppTheme.saffronLight, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${hi ? tier.displayNameHi : tier.displayNameEn} (~${tier.sizeMb} MB)',
              style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hi
                  ? 'वाई-फ़ाई की सिफारिश की जाती है। यदि आपके पास स्थानीय सर्वर या कस्टम URL है, तो नीचे बदल सकते हैं।'
                  : 'Wi-Fi recommended. You can customize the download URL if hosted on a local SDMA server.',
              style: const TextStyle(color: AppTheme.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              style: const TextStyle(color: AppTheme.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: hi ? 'डाउनलोड URL' : 'Download URL',
                filled: true,
                fillColor: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tokenCtrl,
              obscureText: true,
              style: const TextStyle(color: AppTheme.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: hi ? 'Hugging Face टोकन (वैकल्पिक)' : 'HF Token (Optional)',
                filled: true,
                fillColor: AppTheme.navy,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(hi ? 'रद्द करें' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.teal),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(hi ? 'डाउनलोड शुरू करें' : 'Start Download'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    setState(() {
      _busyTierId = tier.id;
      _busyMessage = hi ? 'डाउनलोड शुरू हो रहा है…' : 'Starting download…';
    });

    try {
      await _downloadService.downloadModel(
        tier,
        urlOverride: urlCtrl.text.trim(),
        authToken: tokenCtrl.text.trim().isNotEmpty ? tokenCtrl.text.trim() : null,
      );
      await _refreshFilesOnly();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyTierId = null;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _deleteModel(ModelTier tier) async {
    final hi = AppLang.hindi;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(hi ? 'मॉडल हटाएं?' : 'Delete Model?'),
        content: Text(
          hi
              ? 'क्या आप स्टोरेज खाली करने के लिए ${tier.displayNameHi} को हटाना चाहते हैं?'
              : 'Delete ${tier.displayNameEn} from app storage to free space?',
          style: const TextStyle(color: AppTheme.grey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(hi ? 'नहीं' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(hi ? 'हटाएं' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_engine.activeTier == tier) {
        await _unloadModel();
      }
      await _downloadService.deleteModel(tier);
      await _refreshFilesOnly();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hi = AppLang.hindi;
    final isLoaded = _engine.isReady;
    final activeTier = _engine.activeTier;

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(hi ? 'AI मॉडल मैनेजर' : 'AI MODEL PACK MANAGER'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: hi ? 'रिफ्रेश' : 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.saffronLight))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Global Status & Load/Unload Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isLoaded ? AppTheme.teal.withValues(alpha: 0.15) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isLoaded ? AppTheme.tealLight : AppTheme.surfaceLight,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isLoaded ? Icons.memory : Icons.power_settings_new,
                            color: isLoaded ? AppTheme.green : AppTheme.saffronLight,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isLoaded
                                      ? (hi ? 'AI मॉडल सक्रिय (RAM में लोड)' : 'ACTIVE: ${activeTier?.displayNameEn ?? "AI MODEL"}')
                                      : (hi ? 'AI अनलोड है (नियम मोड सक्रिय)' : 'AI UNLOADED (RULE MODE)'),
                                  style: TextStyle(
                                    color: isLoaded ? AppTheme.green : AppTheme.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isLoaded
                                      ? (hi ? 'ऑन-डिवाइस जेम्मा मॉडल काम कर रहा है' : 'On-device model running locally in memory')
                                      : (hi ? '0 MB RAM उपयोग • सभी आपातकालीन नियम काम कर रहे हैं' : '0 MB RAM used • Deterministic safety rules active'),
                                  style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (isLoaded)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.red,
                                foregroundColor: AppTheme.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: _unloadModel,
                              icon: const Icon(Icons.eject, size: 14),
                              label: Text(hi ? 'अनलोड' : 'UNLOAD', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: AppTheme.surfaceLight, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.phone_android, color: AppTheme.grey, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hi
                                  ? 'डिवाइस RAM: ${_cap.totalRamMb} MB • अनुशंसित पैक: ${_recommended.toUpperCase()}'
                                  : 'Device RAM: ${_cap.totalRamMb} MB • Recommended: ${_recommended.toUpperCase()}',
                              style: const TextStyle(color: AppTheme.grey, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_busyMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.saffron.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.saffronLight.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.saffronLight),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _busyMessage!,
                            style: const TextStyle(color: AppTheme.saffronLight, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  hi ? 'मॉडल आकार चुनें (छोटे से बड़ा)' : 'AVAILABLE MODEL TIERS (SMALL TO BIG)',
                  style: const TextStyle(color: AppTheme.saffronLight, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                ),
                const SizedBox(height: 10),

                // Model Cards
                ...ModelTier.values.map((tier) {
                  final isCurrentActive = isLoaded && activeTier == tier;
                  final installedFile = _installedFiles[tier];
                  final downloadFolderFile = _downloadFolderFiles[tier];
                  final isInstalled = installedFile != null;
                  final isFoundInDownloads = downloadFolderFile != null && !isInstalled;
                  final isRecommended = _recommended == tier.id;
                  final prog = _downloadProgress[tier];

                  return _ModelTierCard(
                    tier: tier,
                    hi: hi,
                    isActive: isCurrentActive,
                    isInstalled: isInstalled,
                    isFoundInDownloads: isFoundInDownloads,
                    downloadPath: downloadFolderFile?.path,
                    isRecommended: isRecommended,
                    isBusy: _busyTierId == tier.id,
                    progress: prog,
                    onLoad: () => _loadModel(tier),
                    onUnload: _unloadModel,
                    onImport: () => _importFromDownloads(tier),
                    onDownload: () => _startDownload(tier),
                    onCancelDownload: () => _downloadService.cancelDownload(tier),
                    onDelete: () => _deleteModel(tier),
                  );
                }),

                // Discovered Storage Files Section
                if (_discoveredModels.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    hi ? 'स्टोरेज / डाउनलोड फ़ोल्डर में मिले मॉडल' : 'DETECTED IN STORAGE / DOWNLOADS',
                    style: const TextStyle(color: AppTheme.tealLight, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  ..._discoveredModels.map((discovered) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.surfaceLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file, color: AppTheme.saffronLight, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  discovered.fileName,
                                  style: const TextStyle(color: AppTheme.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${discovered.sizeMb} MB • ${discovered.isInAppStorage ? "App Storage" : "Download Folder"}',
                                  style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (discovered.matchedTier != null && !discovered.isInAppStorage)
                            TextButton.icon(
                              onPressed: () => _importFromDownloads(discovered.matchedTier!),
                              icon: const Icon(Icons.file_download, size: 14),
                              label: Text(hi ? 'आयात करें' : 'Import'),
                            )
                          else if (discovered.matchedTier != null && discovered.isInAppStorage)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.teal,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: () => _loadModel(discovered.matchedTier!),
                              child: Text(hi ? 'लोड करें' : 'Load', style: const TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 30),
              ],
            ),
    );
  }
}

class _ModelTierCard extends StatelessWidget {
  final ModelTier tier;
  final bool hi;
  final bool isActive;
  final bool isInstalled;
  final bool isFoundInDownloads;
  final String? downloadPath;
  final bool isRecommended;
  final bool isBusy;
  final DownloadProgress? progress;
  final VoidCallback onLoad;
  final VoidCallback onUnload;
  final VoidCallback onImport;
  final VoidCallback onDownload;
  final VoidCallback onCancelDownload;
  final VoidCallback onDelete;

  const _ModelTierCard({
    required this.tier,
    required this.hi,
    required this.isActive,
    required this.isInstalled,
    required this.isFoundInDownloads,
    this.downloadPath,
    required this.isRecommended,
    required this.isBusy,
    this.progress,
    required this.onLoad,
    required this.onUnload,
    required this.onImport,
    required this.onDownload,
    required this.onCancelDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = progress?.isDownloading == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppTheme.green
              : isRecommended
                  ? AppTheme.tealLight.withValues(alpha: 0.6)
                  : AppTheme.surfaceLight,
          width: isActive || isRecommended ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        hi ? tier.displayNameHi : tier.displayNameEn,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.tealLight.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.tealLight),
                          ),
                          child: Text(
                            hi ? 'अनुशंसित' : 'RECOMMENDED',
                            style: const TextStyle(color: AppTheme.tealLight, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStatusBadge(hi),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${tier.sizeMb} MB • ${hi ? "न्यूनतम" : "Min"} RAM: ${tier.minRamMb} MB',
              style: const TextStyle(color: AppTheme.saffronLight, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              hi ? tier.descriptionHi : tier.descriptionEn,
              style: const TextStyle(color: AppTheme.grey, fontSize: 12, height: 1.35),
            ),
            if (isFoundInDownloads && !isInstalled) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.navy,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.saffronLight.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_special, color: AppTheme.saffronLight, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hi ? 'Download फ़ोल्डर में फ़ाइल उपलब्ध है!' : 'File found in mobile Download folder!',
                        style: const TextStyle(color: AppTheme.saffronLight, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isDownloading && progress != null) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${progress!.receivedMb} MB / ${progress!.totalMb} MB (${(progress!.progress * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(color: AppTheme.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: AppTheme.red, size: 18),
                        onPressed: onCancelDownload,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress!.progress > 0 ? progress!.progress : null,
                    backgroundColor: AppTheme.navy,
                    color: AppTheme.tealLight,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (isActive) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.red,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: isBusy ? null : onUnload,
                      icon: const Icon(Icons.eject, size: 16),
                      label: Text(
                        hi ? 'मॉडल अनलोड करें' : 'UNLOAD MODEL',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ),
                ] else if (isInstalled) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.teal,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: isBusy || isDownloading ? null : onLoad,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(
                        hi ? 'RAM में लोड करें' : 'LOAD MODEL INTO RAM',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.grey),
                    tooltip: hi ? 'हटाएं' : 'Delete file',
                    onPressed: isBusy || isDownloading ? null : onDelete,
                  ),
                ] else if (isFoundInDownloads) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.saffron,
                        foregroundColor: AppTheme.navy,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: isBusy || isDownloading ? null : onImport,
                      icon: const Icon(Icons.file_download, size: 18),
                      label: Text(
                        hi ? 'डाउनलोड फ़ोल्डर से आयात करें' : 'IMPORT FROM DOWNLOADS',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceLight,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: isBusy || isDownloading ? null : onDownload,
                      icon: const Icon(Icons.cloud_download, size: 18),
                      label: Text(
                        hi ? 'डाउनलोड करें (${tier.sizeMb} MB)' : 'DOWNLOAD (${tier.sizeMb} MB)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool hi) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.green),
        ),
        child: Text(
          hi ? 'सक्रिय (Loaded)' : 'LOADED',
          style: const TextStyle(color: AppTheme.green, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }
    if (isInstalled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.tealLight.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          hi ? 'तैयार (Ready)' : 'READY',
          style: const TextStyle(color: AppTheme.tealLight, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }
    if (isFoundInDownloads) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.saffron.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          hi ? 'डाउनलोड में उपलब्ध' : 'IN DOWNLOADS',
          style: const TextStyle(color: AppTheme.saffronLight, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        hi ? 'डाउनलोड नहीं है' : 'NOT DOWNLOADED',
        style: const TextStyle(color: AppTheme.grey, fontSize: 10),
      ),
    );
  }
}
