import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/ai_engine.dart';
import 'package:rakshak_ai/services/alert_service.dart';
import 'package:rakshak_ai/services/family_board_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/services/voice_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:rakshak_ai/ui/widgets/ai_badge.dart';

/// Home dashboard. Answers, at a glance: what's happening (alerts),
/// is my family okay (board summary), and what should I do (quick guides).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<HazardAlert> _alerts = [];
  List<FamilyMember> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await AlertService().getCached();
    final members = await FamilyBoardService().getMembers();
    if (!mounted) return;
    setState(() {
      _alerts = cached.where((a) => a.isActive).toList();
      _members = members;
      _loading = false;
    });
  }

  Color _sevColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.red:
        return AppTheme.red;
      case AlertSeverity.orange:
        return AppTheme.saffron;
      case AlertSeverity.yellow:
        return AppTheme.yellow;
      case AlertSeverity.green:
        return AppTheme.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLang.hindi;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusBanner(alerts: _alerts, members: _members, lang: lang),
          const SizedBox(height: 12),
          _AiBriefCard(alerts: _alerts, members: _members, lang: lang),
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.warning_amber,
            title: lang ? 'सक्रिय चेतावनी' : 'Active alerts',
            color: AppTheme.saffronLight,
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if (_alerts.isEmpty)
            _InfoTile(
              icon: Icons.check_circle_outline,
              color: AppTheme.green,
              title: lang ? 'कोई सक्रिय चेतावनी नहीं' : 'No active alerts',
              subtitle: lang
                  ? 'ALERTS टैब में जाकर IMD से ताज़ा जानकारी पाएं'
                  : 'Open the ALERTS tab for fresh IMD updates',
            )
          else
            ..._alerts.take(3).map((a) => _AlertMini(
                  alert: a,
                  color: _sevColor(a.severity),
                  lang: lang,
                )),
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.family_restroom,
            title: lang ? 'परिवार की स्थिति' : 'Family status',
            color: AppTheme.tealLight,
          ),
          const SizedBox(height: 8),
          if (_members.isEmpty)
            _InfoTile(
              icon: Icons.person_add,
              color: AppTheme.tealLight,
              title: lang ? 'अभी कोई सदस्य नहीं' : 'No members added yet',
              subtitle: lang
                  ? 'MORE → परिवार बोर्ड में जोड़ें'
                  : 'Add them in MORE → Family Board',
            )
          else
            Row(
              children: [
                _StatChip(
                  label: lang ? 'सुरक्षित' : 'Safe',
                  count: _members
                      .where((m) => m.status == MemberStatus.safe)
                      .length,
                  color: AppTheme.green,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: lang ? 'मदद चाहिए' : 'Need help',
                  count: _members
                      .where((m) => m.status == MemberStatus.needHelp)
                      .length,
                  color: AppTheme.red,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: lang ? 'संपर्क नहीं' : 'No contact',
                  count: _members
                      .where((m) => m.status == MemberStatus.unknown)
                      .length,
                  color: AppTheme.grey,
                ),
              ],
            ),
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.menu_book,
            title: lang ? 'पहले 10 मिनट' : 'First 10 Minutes',
            color: AppTheme.chakraBlue,
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.help_outline,
            color: AppTheme.chakraBlue,
            title: lang ? 'तुरंत क्या करें?' : 'What do I do right now?',
            subtitle: lang
                ? 'MORE → बचाव निर्देश में हर आपदा के लिए कदम'
                : 'Open MORE → Survival Guides for step-by-step actions',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final List<HazardAlert> alerts;
  final List<FamilyMember> members;
  final bool lang;
  const _StatusBanner(
      {required this.alerts, required this.members, required this.lang});

  @override
  Widget build(BuildContext context) {
    final hasRed = alerts.any((a) => a.severity == AlertSeverity.red);
    final hasHelp =
        members.any((m) => m.status == MemberStatus.needHelp);
    final color = hasRed || hasHelp ? AppTheme.red : AppTheme.teal;

    final status = hasRed
        ? (lang ? 'खतरा — तुरंत कार्रवाई करें' : 'DANGER — act now')
        : hasHelp
            ? (lang ? 'परिवार को मदद चाहिए' : 'Family needs help')
            : (lang ? 'अभी कोई खतरा नहीं' : 'No immediate danger');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            hasRed || hasHelp ? Icons.warning : Icons.shield_moon_outlined,
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  lang
                      ? 'हर काम ऑफ़लाइन चलता है — बीकन इंटरनेट के बिना भी भेजें'
                      : 'Everything works offline — beacon sends without internet',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertMini extends StatelessWidget {
  final HazardAlert alert;
  final Color color;
  final bool lang;
  const _AlertMini(
      {required this.alert, required this.color, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${alert.hazardType.toUpperCase()} — ${alert.area}',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            alert.actionText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppTheme.white, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader(
      {required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
              color: AppTheme.white,
              fontSize: 14,
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _InfoTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
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

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/// The AI situation brief: synthesises alerts + family board + time of day
/// into one calm, spoken instruction. Falls back to a rule-written brief
/// instantly when the model is still loading or unavailable.
class _AiBriefCard extends StatefulWidget {
  final List<HazardAlert> alerts;
  final List<FamilyMember> members;
  final bool lang;

  const _AiBriefCard(
      {required this.alerts, required this.members, required this.lang});

  @override
  State<_AiBriefCard> createState() => _AiBriefCardState();
}

class _AiBriefCardState extends State<_AiBriefCard> {
  final _tts = VoiceService();
  late Future<AiAnswer> _future;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _future = _run();
  }

  @override
  void didUpdateWidget(covariant _AiBriefCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alerts != widget.alerts ||
        oldWidget.members != widget.members ||
        oldWidget.lang != widget.lang) {
      _future = _run();
    }
  }

  Future<AiAnswer> _run() {
    final hour = DateTime.now().hour;
    return AiEngine().synthesizeSituation(
      activeHazards:
          widget.alerts.map((a) => a.hazardType).toSet().toList(),
      familyNeedingHelp: widget.members
          .where((m) => m.status == MemberStatus.needHelp)
          .length,
      familyUnknown: widget.members
          .where((m) => m.status == MemberStatus.unknown)
          .length,
      night: hour < 6 || hour >= 19,
      hindi: widget.lang,
    );
  }

  Future<void> _speak(String text) async {
    if (_speaking) {
      await _tts.stopSpeaking();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await _tts.speak(text);
    if (mounted) setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return FutureBuilder<AiAnswer>(
      future: _future,
      builder: (context, snap) {
        final answer = snap.data;
        final text = answer?.text ??
            (lang ? 'स्थिति पढ़ी जा रही है…' : 'Reading your situation…');
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppTheme.tealLight.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: AppTheme.tealLight, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang ? 'AI स्थिति संक्षेप' : 'AI situation brief',
                      style: const TextStyle(
                          color: AppTheme.tealLight,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (answer != null) AiBadge(source: answer.source, compact: true),
                  const SizedBox(width: 4),
                  if (answer != null)
                    GestureDetector(
                      onTap: () => _speak(answer.text),
                      child: Icon(
                        _speaking ? Icons.stop_circle : Icons.volume_up,
                        color: AppTheme.saffronLight,
                        size: 18,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                text,
                style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }
}
