import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rakshak_ai/services/gemma_service.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/services/mesh_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:rakshak_ai/ui/widgets/wreckage_analyzer.dart';
import 'package:rakshak_ai/ui/medical_triage_screen.dart' as medical;
import 'package:rakshak_ai/ui/offline_maps_screen.dart';
import 'package:rakshak_ai/ui/settings_screen.dart';
import 'package:rakshak_ai/ui/sos_screen.dart';
import 'package:rakshak_ai/ui/first_aid_screen.dart';
import 'package:rakshak_ai/ui/im_safe_screen.dart';
import 'package:rakshak_ai/ui/emergency_contacts_screen.dart';
import 'package:rakshak_ai/ui/incident_report_screen.dart';

class TriageDashboard extends StatefulWidget {
  final bool isEmbedded;
  const TriageDashboard({super.key, this.isEmbedded = false});

  @override
  State<TriageDashboard> createState() => _TriageDashboardState();
}

class _TriageDashboardState extends State<TriageDashboard>
    with SingleTickerProviderStateMixin {
  final GemmaInferenceService _gemma = GemmaInferenceService();
  final GpsService _gps = GpsService();
  bool _isInitializing = true;
  bool _gpsReady = false;
  String _statusMessage = 'Waking engine...';
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _initSystem();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _initSystem() async {
    try {
      setState(() => _statusMessage = '${Strings.appTitle} Engine…');
      await _gemma.initialize();
      setState(() => _statusMessage = 'Acquiring GPS...');
      _gpsReady = await _gps.initialize();
    } catch (e) {
      _statusMessage = 'System error';
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
        _statusMessage = _gpsReady ? 'Rakshak AI Active — Ready' : 'GPS Signal Lost — Triage available';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildBody();
    }
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppTheme.saffronLight, AppTheme.saffron],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'RAKSHAK  AI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                  fontSize: 22,
                ),
              ),
            ),
            backgroundColor: AppTheme.navy,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.hub_outlined, color: AppTheme.saffronLight),
                onPressed: () => _showSystemStatus(context),
                tooltip: 'System Status',
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppTheme.grey),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                tooltip: 'Settings',
              ),
            ],
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusHeader(),
        const SizedBox(height: 24),
        _buildHeroTriageCard(),
        const SizedBox(height: 24),
        _buildToolGrid(),
        const Spacer(),
        _buildFooter(),
      ],
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.saffron.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          _isInitializing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.saffron),
                  ),
                )
              : AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) => Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.teal.withValues(alpha: 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.teal.withValues(alpha: 0.2 + _glowController.value * 0.2),
                          blurRadius: 8 + _glowController.value * 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.radar, color: AppTheme.teal, size: 16),
                  ),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusMessage.toUpperCase(),
                  style: TextStyle(
                    color: _statusMessage.contains('Lost') ? AppTheme.saffronLight : AppTheme.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'भारत का आपदा सुरक्षा कवच',
                  style: TextStyle(color: AppTheme.grey, fontSize: 9, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
          _buildOfflineBadge(),
        ],
      ),
    );
  }

  Widget _buildOfflineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 10, color: AppTheme.teal),
          SizedBox(width: 4),
          Text(
            'OFFLINE',
            style: TextStyle(
              color: AppTheme.teal,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTriageCard() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.saffron.withValues(alpha: 0.08 + _glowController.value * 0.04),
                AppTheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.saffron.withValues(alpha: 0.3 + _glowController.value * 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.saffron.withValues(alpha: 0.06 + _glowController.value * 0.06),
                blurRadius: 20 + _glowController.value * 10,
                spreadRadius: 2 + _glowController.value * 3,
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const medical.MedicalTriageScreen()),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.saffron, AppTheme.saffronDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.healing_outlined, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'MEDICAL TRIAGE',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.saffronLight,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI-powered START Protocol triage.\nWorks completely offline. No internet needed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.grey, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.saffron, AppTheme.saffronDark],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.saffron.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Text(
                      'BEGIN ASSESSMENT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.5,
      children: [
        _buildToolTile(
          icon: Icons.remove_red_eye_outlined,
          label: 'STRUCTURE SCAN',
          sublabel: 'GPU Required (Premium)',
          color: AppTheme.chakraBlue,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WreckageAnalyzer())),
        ),
        _buildToolTile(
          icon: Icons.sos,
          label: 'SOS BEACON',
          sublabel: 'Emergency Alert',
          color: AppTheme.red,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen())),
        ),
        _buildToolTile(
          icon: Icons.qr_code_scanner,
          label: 'MESH SYNC',
          sublabel: 'QR Data Share',
          color: AppTheme.teal,
          onTap: () => _showSyncDialog(context),
        ),
        _buildToolTile(
          icon: Icons.explore_outlined,
          label: 'OFFLINE MAP',
          sublabel: 'Resources Near You',
          color: AppTheme.saffronLight,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflineMapsScreen())),
        ),
        _buildToolTile(
          icon: Icons.medical_services_outlined,
          label: 'FIRST AID',
          sublabel: '17 Emergency Protocols',
          color: AppTheme.chakraBlue,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FirstAidScreen())),
        ),
        _buildToolTile(
          icon: Icons.radar,
          label: "I'M SAFE",
          sublabel: 'Family Reunification',
          color: AppTheme.teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImSafeScreen())),
        ),
        _buildToolTile(
          icon: Icons.contact_phone,
          label: 'EMERGENCY #',
          sublabel: '108, 112, 100, 101...',
          color: AppTheme.red,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsScreen())),
        ),
        _buildToolTile(
          icon: Icons.report_gmailerrorred,
          label: 'INCIDENTS',
          sublabel: 'Report & Track',
          color: AppTheme.yellow,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncidentReportScreen())),
        ),
      ],
    );
  }

  Widget _buildToolTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: const TextStyle(color: AppTheme.grey, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: AppTheme.surfaceLight),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_outlined, color: AppTheme.grey, size: 12),
            const SizedBox(width: 6),
            Text(
              'COMPLETELY OFFLINE · NO INTERNET NEEDED',
              style: TextStyle(color: AppTheme.grey, fontSize: 9, letterSpacing: 2.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'रक्षक AI v1.0 · Powered by Gemma 4',
          style: TextStyle(color: AppTheme.grey, fontSize: 8, letterSpacing: 1),
        ),
      ],
    );
  }

  // ---- Dialog helpers ----

  void _showSyncDialog(BuildContext context) {
    final mesh = MeshService();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('MESH SYNC', style: TextStyle(color: AppTheme.saffronLight, letterSpacing: 2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share patient data with nearby responders via QR code.',
              style: TextStyle(color: AppTheme.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final payload = await mesh.generateSyncPayload();
                  if (!ctx.mounted) return;
                  if (payload == null) {
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Too many patients for QR sync. Reduce count or use Import/Export.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  _showQrCode(context, payload);
                },
                icon: const Icon(Icons.qr_code, size: 18),
                label: const Text('GENERATE EXPORT QR'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showImportDialog(context);
                },
                icon: const Icon(Icons.download, size: 18),
                label: const Text('IMPORT FROM QR SCAN'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.saffronLight,
                  side: const BorderSide(color: AppTheme.saffronLight),
                ),
              ),
            ),
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

  void _showQrCode(BuildContext context, String payload) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('SCAN TO SYNC', style: TextStyle(color: AppTheme.saffronLight)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Show this QR to another responder.',
              style: TextStyle(color: AppTheme.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${payload.length} chars | ${(payload.length * 0.75).round()} bytes',
              style: const TextStyle(color: AppTheme.grey, fontSize: 10),
            ),
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

  void _showImportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('IMPORT SYNC', style: TextStyle(color: AppTheme.saffronLight)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste QR content received from another device, or scan using QR Scanner.',
              style: TextStyle(color: AppTheme.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Paste sync payload here...',
                isDense: true,
              ),
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final mesh = MeshService();
              final count = await mesh.processSyncPayload(controller.text.trim());
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(count > 0
                      ? 'Imported $count patients'
                      : count == 0
                          ? 'No new patients to import'
                          : 'Invalid sync data'),
                  backgroundColor: count > 0 ? AppTheme.teal : AppTheme.red,
                ),
              );
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showSystemStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('System Status', style: TextStyle(color: AppTheme.saffronLight)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusRow('Gemma 4 Engine', _gemma.isInitialized ? 'Ready' : 'Offline'),
            _statusRow('GPS', _gpsReady ? 'Acquired' : 'Unavailable'),
            _statusRow('Model', _gemma.isModelLoaded ? 'Loaded' : 'Not loaded'),
            _statusRow('Inferences', '${_gemma.totalInferences}'),
            if (_gemma.lastError.isNotEmpty) _statusRow('Last Error', _gemma.lastError),
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

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.white)),
          Text(value, style: const TextStyle(color: AppTheme.grey)),
        ],
      ),
    );
  }
}
