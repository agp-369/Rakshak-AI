import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/gemma_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:rakshak_ai/ui/triage_dashboard.dart';
import 'package:rakshak_ai/ui/medical_triage_screen.dart' as medical;
import 'package:rakshak_ai/ui/sos_screen.dart';
import 'package:rakshak_ai/ui/menu_screen.dart';
import 'package:rakshak_ai/ui/settings_screen.dart';
import 'package:rakshak_ai/ui/im_safe_screen.dart';
import 'package:rakshak_ai/ui/first_aid_screen.dart';
import 'package:rakshak_ai/ui/emergency_contacts_screen.dart';
import 'package:rakshak_ai/ui/incident_report_screen.dart';
import 'package:rakshak_ai/ui/offline_maps_screen.dart';
import 'package:rakshak_ai/ui/widgets/wreckage_analyzer.dart';

enum AppTab { home, triage, sos, more }

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  String get _title {
    switch (_currentIndex) {
      case 0: return 'RAKSHAK  AI';
      case 1: return Strings.triage.toUpperCase();
      case 2: return Strings.sos.toUpperCase();
      case 3: return 'TOOLS';
      default: return 'RAKSHAK  AI';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.saffronLight, AppTheme.saffron],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            _title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.hub_outlined, color: AppTheme.saffronLight),
              onPressed: () => _showSystemStatus(context),
              tooltip: 'System Status',
            ),
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppTheme.grey),
              onPressed: () => _pushScreen(const SettingsScreen()),
              tooltip: 'Settings',
            ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          TriageDashboard(isEmbedded: true),
          medical.MedicalTriageScreen(),
          SosScreen(),
          MenuScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.surfaceLight, width: 1)),
      ),
      child: BottomNavigationBar(
        backgroundColor: AppTheme.navy,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.saffron,
        unselectedItemColor: AppTheme.grey,
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'HOME'),
          BottomNavigationBarItem(icon: Icon(Icons.healing_outlined), label: 'TRIAGE'),
          BottomNavigationBarItem(icon: Icon(Icons.sos), label: 'SOS'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'MORE'),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.navy, AppTheme.surfaceLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppTheme.saffron, AppTheme.teal],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.healing_outlined, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 12),
                const Text('RAKSHAK  AI', style: TextStyle(color: AppTheme.saffronLight, fontWeight: FontWeight.w900, letterSpacing: 3)),
                const SizedBox(height: 2),
                Text('भारत का आपदा सुरक्षा कवच', style: TextStyle(color: AppTheme.grey, fontSize: 11)),
                const SizedBox(height: 2),
                Text('Offline AI Disaster Response', style: TextStyle(color: AppTheme.grey, fontSize: 9)),
              ],
            ),
          ),
          _drawerItem(Icons.healing_outlined, 'Triage', () => _closeAndNavigate(1)),
          _drawerItem(Icons.sos, 'SOS Beacon', () => _closeAndNavigate(2)),
          _drawerItem(Icons.radar, "I'm Safe", () => _pushFromDrawer(const ImSafeScreen())),
          _drawerItem(Icons.medical_services_outlined, 'First Aid', () => _pushFromDrawer(const FirstAidScreen())),
          _drawerItem(Icons.contact_phone, 'Emergency Contacts', () => _pushFromDrawer(const EmergencyContactsScreen())),
          _drawerItem(Icons.report_gmailerrorred, 'Incident Reports', () => _pushFromDrawer(const IncidentReportScreen())),
          _drawerItem(Icons.explore_outlined, 'Offline Maps', () => _pushFromDrawer(const OfflineMapsScreen())),
          _drawerItem(Icons.remove_red_eye_outlined, 'Structure Scan', () => _pushFromDrawer(const WreckageAnalyzer())),
          const Divider(color: AppTheme.surfaceLight),
          _drawerItem(Icons.settings, 'Settings', () => _pushFromDrawer(const SettingsScreen())),
          _drawerItem(Icons.info_outline, 'About', () => _showAbout(context)),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.saffronLight, size: 20),
      title: Text(label, style: const TextStyle(color: AppTheme.white, fontSize: 13)),
      onTap: onTap,
      dense: true,
    );
  }

  void _closeAndNavigate(int tabIndex) {
    Navigator.pop(context);
    setState(() => _currentIndex = tabIndex);
  }

  void _pushFromDrawer(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _pushScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showSystemStatus(BuildContext context) {
    final gemma = GemmaInferenceService();
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
            _statusRow('Gemma 4 Engine', gemma.isInitialized ? 'Ready' : 'Offline'),
            _statusRow('Model', gemma.isModelLoaded ? 'Loaded' : 'Not loaded'),
            _statusRow('GPU Vision', DeviceCapabilities.supportsVision ? 'Available' : 'CPU-only'),
            _statusRow('Inferences', '${gemma.totalInferences}'),
            if (gemma.lastError.isNotEmpty) _statusRow('Last Error', gemma.lastError),
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.white, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ABOUT', style: TextStyle(color: AppTheme.saffronLight, letterSpacing: 2)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('रक्षक AI v1.0', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            Text('AI-powered offline disaster response for India.', style: TextStyle(color: AppTheme.grey, fontSize: 13)),
            SizedBox(height: 4),
            Text('• Gemma 4 E2B (5.15B) on-device', style: TextStyle(color: AppTheme.grey, fontSize: 12)),
            Text('• START Protocol triage engine', style: TextStyle(color: AppTheme.grey, fontSize: 12)),
            Text('• Hindi / English bilingual', style: TextStyle(color: AppTheme.grey, fontSize: 12)),
            Text('• Complete offline operation', style: TextStyle(color: AppTheme.grey, fontSize: 12)),
            Text('• Mesh QR sync for team coordination', style: TextStyle(color: AppTheme.grey, fontSize: 12)),
            SizedBox(height: 12),
            Text('Samsung Solve for Tomorrow 2026', style: TextStyle(color: AppTheme.saffronLight, fontSize: 11)),
            Text('Theme: AI Living for India', style: TextStyle(color: AppTheme.saffronLight, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: AppTheme.grey))),
        ],
      ),
    );
  }
}
