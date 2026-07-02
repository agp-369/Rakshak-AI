import 'dart:io';
import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/gemma_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/services/patient_repository.dart';
import 'package:rakshak_ai/services/voice_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GemmaInferenceService _gemma = GemmaInferenceService();
  bool _useHindi = false;
  String _appSize = 'Calculating...';
  String _modelPath = 'Not found';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final modelFile = File('${dir.path}/gemma-4-E2B-it.litertlm');
      if (await modelFile.exists()) {
        final size = await modelFile.length();
        setState(() => _modelPath = '${(size / 1048576).toStringAsFixed(0)} MB on device');
      }
    } catch (_) {}

    try {
      final appDir = await getApplicationSupportDirectory();
      int totalSize = 0;
      await for (final entity in appDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      setState(() => _appSize = '${(totalSize / 1048576).toStringAsFixed(0)} MB');
    } catch (_) {
      setState(() => _appSize = 'Unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(Strings.settings.toUpperCase(), style: const TextStyle(letterSpacing: 2)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildSection('AI ENGINE'),
          _buildInfoTile(
            Icons.memory,
            'Model Status',
            _gemma.isModelLoaded ? 'Loaded & Ready' : 'Awaiting model file',
            _gemma.isModelLoaded ? AppTheme.teal : AppTheme.grey,
          ),
          _buildInfoTile(
            Icons.storage,
            'Model File',
            _modelPath,
            AppTheme.grey,
          ),
          _buildInfoTile(
            Icons.speed,
            'Total Inferences',
            '${_gemma.totalInferences}',
            AppTheme.saffronLight,
          ),
          if (_gemma.avgLatencyMs > 0)
            _buildInfoTile(
              Icons.timer,
              'Avg Latency',
              '${_gemma.avgLatencyMs.toStringAsFixed(1)} ms',
              AppTheme.grey,
            ),
          if (_gemma.lastError.isNotEmpty)
            _buildInfoTile(
              Icons.error_outline,
              'Last Error',
              _gemma.lastError,
              AppTheme.red,
            ),

          const SizedBox(height: 24),
          _buildSection('DEVICE'),
          _buildInfoTile(
            Icons.phone_android,
            'GPU Available',
            DeviceCapabilities.supportsVision ? 'Yes (Vision enabled)' : 'No (CPU-only)',
            DeviceCapabilities.supportsVision ? AppTheme.teal : AppTheme.grey,
          ),
          _buildInfoTile(
            Icons.memory,
            'Low RAM Device',
            DeviceCapabilities.isLowRam ? 'Yes (Lite mode)' : 'No (Full mode)',
            DeviceCapabilities.isLowRam ? AppTheme.saffronLight : AppTheme.teal,
          ),
          _buildInfoTile(
            Icons.tune,
            'Max Tokens',
            '${DeviceCapabilities.maxTokens}',
            AppTheme.grey,
          ),
          _buildInfoTile(
            Icons.offline_bolt,
            'Speculative Decoding',
            DeviceCapabilities.enableSpeculativeDecoding ? 'Enabled' : 'Disabled',
            DeviceCapabilities.enableSpeculativeDecoding ? AppTheme.teal : AppTheme.grey,
          ),
          _buildInfoTile(
            Icons.sd_storage,
            'App Data Size',
            _appSize,
            AppTheme.grey,
          ),

          const SizedBox(height: 24),
          _buildSection('LANGUAGE'),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: SwitchListTile(
              title: Text(Strings.hindiTriage, style: const TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text(
                _useHindi ? Strings.hindi : Strings.english,
                style: const TextStyle(color: AppTheme.grey, fontSize: 12),
              ),
              value: _useHindi,
              activeTrackColor: AppTheme.saffron,
              onChanged: (v) => setState(() {
                _useHindi = v;
                GemmaInferenceService.useHindi = v;
              }),
            ),
          ),

          const SizedBox(height: 24),
          _buildSection('VOICE'),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: SwitchListTile(
              title: const Text('Voice Language — Hindi', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Hindi STT & TTS for voice input / read aloud', style: TextStyle(color: AppTheme.grey, fontSize: 11)),
              value: VoiceService().language == VoiceLanguage.hindi,
              activeTrackColor: AppTheme.teal,
              onChanged: (v) {
                VoiceService().setLanguage(v ? VoiceLanguage.hindi : VoiceLanguage.english);
                setState(() {});
              },
            ),
          ),

          const SizedBox(height: 24),
          _buildSection('STORAGE'),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearPatientData,
              icon: const Icon(Icons.delete_sweep, size: 18),
              label: const Text('Clear All Patient Records'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.red,
                side: BorderSide(color: AppTheme.red.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearCache,
              icon: const Icon(Icons.cached, size: 18),
              label: const Text('Clear Model Cache & Re-load'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.saffronLight,
                side: BorderSide(color: AppTheme.saffronLight.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 24),
          _buildSection('DATA EXPORT'),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _exportData,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export Patients as JSON'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.teal,
                side: BorderSide(color: AppTheme.teal.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),

          const SizedBox(height: 24),
          _buildSection('ABOUT'),
          _buildInfoTile(Icons.info_outline, 'App Version', '1.0.0', AppTheme.grey),
          _buildInfoTile(Icons.model_training, 'AI Model', 'Gemma 4 E2B (5.15B)', AppTheme.grey),
          _buildInfoTile(Icons.flag, 'Theme', 'AI Living for India', AppTheme.saffronLight),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'रक्षक AI v1.0\nSamsung Solve for Tomorrow 2026',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey, fontSize: 10, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.saffronLight,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _clearPatientData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Patients?', style: TextStyle(color: AppTheme.red)),
        content: const Text('This cannot be undone.', style: TextStyle(color: AppTheme.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirm == true) {
      await PatientRepository().clearAll();
    }
  }

  Future<void> _exportData() async {
    try {
      final path = await PatientRepository().exportToJson();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: $path'),
            backgroundColor: AppTheme.teal,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final modelFile = File('${dir.path}/gemma-4-E2B-it.litertlm');
      if (await modelFile.exists()) {
        await modelFile.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model cache cleared. Restart app to re-load.')),
          );
        }
      }
    } catch (_) {}
  }
}
