import 'package:flutter/material.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:rakshak_ai/ui/first_aid_screen.dart';
import 'package:rakshak_ai/ui/emergency_contacts_screen.dart';
import 'package:rakshak_ai/ui/im_safe_screen.dart';
import 'package:rakshak_ai/ui/incident_report_screen.dart';
import 'package:rakshak_ai/ui/offline_maps_screen.dart';
import 'package:rakshak_ai/ui/settings_screen.dart';
import 'package:rakshak_ai/ui/widgets/wreckage_analyzer.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'DISASTER RESPONSE TOOLS',
            style: TextStyle(color: AppTheme.grey, fontSize: 9, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.4,
              children: [
                _toolTile(
                  context,
                  icon: Icons.radar,
                  label: "I'M SAFE",
                  sublabel: 'Family Reunification',
                  color: AppTheme.teal,
                  screen: const ImSafeScreen(),
                ),
                _toolTile(
                  context,
                  icon: Icons.medical_services_outlined,
                  label: 'FIRST AID',
                  sublabel: '17 Emergency Protocols',
                  color: AppTheme.chakraBlue,
                  screen: const FirstAidScreen(),
                ),
                _toolTile(
                  context,
                  icon: Icons.contact_phone,
                  label: 'EMERGENCY #',
                  sublabel: '108, 112, 100, 101...',
                  color: AppTheme.red,
                  screen: const EmergencyContactsScreen(),
                ),
                _toolTile(
                  context,
                  icon: Icons.report_gmailerrorred,
                  label: 'INCIDENTS',
                  sublabel: 'Report & Track',
                  color: AppTheme.yellow,
                  screen: const IncidentReportScreen(),
                ),
                _toolTile(
                  context,
                  icon: Icons.explore_outlined,
                  label: 'OFFLINE MAP',
                  sublabel: 'Resources Near You',
                  color: AppTheme.saffronLight,
                  screen: const OfflineMapsScreen(),
                ),
                _toolTile(
                  context,
                  icon: Icons.remove_red_eye_outlined,
                  label: 'STRUCTURE SCAN',
                  sublabel: 'GPU Required (Premium)',
                  color: AppTheme.chakraBlue,
                  screen: const WreckageAnalyzer(),
                ),
                _toolTile(
                  context,
                  icon: Icons.tune,
                  label: 'SETTINGS',
                  sublabel: 'Configure & Export',
                  color: AppTheme.grey,
                  screen: const SettingsScreen(),
                ),
                _quickActionTile(
                  context,
                  icon: Icons.call,
                  label: 'DIAL 112',
                  sublabel: 'Pan-India Emergency',
                  color: AppTheme.red,
                  phone: '112',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_outlined, color: AppTheme.grey, size: 10),
              const SizedBox(width: 6),
              Text(
                'COMPLETELY OFFLINE · NO INTERNET NEEDED',
                style: TextStyle(color: AppTheme.grey, fontSize: 8, letterSpacing: 2),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'रक्षक AI v1.0 · Powered by Gemma 4',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.grey, fontSize: 8, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _toolTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required Widget screen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text(sublabel, style: TextStyle(color: AppTheme.grey, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required String phone,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), AppTheme.surface],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dialing $phone...'), backgroundColor: color),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2)),
              const SizedBox(height: 2),
              Text(sublabel, style: const TextStyle(color: AppTheme.grey, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}
