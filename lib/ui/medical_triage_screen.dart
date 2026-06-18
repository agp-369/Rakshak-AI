import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:rakshak_ai/services/triage_engine.dart';
import 'package:rakshak_ai/services/gemma_triage_service.dart';
import 'package:rakshak_ai/services/patient_repository.dart';
import 'package:rakshak_ai/services/mesh_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

class MedicalTriageScreen extends StatefulWidget {
  const MedicalTriageScreen({super.key});

  @override
  State<MedicalTriageScreen> createState() => _MedicalTriageScreenState();
}

class _MedicalTriageScreenState extends State<MedicalTriageScreen> {
  final TriageEngine _triage = TriageEngine();
  final GemmaTriageService _gemmaTriage = GemmaTriageService();
  final PatientRepository _repo = PatientRepository();
  final MeshService _mesh = MeshService();

  List<PatientAssessment> _patients = [];
  final TextEditingController _descController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool? _isWalking;
  bool? _isBreathing;
  double _respRate = 20;
  bool? _hasRadialPulse;
  double _capRefill = 1;
  bool? _respondsToVoice;
  bool? _respondsToPain;
  String _visibleInjuries = '';
  bool _isAssessing = false;
  XFile? _cameraImage;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final patients = await _repo.getAllPatients();
    if (mounted) setState(() => _patients = patients);
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _performTriage() async {
    if (_isWalking == null || _isBreathing == null ||
        _hasRadialPulse == null || _respondsToVoice == null ||
        _respondsToPain == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set all assessment fields before triaging'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    setState(() => _isAssessing = true);

    try {
      final assessment = _triage.assess(
        isWalking: _isWalking!,
        isBreathing: _isBreathing!,
        respiratoryRate: _respRate.round(),
        hasRadialPulse: _hasRadialPulse!,
        capillaryRefillSeconds: _capRefill.round(),
        respondsToVoice: _respondsToVoice!,
        respondsToPain: _respondsToPain!,
        visibleInjuries: _visibleInjuries.isNotEmpty ? _visibleInjuries : null,
      );

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _categoryColor(assessment.category),
                ),
              ),
              const SizedBox(width: 10),
              Text('Confirm ${assessment.category.code}',
                style: TextStyle(color: _categoryColor(assessment.category), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(assessment.category.description,
                style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
              const SizedBox(height: 12),
              _confirmField('Walking', assessment.isWalking),
              _confirmField('Breathing', assessment.isBreathing),
              _confirmField('Resp Rate', '${assessment.respiratoryRate}/min'),
              _confirmField('Radial Pulse', assessment.hasRadialPulse),
              _confirmField('Cap Refill', '${assessment.capillaryRefillSeconds}s'),
              _confirmField('Responds to Voice', assessment.respondsToVoice),
              _confirmField('Responds to Pain', assessment.respondsToPain),
              if (assessment.visibleInjuries != null)
                _confirmField('Injuries', assessment.visibleInjuries!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Assessment'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        if (mounted) setState(() => _isAssessing = false);
        return;
      }

      await _repo.insertPatient(assessment);
      await _loadPatients();
      if (mounted) {
        setState(() {
          _isAssessing = false;
          _resetForm();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isAssessing = false);
    }
  }

  Widget _confirmField(String label, dynamic value) {
    final display = value is bool ? (value ? 'Yes' : 'No') : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
          Text(display, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _parseFromDescription() async {
    final text = _descController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isAssessing = true);

    try {
      final assessment = await _gemmaTriage.parseAndAssess(text)
          .timeout(const Duration(seconds: 90));
      await _repo.insertPatient(assessment);
      await _loadPatients();
    } catch (e) {
      final assessment = _triage.parseFromDescription(text);
      await _repo.insertPatient(assessment);
      await _loadPatients();
    }

    if (mounted) {
      setState(() {
        _isAssessing = false;
        _descController.clear();
      });
    }
  }

  Future<void> _assessFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;
    setState(() => _cameraImage = image);
  }

  Future<void> _analyzeCameraImage() async {
    if (_cameraImage == null) return;
    setState(() => _isAssessing = true);

    final bytes = await _cameraImage!.readAsBytes();
    final assessment = await _gemmaTriage.assessFromImage(bytes, _descController.text);
    await _repo.insertPatient(assessment);
    await _loadPatients();

    if (mounted) {
      setState(() {
        _isAssessing = false;
        _cameraImage = null;
      });
    }
  }

  void _showSyncDialog() async {
    final payload = await _mesh.generateSyncPayload();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mesh Sync', style: TextStyle(color: AppTheme.saffronLight)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share your triage log with another responder.', style: TextStyle(color: AppTheme.white, fontSize: 13)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(data: payload, version: QrVersions.auto, size: 200),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _scanSyncQr();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan to Sync'),
            ),
          ],
        ),
      ),
    );
  }

  void _scanSyncQr() {
    final scaffold = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: AppTheme.navy,
          appBar: AppBar(title: const Text('Scan Sync QR')),
          body: QRView(
            key: GlobalKey(debugLabel: 'QR'),
            onQRViewCreated: (controller) {
              controller.scannedDataStream.listen((scanData) async {
                controller.pauseCamera();
                final count = await _mesh.processSyncPayload(scanData.code ?? '');

                navigator.pop();
                scaffold.showSnackBar(
                  SnackBar(content: Text(count >= 0 ? 'Synced $count new patient records.' : 'Sync failed. Invalid data.')),
                );
                _loadPatients();
              });
            },
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _isWalking = null;
      _isBreathing = null;
      _respRate = 20;
      _hasRadialPulse = null;
      _capRefill = 1;
      _respondsToVoice = null;
      _respondsToPain = null;
      _visibleInjuries = '';
      _cameraImage = null;
    });
  }

  Color _categoryColor(TriageCategory cat) {
    switch (cat) {
      case TriageCategory.immediate: return AppTheme.red;
      case TriageCategory.delayed: return AppTheme.triageDelayed;
      case TriageCategory.minimal: return AppTheme.green;
      case TriageCategory.deceased: return AppTheme.triageDeceased;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: const Text('Medical Triage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: AppTheme.saffronLight),
            onPressed: _showSyncDialog,
          ),
          TextButton(
            onPressed: _patients.isEmpty ? null : () async {
              await _repo.clearAll();
              _loadPatients();
            },
            child: const Text('Clear', style: TextStyle(color: AppTheme.saffronLight)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Triage form
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.saffron.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.healing, color: AppTheme.saffron, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RAKSHAK TRIAGE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.saffronLight,
                                fontSize: 14,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'START Protocol + Gemma 4 AI',
                              style: TextStyle(color: AppTheme.grey, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      _buildOfflineBadge(),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Language indicator
                  Row(
                    children: [
                      _langChip('EN', AppTheme.saffron),
                      const SizedBox(width: 6),
                      _langChip('हिंदी', AppTheme.teal),
                      const SizedBox(width: 8),
                      Text('supported', style: TextStyle(color: AppTheme.grey, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Quick description input
                  TextField(
                    controller: _descController,
                    decoration: InputDecoration(
                      labelText: 'Describe Patient (English / हिंदी)',
                      hintText: 'e.g., "Patient not walking, weak pulse" or Hindi...',
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.camera_alt, color: AppTheme.saffronLight),
                        onPressed: _assessFromCamera,
                        tooltip: 'Camera Assessment',
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isAssessing ? null : _parseFromDescription,
                    icon: _isAssessing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_isAssessing ? 'Analyzing... (up to 90s)' : 'AI Analysis'),
                  ),

                  // Camera preview
                  if (_cameraImage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_cameraImage!.path),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() => _cameraImage = null),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retake', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.grey,
                                    side: const BorderSide(color: AppTheme.surfaceLight),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isAssessing ? null : _analyzeCameraImage,
                                  icon: _isAssessing
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.auto_awesome, size: 16),
                                  label: Text(_isAssessing ? 'Analyzing...' : 'Analyze Image', style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const Divider(height: 24, color: AppTheme.surfaceLight),
                  const Text(
                    'START PROTOCOL ASSESSMENT',
                    style: TextStyle(
                      color: AppTheme.saffronLight,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Row 1: Walking + Breathing
                  Row(
                    children: [
                      Expanded(child: _quickToggle('Walking', _isWalking, (v) => setState(() => _isWalking = v))),
                      const SizedBox(width: 8),
                      Expanded(child: _quickToggle('Breathing', _isBreathing, (v) => setState(() => _isBreathing = v))),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Radial Pulse + Mental Status
                  Row(
                    children: [
                      Expanded(child: _quickToggle('Radial Pulse', _hasRadialPulse, (v) => setState(() => _hasRadialPulse = v))),
                      const SizedBox(width: 8),
                      Expanded(child: _quickToggle('Voice Response', _respondsToVoice, (v) => setState(() => _respondsToVoice = v))),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 3: Pain Response + Resp Rate display
                  Row(
                    children: [
                      Expanded(child: _quickToggle('Pain Response', _respondsToPain, (v) => setState(() => _respondsToPain = v))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.surfaceLight),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Text('Resp Rate', style: TextStyle(fontSize: 9, color: AppTheme.grey)),
                              Text('${_respRate.round()}/min',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: (_respRate > 30 || _respRate < 10) ? AppTheme.red : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Sliders
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          ),
                          child: Slider(
                            value: _respRate,
                            min: 0, max: 50, divisions: 50,
                            activeColor: (_respRate > 30 || _respRate < 10) ? AppTheme.red : AppTheme.saffron,
                            inactiveColor: AppTheme.surfaceLight,
                            label: '${_respRate.round()}',
                            onChanged: (v) => setState(() => _respRate = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: Column(
                          children: [
                            const Text('Cap Refill', style: TextStyle(fontSize: 9, color: AppTheme.grey)),
                            Text('${_capRefill.round()}s',
                              style: TextStyle(
                                fontSize: 12,
                                color: _capRefill > 2 ? AppTheme.red : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: _capRefill,
                      min: 0, max: 5, divisions: 10,
                      activeColor: _capRefill > 2 ? AppTheme.red : AppTheme.saffron,
                      inactiveColor: AppTheme.surfaceLight,
                      label: '${_capRefill.round()}s',
                      onChanged: (v) => setState(() => _capRefill = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isAssessing ? null : _performTriage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.saffron,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _isAssessing ? 'Assessing...' : 'RUN START ASSESSMENT',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Patient count header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.people, size: 14, color: AppTheme.grey),
                const SizedBox(width: 6),
                Text(
                  '${_patients.length} Patients Triaged',
                  style: const TextStyle(color: AppTheme.grey, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                if (_patients.isNotEmpty)
                  Text(
                    '${_patients.where((p) => p.category == TriageCategory.immediate).length} Critical',
                    style: const TextStyle(color: AppTheme.red, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Patient list
          Expanded(
            child: _patients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.medical_services_outlined, size: 40, color: AppTheme.grey.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text('No patients triaged yet.', style: TextStyle(color: AppTheme.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _patients.length,
                    itemBuilder: (context, index) {
                      final p = _patients[index];
                      final isHighConfidence = p.confidenceScore >= 0.8;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isHighConfidence
                                ? AppTheme.teal.withValues(alpha: 0.4)
                                : AppTheme.surfaceLight,
                            width: isHighConfidence ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _categoryColor(p.category).withValues(alpha: 0.2),
                            radius: 18,
                            child: Text(
                              p.category.code,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _categoryColor(p.category),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text('Patient ${index + 1}',
                            style: const TextStyle(fontSize: 13, color: Colors.white)),
                          subtitle: Text(
                            '${p.category.description} · ${(p.confidenceScore * 100).toStringAsFixed(0)}% confidence',
                            style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                          ),
                          trailing: isHighConfidence
                              ? const Icon(Icons.verified, color: AppTheme.teal, size: 16)
                              : null,
                          onTap: () => _showPatientDetail(context, p),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showPatientDetail(BuildContext context, PatientAssessment p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _categoryColor(p.category),
              ),
            ),
            const SizedBox(width: 10),
            Text('Patient ${p.id.substring(0, 8)}',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Category', '${p.category.code} — ${p.category.description}'),
            _detailRow('Confidence', '${(p.confidenceScore * 100).toStringAsFixed(0)}%'),
            const Divider(color: AppTheme.surfaceLight),
            _detailRow('Walking', p.isWalking ? 'Yes' : 'No'),
            _detailRow('Breathing', p.isBreathing ? 'Yes' : 'No'),
            _detailRow('Respiratory Rate', '${p.respiratoryRate}/min'),
            _detailRow('Radial Pulse', p.hasRadialPulse ? 'Present' : 'Absent'),
            _detailRow('Capillary Refill', '${p.capillaryRefillSeconds}s'),
            _detailRow('Voice Response', p.respondsToVoice ? 'Yes' : 'No'),
            _detailRow('Pain Response', p.respondsToPain ? 'Yes' : 'No'),
            if (p.visibleInjuries != null) _detailRow('Injuries', p.visibleInjuries!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppTheme.grey)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _langChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOfflineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 8, color: AppTheme.teal),
          SizedBox(width: 3),
          Text('OFFLINE', style: TextStyle(color: AppTheme.teal, fontSize: 7, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _quickToggle(String label, bool? value, ValueChanged<bool> onChanged) {
    final isSet = value != null;
    return InkWell(
      onTap: () => onChanged(value != true),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isSet ? AppTheme.saffron.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSet ? AppTheme.saffron : AppTheme.surfaceLight,
            width: isSet ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSet ? (value ? Icons.check_circle : Icons.cancel_outlined) : Icons.help_outline,
              color: isSet ? AppTheme.saffron : AppTheme.grey,
              size: 12,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                isSet ? '$label: ${value ? "Yes" : "No"}' : label,
                style: TextStyle(
                  fontSize: 9,
                  color: isSet ? Colors.white : AppTheme.grey,
                  fontWeight: isSet ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
