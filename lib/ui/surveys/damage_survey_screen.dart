import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/damage_survey.dart';
import '../../services/damage_survey_service.dart';
import '../../services/gps_service.dart';
import '../../services/localization.dart';
import '../../services/location_descriptor_service.dart';
import '../../theme/app_theme.dart';

class DamageSurveyScreen extends StatefulWidget {
  const DamageSurveyScreen({super.key});

  @override
  State<DamageSurveyScreen> createState() => _DamageSurveyScreenState();
}

class _DamageSurveyScreenState extends State<DamageSurveyScreen> {
  final _service = DamageSurveyService();
  List<DamageSurveyRecord> _surveys = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.getSurveys();
    if (mounted) {
      setState(() {
        _surveys = list;
        _loading = false;
      });
    }
  }

  Future<void> _startNewSurvey() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NewSurveySheet(),
    );

    if (result == true) {
      await _load();
    }
  }

  Future<void> _exportSurveys() async {
    if (_surveys.isEmpty) return;
    final csv = _service.exportToCsv(_surveys);

    await Share.share(
      csv,
      subject: 'Rakshak_Damage_Survey_Export_${DateTime.now().toIso8601String().substring(0, 10)}.csv',
    );
  }

  Future<void> _deleteSurvey(DamageSurveyRecord record) async {
    final hi = AppLang.hindi;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(hi ? 'रिकॉर्ड हटाएं?' : 'Delete Record?'),
        content: Text(
          hi ? 'क्या आप इस सर्वेक्षण रिकॉर्ड को हटाना चाहते हैं?' : 'Delete this survey record permanently?',
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
      await _service.deleteSurvey(record.id);
      await _load();
    }
  }

  Color _severityColor(DamageSeverity s) {
    switch (s) {
      case DamageSeverity.minor: return AppTheme.green;
      case DamageSeverity.partial: return AppTheme.saffronLight;
      case DamageSeverity.severe: return AppTheme.saffron;
      case DamageSeverity.destroyed: return AppTheme.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hi = AppLang.hindi;

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(
          hi ? 'आपदा उपरांत क्षति सर्वेक्षण' : 'DAMAGE SURVEY (POST-DISASTER)',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        actions: [
          if (_surveys.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share, color: AppTheme.saffronLight),
              onPressed: _exportSurveys,
              tooltip: hi ? 'CSV एक्सपोर्ट करें' : 'Export CSV',
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.saffron,
        foregroundColor: AppTheme.navy,
        onPressed: _startNewSurvey,
        icon: const Icon(Icons.add_a_photo, size: 20),
        label: Text(
          hi ? 'नया सर्वेक्षण जोड़ें' : 'NEW ASSESSMENT',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.saffronLight))
          : _surveys.isEmpty
              ? _EmptySurveyView(hi: hi, onStart: _startNewSurvey)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.tealLight.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.assignment_turned_in, color: AppTheme.tealLight, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              hi
                                  ? 'भू-टैग (GPS) फोटो और क्षति रिकॉर्ड स्थानीय रूप से सुरक्षित हैं। राहत शिविर या कंट्रोल रूम पहुँचने पर CSV में एक्सपोर्ट करें।'
                                  : 'Geotagged photos & damage assessments saved locally. Export to CSV/MIS when reaching relief camp or signal.',
                              style: const TextStyle(color: AppTheme.white, fontSize: 11.5, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._surveys.map((s) {
                      final file = s.imagePath.isNotEmpty ? File(s.imagePath) : null;
                      final hasImage = file != null && file.existsSync();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.surfaceLight),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  color: AppTheme.navy,
                                  child: hasImage
                                      ? Image.file(file, fit: BoxFit.cover)
                                      : const Icon(Icons.broken_image, color: AppTheme.grey, size: 28),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            s.beneficiaryName.isNotEmpty
                                                ? s.beneficiaryName
                                                : (s.houseId.isNotEmpty ? s.houseId : (hi ? 'अज्ञात मकान' : 'Unlabeled Property')),
                                            style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _severityColor(s.damageSeverity).withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: _severityColor(s.damageSeverity)),
                                          ),
                                          child: Text(
                                            hi ? s.damageSeverity.labelHi : s.damageSeverity.labelEn,
                                            style: TextStyle(
                                              color: _severityColor(s.damageSeverity),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      hi ? s.structureType.labelHi : s.structureType.labelEn,
                                      style: const TextStyle(color: AppTheme.saffronLight, fontSize: 11),
                                    ),
                                    if (s.landmarkAndVillage.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        s.landmarkAndVillage,
                                        style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      '${s.latitude.toStringAsFixed(4)}, ${s.longitude.toStringAsFixed(4)} • ${s.timestamp.toLocal().toString().substring(0, 16)}',
                                      style: const TextStyle(color: AppTheme.grey, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.grey, size: 18),
                                onPressed: () => _deleteSurvey(s),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 60),
                  ],
                ),
    );
  }
}

class _EmptySurveyView extends StatelessWidget {
  final bool hi;
  final VoidCallback onStart;

  const _EmptySurveyView({required this.hi, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_indoor_outlined, size: 54, color: AppTheme.grey),
            const SizedBox(height: 16),
            Text(
              hi ? 'अभी कोई क्षति सर्वेक्षण नहीं' : 'No Damage Surveys Yet',
              style: const TextStyle(color: AppTheme.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hi
                  ? 'बाढ़ या चक्रवात के बाद क्षतिग्रस्त मकानों और संरचनाओं की जियो-टैग फ़ोटो लेकर रिपोर्ट तैयार करें। यह सरकारी मुआवज़े और राहत वितरण में सहायक है।'
                  : 'Capture geotagged evidence photos and damage severity for flood/cyclone affected properties to speed up relief delivery and avoid double-counting.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.grey, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.saffron,
                foregroundColor: AppTheme.navy,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: onStart,
              icon: const Icon(Icons.add_a_photo, size: 18),
              label: Text(hi ? 'पहला सर्वेक्षण दर्ज करें' : 'Start First Survey', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewSurveySheet extends StatefulWidget {
  const _NewSurveySheet();

  @override
  State<_NewSurveySheet> createState() => _NewSurveySheetState();
}

class _NewSurveySheetState extends State<_NewSurveySheet> {
  final _gps = GpsService();
  final _descriptor = LocationDescriptorService();
  final _service = DamageSurveyService();
  final _picker = ImagePicker();

  final _beneficiaryCtrl = TextEditingController();
  final _houseIdCtrl = TextEditingController();
  final _waterMarkCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  File? _image;
  GeoPoint? _point;
  String _locationSummary = '';
  StructureType _structureType = StructureType.residential;
  DamageSeverity _severity = DamageSeverity.partial;
  bool _isHabitable = false;
  bool _locating = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _beneficiaryCtrl.dispose();
    _houseIdCtrl.dispose();
    _waterMarkCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _locating = true);
    await _gps.initialize();
    try {
      final p = await _gps.getCurrentPosition();
      final desc = await _descriptor.describeLocation(p);
      if (mounted) {
        setState(() {
          _point = p;
          _locationSummary = AppLang.hindi ? desc.formattedHi(includeCoords: false) : desc.formattedEn(includeCoords: false);
          _locating = false;
        });
      }
    } catch (_) {
      final last = _gps.lastKnown;
      if (mounted) {
        setState(() {
          _point = last;
          _locating = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (picked != null) {
        setState(() {
          _image = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint('[Survey] pickImage error: $e');
    }
  }

  Future<void> _save() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLang.hindi ? 'कृपया क्षति की साक्ष्य फ़ोटो लें' : 'Please take an evidence photo'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final id = 'survey_${DateTime.now().millisecondsSinceEpoch}';
    final savedImagePath = await _service.saveEvidenceImage(_image!, id);

    final record = DamageSurveyRecord(
      id: id,
      imagePath: savedImagePath,
      timestamp: DateTime.now(),
      latitude: _point?.latitude ?? 0.0,
      longitude: _point?.longitude ?? 0.0,
      accuracy: _point?.accuracy ?? 0.0,
      landmarkAndVillage: _locationSummary,
      beneficiaryName: _beneficiaryCtrl.text.trim(),
      houseId: _houseIdCtrl.text.trim(),
      structureType: _structureType,
      damageSeverity: _severity,
      waterMarkMeters: double.tryParse(_waterMarkCtrl.text.trim()),
      isHabitable: _isHabitable,
      notes: _notesCtrl.text.trim(),
    );

    await _service.saveSurvey(record);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hi = AppLang.hindi;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hi ? 'नया क्षति मूल्यांकन' : 'NEW DAMAGE ASSESSMENT',
                  style: const TextStyle(color: AppTheme.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(icon: const Icon(Icons.close, color: AppTheme.grey), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),

            // Photo Capture Area
            GestureDetector(
              onTap: () => _pickImage(ImageSource.camera),
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: AppTheme.navy,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt, color: AppTheme.saffronLight, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            hi ? 'कैमरा से क्षति फ़ोटो खींचें' : 'Tap to Capture Evidence Photo',
                            style: const TextStyle(color: AppTheme.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hi ? 'या गैलरी से चुनें' : 'or select from device',
                            style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Auto GPS & Landmark Indicator
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.navy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location, color: AppTheme.tealLight, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _locating
                        ? Text(
                            hi ? 'जीपीएस स्थान प्राप्त किया जा रहा है…' : 'Acquiring GPS fix…',
                            style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                          )
                        : Text(
                            _locationSummary.isNotEmpty
                                ? _locationSummary
                                : (_point != null ? '${_point!.latitude.toStringAsFixed(4)}, ${_point!.longitude.toStringAsFixed(4)}' : (hi ? 'GPS अनुपलब्ध' : 'No GPS Fix')),
                            style: const TextStyle(color: AppTheme.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Structure Type
            Text(hi ? 'संरचना प्रकार' : 'Structure Type', style: const TextStyle(color: AppTheme.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: StructureType.values.map((t) {
                final selected = _structureType == t;
                return ChoiceChip(
                  label: Text(hi ? t.labelHi : t.labelEn, style: TextStyle(fontSize: 11, color: selected ? AppTheme.navy : AppTheme.white)),
                  selected: selected,
                  selectedColor: AppTheme.saffron,
                  backgroundColor: AppTheme.navy,
                  onSelected: (_) => setState(() => _structureType = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Damage Severity
            Text(hi ? 'क्षति गंभीरता' : 'Damage Severity', style: const TextStyle(color: AppTheme.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: DamageSeverity.values.map((s) {
                final selected = _severity == s;
                return ChoiceChip(
                  label: Text(hi ? s.labelHi : s.labelEn, style: TextStyle(fontSize: 11, color: selected ? AppTheme.navy : AppTheme.white)),
                  selected: selected,
                  selectedColor: AppTheme.tealLight,
                  backgroundColor: AppTheme.navy,
                  onSelected: (_) => setState(() => _severity = s),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Text Inputs
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _beneficiaryCtrl,
                    style: const TextStyle(color: AppTheme.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: hi ? 'मुखिया का नाम' : 'Beneficiary Name',
                      filled: true,
                      fillColor: AppTheme.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _houseIdCtrl,
                    style: const TextStyle(color: AppTheme.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: hi ? 'मकान नं. / राशन कार्ड' : 'House / Ration ID',
                      filled: true,
                      fillColor: AppTheme.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _waterMarkCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: hi ? 'जल स्तर निशान (मी.)' : 'Water Mark (Meters)',
                      filled: true,
                      fillColor: AppTheme.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(hi ? 'रहने योग्य है?' : 'Habitable?', style: const TextStyle(color: AppTheme.white, fontSize: 12)),
                    value: _isHabitable,
                    activeThumbColor: AppTheme.green,
                    onChanged: (v) => setState(() => _isHabitable = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              style: const TextStyle(color: AppTheme.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: hi ? 'अतिरिक्त विवरण / टिप्पणी' : 'Surveyor Notes / Details',
                filled: true,
                fillColor: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 16),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.saffron,
                  foregroundColor: AppTheme.navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_circle, size: 18),
                label: Text(
                  hi ? 'सर्वेक्षण सुरक्षित करें' : 'SAVE DAMAGE ASSESSMENT',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
