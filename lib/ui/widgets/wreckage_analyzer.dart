import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rakshak_ai/services/gemma_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

class WreckageAnalyzer extends StatefulWidget {
  const WreckageAnalyzer({super.key});

  @override
  State<WreckageAnalyzer> createState() => _WreckageAnalyzerState();
}

class _WreckageAnalyzerState extends State<WreckageAnalyzer> {
  final ImagePicker _picker = ImagePicker();
  final GemmaInferenceService _gemma = GemmaInferenceService();

  XFile? _image;
  String _analysis = '';
  bool _isAnalyzing = false;
  ConfidenceLevel _lastConfidence = ConfidenceLevel.medium;

  bool get _canUseVision => _gemma.visionAvailable;

  Future<void> _captureAndAnalyze() async {
    if (!_canUseVision) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vision analysis requires a device with GPU/NPU support.'),
          backgroundColor: AppTheme.saffron,
        ),
      );
      return;
    }

    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() {
      _image = photo;
      _isAnalyzing = true;
      _analysis = 'Analyzing structure via Gemma 4...';
    });

    final bytes = await photo.readAsBytes();
    final result = await _gemma.analyzeImage(
      bytes,
      'Assess this disaster scene: hazards, structural damage, survivor signals, safe routes.',
    );

    setState(() {
      _isAnalyzing = false;
      _analysis = result.text;
      _lastConfidence = result.confidence;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHighConfidence = _lastConfidence == ConfidenceLevel.high;

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: const Text('STRUCTURE SCAN', style: TextStyle(letterSpacing: 2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVisionGate(),

            const SizedBox(height: 24),

            if (_image != null)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(_image!.path),
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            if (_isAnalyzing)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: LinearProgressIndicator(
                  color: AppTheme.saffron,
                  backgroundColor: AppTheme.surface,
                ),
              ),

            if (_analysis.isNotEmpty && !_isAnalyzing)
              Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isHighConfidence ? AppTheme.teal.withValues(alpha: 0.3) : AppTheme.surfaceLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye, color: AppTheme.saffronLight, size: 16),
                        const SizedBox(width: 10),
                        const Text('ASSESSMENT',
                          style: TextStyle(color: AppTheme.saffronLight, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.5)),
                        const Spacer(),
                        _confidenceBadge(_lastConfidence),
                      ],
                    ),
                    const Divider(color: AppTheme.surfaceLight, height: 28),
                    Text(_analysis, style: const TextStyle(color: AppTheme.white, fontSize: 13, height: 1.5)),
                  ],
                ),
              ),

            if (_canUseVision) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _captureAndAnalyze,
                icon: const Icon(Icons.camera_alt),
                label: Text(_image == null ? 'CAPTURE & ANALYZE' : 'RE-SCAN'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVisionGate() {
    if (!_canUseVision) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.saffron.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.visibility_off, size: 48, color: AppTheme.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Vision Analysis Requires GPU',
              style: TextStyle(
                color: AppTheme.saffronLight,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Structural damage assessment uses Gemma 4 multimodal vision, '
              'which requires a GPU or NPU accelerator.\n\n'
              'Available on Samsung Galaxy S series and premium devices.\n\n'
              'Medical triage (text-based) works on all devices.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.memory, color: AppTheme.teal, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'GPU acceleration available — full vision analysis ready',
              style: TextStyle(color: AppTheme.teal, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confidenceBadge(ConfidenceLevel level) {
    Color color = AppTheme.grey;
    if (level == ConfidenceLevel.high) color = AppTheme.teal;
    if (level == ConfidenceLevel.insufficient) color = AppTheme.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level.name.toUpperCase(),
        style: TextStyle(fontSize: 7, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
