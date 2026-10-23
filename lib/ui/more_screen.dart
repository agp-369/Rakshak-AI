import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/beacon_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:rakshak_ai/ui/emergency_contacts_screen.dart';
import 'package:rakshak_ai/ui/family_screen.dart';
import 'package:rakshak_ai/ui/settings_screen.dart';
import 'package:rakshak_ai/ui/survival_screen.dart';
import 'package:rakshak_ai/ui/where_am_i_screen.dart';

/// "More" — everything else, laid out as a simple guided list.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = AppLang.hindi;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MenuItem(
          icon: Icons.menu_book,
          color: AppTheme.chakraBlue,
          title: lang
              ? 'पहले 10 मिनट + AI से पूछें'
              : 'First 10 Minutes + Ask AI',
          subtitle: lang
              ? 'बाढ़, भूस्खलन, भूकंप, खून, फंसना — या अपनी स्थिति AI से पूछें'
              : 'Flood, landslide, earthquake, bleeding, trapped — or ask AI',
          onTap: () => _push(context, const SurvivalScreen()),
        ),
        _MenuItem(
          icon: Icons.family_restroom,
          color: AppTheme.tealLight,
          title: lang ? 'परिवार बोर्ड' : 'Family Board',
          subtitle: lang
              ? 'हर सदस्य की स्थिति — ऑफ़लाइन सेव'
              : "Track each member's status — saved offline",
          onTap: () => _push(context, const FamilyScreen()),
        ),
        _MenuItem(
          icon: Icons.my_location,
          color: AppTheme.saffronLight,
          title: lang ? 'मैं कहाँ हूँ' : 'Where Am I',
          subtitle: lang
              ? 'रेडियो/हेलीकॉप्टर को बताने के लिए बड़े नंबरों में स्थान'
              : 'Giant coordinates to relay to rescue teams',
          onTap: () => _push(context, const WhereAmIScreen()),
        ),
        _MenuItem(
          icon: Icons.contact_phone,
          color: AppTheme.red,
          title: Strings.emergencyNumbers,
          subtitle: lang
              ? '108, 112, 100, 101, 1078 और अधिक'
              : '108, 112, 100, 101, 1078 and more',
          onTap: () => _push(context, const EmergencyContactsScreen()),
        ),
        _MenuItem(
          icon: Icons.history,
          color: AppTheme.grey,
          title: lang ? 'भेजे गए बीकन' : 'Beacon history',
          subtitle: lang
              ? 'अब तक भेजे गए संदेश और उनकी स्थिति'
              : 'Messages sent so far and their status',
          onTap: () => _push(context, const BeaconHistoryScreen()),
        ),
        _MenuItem(
          icon: Icons.battery_saver,
          color: AppTheme.green,
          title: lang ? 'बैटरी मोड' : 'Battery mode',
          subtitle: lang
              ? 'कम रोशनी, कम चमक — बैटरी बचाने के लिए'
              : 'Dim screen and reduce animations to save battery',
          onTap: () => _showBatteryMode(context),
        ),
        _MenuItem(
          icon: Icons.settings,
          color: AppTheme.grey,
          title: Strings.settings,
          subtitle: lang
              ? 'भाषा, बीकन प्राप्तकर्ता, ऐप जानकारी'
              : 'Language, beacon recipients, about',
          onTap: () => _push(context, const SettingsScreen()),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            lang
                ? 'रक्षक v2 · ऑफ़लाइन आपदा साथी'
                : 'RAKSHAK v2 · Offline Disaster Companion',
            style: const TextStyle(color: AppTheme.grey, fontSize: 11),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showBatteryMode(BuildContext context) {
    final lang = AppLang.hindi;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.battery_saver, color: AppTheme.green),
                const SizedBox(width: 10),
                Text(lang ? 'बैटरी मोड' : 'Battery mode',
                    style: const TextStyle(
                        color: AppTheme.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              lang
                  ? 'आपदा में बिजली नहीं होती। बैटरी बचाने के लिए:\n\n• ब्राइटनेस कम करें\n• अनावश्यक ऐप बंद करें\n• फ़ोन को सीधी धूप से दूर रखें\n• हर भेजे गए बीकन के बाद स्क्रीन बंद करें\n• बीकन भेजने के लिए SMS — इंटरनेट बंद रखें ताकि बैटरी बचे'
                  : 'In a disaster there is no power. To save battery:\n\n• Lower screen brightness\n• Close unused apps\n• Keep the phone out of direct sun\n• Turn the screen off after each beacon\n• Beacons use SMS — keep mobile data off to save battery',
              style: const TextStyle(
                  color: AppTheme.grey, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(lang ? 'समझ गया' : 'Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: AppTheme.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: AppTheme.grey,
                              fontSize: 11,
                              height: 1.3)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// History of sent beacons — useful to confirm what went out and when.
class BeaconHistoryScreen extends StatefulWidget {
  const BeaconHistoryScreen({super.key});

  @override
  State<BeaconHistoryScreen> createState() => _BeaconHistoryScreenState();
}

class _BeaconHistoryScreenState extends State<BeaconHistoryScreen> {
  final _service = BeaconService();
  List<BeaconRecord> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await _service.getHistory();
    if (mounted) {
      setState(() {
        _history = h;
        _loading = false;
      });
    }
  }

  Future<void> _clear() async {
    await _service.clearHistory();
    await _load();
  }

  Color _color(BeaconType t) => Color(t.colorValue);

  @override
  Widget build(BuildContext context) {
    final lang = AppLang.hindi;
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(lang ? 'भेजे गए बीकन' : 'Beacon history',
            style: const TextStyle(fontSize: 15)),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clear,
              tooltip: 'Clear',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _history.isEmpty
              ? Center(
                  child: Text(
                    lang ? 'अभी कोई बीकन नहीं भेजा' : 'No beacons sent yet',
                    style: const TextStyle(color: AppTheme.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, i) {
                    final r = _history[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border(left: BorderSide(color: _color(r.type), width: 4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(r.type.labelEn,
                                  style: TextStyle(
                                      color: _color(r.type),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              const Spacer(),
                              Icon(
                                r.delivered
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                size: 15,
                                color: r.delivered
                                    ? AppTheme.green
                                    : AppTheme.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                r.delivered ? 'Sent' : 'Queued',
                                style: TextStyle(
                                    color: r.delivered
                                        ? AppTheme.green
                                        : AppTheme.red,
                                    fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(r.message,
                              style: const TextStyle(
                                  color: AppTheme.white,
                                  fontSize: 11,
                                  height: 1.4)),
                          const SizedBox(height: 4),
                          Text(
                            r.timestamp.toString().substring(0, 16),
                            style: const TextStyle(
                                color: AppTheme.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
