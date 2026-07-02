import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rakshak_ai/services/incident_report_service.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});
  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _service = IncidentReportService();
  final _gps = GpsService();
  final _picker = ImagePicker();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<IncidentReport> _reports = [];
  IncidentType? _selectedType;
  XFile? _photo;
  bool _loading = true;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final reports = await _service.getReports();
    if (mounted) setState(() { _reports = reports; _loading = false; });
  }

  Future<void> _submitReport() async {
    if (_selectedType == null || _descCtrl.text.trim().isEmpty) return;

    double? lat; double? lon;
    try {
      final pos = await _gps.getCurrentPosition();
      lat = pos.latitude; lon = pos.longitude;
    } catch (_) {}

    final report = IncidentReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _selectedType!,
      description: _descCtrl.text.trim(),
      latitude: lat, longitude: lon,
      photoPath: _photo?.path,
    );

    await _service.addReport(report);
    _descCtrl.clear();
    setState(() { _selectedType = null; _photo = null; _showForm = false; });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('INCIDENT REPORT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
            Text('घटना रिपोर्ट', style: TextStyle(fontSize: 11, color: AppTheme.grey)),
          ],
        ),
        iconTheme: const IconThemeData(color: AppTheme.saffronLight),
        actions: [
          IconButton(
            icon: Icon(_showForm ? Icons.list : Icons.add_circle_outline, color: AppTheme.saffronLight),
            onPressed: () => setState(() => _showForm = !_showForm),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _showForm ? _buildForm() : _buildList(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('REPORT AN INCIDENT', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.saffronLight, fontSize: 14, letterSpacing: 2)),
            const SizedBox(height: 4),
            const Text('Select type, describe, and optionally add a photo.', style: TextStyle(color: AppTheme.grey, fontSize: 11)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: IncidentType.values.map((t) {
                final sel = _selectedType == t;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 16, color: sel ? Colors.white : t.color),
                      const SizedBox(width: 6),
                      Text(t.label, style: TextStyle(fontSize: 11, color: sel ? Colors.white : AppTheme.grey)),
                    ],
                  ),
                  selected: sel,
                  selectedColor: t.color,
                  onSelected: (_) => setState(() => _selectedType = t),
                  backgroundColor: AppTheme.surface,
                  side: BorderSide(color: sel ? t.color : AppTheme.surfaceLight),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe what happened, affected area, injuries...',
                isDense: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final img = await _picker.pickImage(source: ImageSource.camera);
                    if (img != null) setState(() => _photo = img);
                  },
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: const Text('Add Photo', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.saffronLight, side: const BorderSide(color: AppTheme.saffronLight)),
                ),
                const SizedBox(width: 12),
                if (_photo != null)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_photo!.path), height: 60, width: 60, fit: BoxFit.cover),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _selectedType != null && _descCtrl.text.trim().isNotEmpty ? _submitReport : null,
              icon: const Icon(Icons.send, size: 18),
              label: const Text('SUBMIT REPORT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.report_gmailerrorred, size: 48, color: AppTheme.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('No incidents reported.', style: TextStyle(color: AppTheme.grey)),
            const SizedBox(height: 4),
            const Text('Tap + to report an incident.', style: TextStyle(color: AppTheme.grey, fontSize: 11)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, i) {
        final r = _reports[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: r.resolved ? AppTheme.teal.withValues(alpha: 0.3) : r.type.color.withValues(alpha: 0.2)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: r.type.color.withValues(alpha: 0.15),
              child: Icon(r.type.icon, color: r.type.color, size: 20),
            ),
            title: Row(
              children: [
                Text(r.type.label, style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 13)),
                if (r.resolved) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: const Text('RESOLVED', style: TextStyle(color: AppTheme.teal, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.description, style: const TextStyle(color: AppTheme.grey, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (r.latitude != null) ...[
                      Icon(Icons.location_on, size: 10, color: AppTheme.grey),
                      const SizedBox(width: 2),
                    ],
                    Text(r.timeAgo, style: const TextStyle(color: AppTheme.grey, fontSize: 9)),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              color: AppTheme.surface,
              onSelected: (v) async {
                if (v == 'resolve') {
                  await _service.updateReport(r.id, resolved: !r.resolved);
                  _load();
                } else if (v == 'delete') {
                  await _service.deleteReport(r.id);
                  _load();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'resolve', child: Text(r.resolved ? 'Mark Unresolved' : 'Mark Resolved', style: const TextStyle(color: AppTheme.teal))),
                PopupMenuItem(value: 'delete', child: const Text('Delete', style: TextStyle(color: AppTheme.red))),
              ],
            ),
          ),
        );
      },
    );
  }
}
