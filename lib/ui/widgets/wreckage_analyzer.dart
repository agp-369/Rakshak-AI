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

  Future<void> _captureAndAnalyze() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() {
      _image = photo;
      _isAnalyzing = true;
      _analysis = 'Analyzing structure... Gemma 4 E2B processing.';
    });

    final bytes = await photo.readAsBytes();

    final result = await _gemma.analyzeImage(
      bytes,
      'Act as a structural engineer in a disaster zone. Analyze this image for: '
      '1. CRITICAL HAZARDS (Fire, Gas, Electrical) '
      '2. STRUCTURAL FRACTURES (Severity, Collapse Risk) '
      '3. SURVIVOR SIGNALS (Movement, Entrapment) '
      '4. TACTICAL ACCESS (Blocked vs Safe routes) '
      'Provide a concise, life-saving report.',
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
          children: [
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

            const SizedBox(height: 24),

            if (_isAnalyzing)
              LinearProgressIndicator(
                color: AppTheme.saffron,
                backgroundColor: AppTheme.surface,
              ),

            if (_analysis.isNotEmpty && !_isAnalyzing)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isHighConfidence ? AppTheme.teal.withValues(alpha: 0.3) : AppTheme.surfaceLight,
                    width: isHighConfidence ? 1.5 : 1,
                  ),
                  boxShadow: isHighConfidence ? [
                    BoxShadow(color: AppTheme.teal.withValues(alpha: 0.05), blurRadius: 15)
                  ] : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye, color: AppTheme.saffronLight, size: 16),
                        const SizedBox(width: 10),
                        const Text('DAMAGE ASSESSMENT',
                          style: TextStyle(color: AppTheme.saffronLight, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.5)),
                        const Spacer(),
                        _confidenceBadge(_lastConfidence),
                      ],
                    ),
                    const Divider(color: AppTheme.surfaceLight, height: 28),
                    Text(
                      _analysis,
                      style: const TextStyle(color: AppTheme.white, fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _captureAndAnalyze,
              icon: const Icon(Icons.camera_alt),
              label: Text(_image == null ? 'CAPTURE & ANALYZE' : 'RE-SCAN'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'VISION ANALYSIS | GEMMA 4 E2B',
              style: TextStyle(color: AppTheme.grey, fontSize: 9, letterSpacing: 2),
            ),
            if (_analysis.contains('unavailable'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.saffron.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.saffron.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'Vision requires GPU acceleration. Works on Samsung Galaxy S series with NPU.\n'
                    'Text triage still works on all devices.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.grey, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
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
