import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:rakshak_ai/ui/home_screen.dart';
import 'package:rakshak_ai/ui/map/offline_map_screen.dart';
import 'package:rakshak_ai/ui/beacon_screen.dart';
import 'package:rakshak_ai/ui/alerts_screen.dart';
import 'package:rakshak_ai/ui/more_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTab { home, map, beacon, alerts, more }

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
    _showFirstRunGuide();
  }

  Future<void> _showFirstRunGuide() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('guide_shown_v2') ?? false;
    if (seen || !mounted) return;
    await prefs.setBool('guide_shown_v2', true);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'रक्षक — ऑफ़लाइन आपदा साथी',
          style: TextStyle(
              color: AppTheme.saffronLight, letterSpacing: 1, fontSize: 16),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GuideRow(
                icon: Icons.home_outlined,
                title: 'HOME',
                desc: 'Alerts, family status, survival guides at a glance'),
            _GuideRow(
                icon: Icons.map_outlined,
                title: 'MAP',
                desc: 'Offline map with GPS, accuracy, go-to and backtrack. '
                    'Works with no network.'),
            _GuideRow(
                icon: Icons.campaign,
                title: 'BEACON',
                desc: '3 buttons — SAFE / NEED HELP / EVACUATE. '
                    'Sends SMS with your GPS to family. Works without internet.'),
            _GuideRow(
                icon: Icons.warning_amber,
                title: 'ALERTS',
                desc: 'Official IMD/CWC warnings. Rules give exact actions; '
                    'AI is optional.'),
            _GuideRow(
                icon: Icons.grid_view,
                title: 'MORE',
                desc: 'Family board, First-10-Minutes, AI Pack Manager, '
                    'Where Am I, emergency numbers'),
            SizedBox(height: 12),
            Text(
              'Map and safety rules work offline with no model. AI is opt-in. '
              'No account. No tracking.',
              style: TextStyle(
                  color: AppTheme.grey, fontSize: 11, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('समझ गया / GOT IT'),
          ),
        ],
      ),
    );
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  String get _title {
    switch (_currentIndex) {
      case 0:
        return 'रक्षक  RAKSHAK';
      case 1:
        return AppLang.hindi ? 'ऑफ़लाइन मैप' : 'OFFLINE MAP';
      case 2:
        return Strings.beacon.toUpperCase();
      case 3:
        return Strings.alerts.toUpperCase();
      case 4:
        return Strings.more.toUpperCase();
      default:
        return 'रक्षक  RAKSHAK';
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
              letterSpacing: 3,
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          OfflineMapScreen(),
          BeaconScreen(),
          AlertsScreen(),
          MoreScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.surfaceLight)),
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
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), label: 'HOME'),
            BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined), label: 'MAP'),
            BottomNavigationBarItem(
                icon: Icon(Icons.campaign), label: 'BEACON'),
            BottomNavigationBarItem(
                icon: Icon(Icons.warning_amber), label: 'ALERTS'),
            BottomNavigationBarItem(
                icon: Icon(Icons.grid_view), label: 'MORE'),
          ],
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _GuideRow({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.saffronLight, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1)),
                Text(desc,
                    style: const TextStyle(
                        color: AppTheme.grey, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
