import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/ai_engine.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/services/voice_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:rakshak_ai/ui/family_screen.dart';
import 'package:rakshak_ai/ui/widgets/ai_badge.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hindi = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AppLang.load().then((_) {
      if (mounted) {
        setState(() {
          _hindi = AppLang.hindi;
          _loaded = true;
        });
      }
    });
  }

  Future<void> _setHindi(bool value) async {
    await AppLang.setHindi(value);
    final voice = VoiceService();
    voice.setLanguage(
        value ? VoiceLanguage.hindi : VoiceLanguage.english);
    if (mounted) setState(() => _hindi = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppTheme.navy,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final lang = _hindi;
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(Strings.settings, style: const TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(lang ? 'भाषा' : 'Language'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _LangTile(
                  label: 'हिंदी',
                  selected: _hindi,
                  onTap: () => _setHindi(true),
                ),
                _LangTile(
                  label: 'English',
                  selected: !_hindi,
                  onTap: () => _setHindi(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(lang ? 'बीकन प्राप्तकर्ता' : 'Beacon recipients'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang
                      ? 'बीकन SMS उन परिवार सदस्यों को जाते हैं जिनका फ़ोन नंबर आपने परिवार बोर्ड में जोड़ा है। कोई सदस्य न हो तो 108 पर भेजा जाएगा।'
                      : 'Beacon SMS go to family members with a phone number on your board. With no members, beacons go to 108.',
                  style: const TextStyle(
                      color: AppTheme.grey, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FamilyScreen()),
                    ),
                    icon: const Icon(Icons.family_restroom, size: 16),
                    label: Text(lang ? 'परिवार बोर्ड खोलें' : 'Open Family Board'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(lang ? 'ऑन-डिवाइस AI' : 'On-device AI'),
          _AiSection(lang: lang),
          const SizedBox(height: 20),
          _SectionTitle(lang ? 'ऐप जानकारी' : 'About'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_moon_outlined,
                        color: AppTheme.saffronLight, size: 20),
                    const SizedBox(width: 10),
                    Text(lang ? 'रक्षक v2.1' : 'RAKSHAK v2.1',
                        style: const TextStyle(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  lang
                      ? '• ऑन-डिवाइस Gemma AI — इंटरनेट के बिना\n• बीकन SMS — इंटरनेट के बिना\n• पहले 10 मिनट के बचाव निर्देश\n• आधिकारिक चेतावनी सरल भाषा में\n• परिवार बोर्ड — इंटरनेट के बिना'
                      : '• On-device Gemma AI — no internet\n• Beacon SMS — no internet needed\n• First-10-minutes survival guides\n• Official alerts in plain language\n• Family board — works offline',
                  style: const TextStyle(
                      color: AppTheme.grey, fontSize: 12, height: 1.7),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Works in Hindi & English · No account · No tracking',
                  style: TextStyle(color: AppTheme.grey, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
            color: AppTheme.saffronLight,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1),
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(label, style: const TextStyle(color: AppTheme.white)),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppTheme.saffron, size: 20)
          : const Icon(Icons.circle_outlined, color: AppTheme.grey, size: 20),
    );
  }
}

/// Transparent AI status: users can see whether the on-device model is
/// loaded, how fast it is, and whether vision is available on this phone.
class _AiSection extends StatefulWidget {
  final bool lang;
  const _AiSection({required this.lang});

  @override
  State<_AiSection> createState() => _AiSectionState();
}

class _AiSectionState extends State<_AiSection> {
  final _ai = AiEngine();
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await _ai.initializeInBackground();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final state = _ai.state;
    final ready = state == AiState.ready;

    final description = switch (state) {
      AiState.ready => lang
          ? 'Gemma इस फ़ोन पर चल रहा है। चेतावनी, आवाज़ और सवाल — सब इंटरनेट के बिना।'
          : 'Gemma is running on this phone. Warnings, voice and questions work without internet.',
      AiState.loading => lang
          ? 'मॉडल स्टोरेज से लोड हो रहा है…'
          : 'Loading the model from storage…',
      AiState.error => lang
          ? 'मॉडल लोड नहीं हुआ। सभी सुविधाएं सत्यापित नियमों से चल रही हैं।'
          : 'Model not loaded. Every feature still works using verified rules.',
      AiState.unavailable => lang
          ? 'AI मॉडल नहीं मिला। सभी सुविधाएं सत्यापित नियमों से चल रही हैं।'
          : 'AI model not found. Every feature works using verified rules.',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: (ready ? AppTheme.tealLight : AppTheme.saffronLight)
                .withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  color: ready ? AppTheme.tealLight : AppTheme.grey, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang ? 'AI स्थिति' : 'AI status',
                  style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
              AiStatusChip(state: state, hindi: lang),
            ],
          ),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(
                  color: AppTheme.grey, fontSize: 11, height: 1.5)),
          if (ready) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _metric('${_ai.totalInferences}', lang ? 'जवाब' : 'answers'),
                const SizedBox(width: 8),
                _metric(
                    _ai.avgLatencyMs <= 0
                        ? '—'
                        : '${_ai.avgLatencyMs.round()} ms',
                    lang ? 'औसत समय' : 'avg time'),
                const SizedBox(width: 8),
                _metric(
                    _ai.visionAvailable
                        ? (lang ? 'हाँ' : 'Yes')
                        : (lang ? 'नहीं' : 'No'),
                    lang ? 'कैमरा AI' : 'vision'),
              ],
            ),
          ],
          if (state == AiState.error && _ai.lastError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _ai.lastError,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.red, fontSize: 9),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _retrying ? null : _retry,
              icon: _retrying
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 15),
              label: Text(
                _retrying
                    ? (lang ? 'लोड हो रहा है…' : 'Loading…')
                    : (lang ? 'AI दोबारा लोड करें' : 'Retry AI load'),
                style: const TextStyle(fontSize: 11),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AppTheme.tealLight.withValues(alpha: 0.45)),
                foregroundColor: AppTheme.tealLight,
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lang
                ? 'मॉडल फ़ाइल: Download/gemma-4-E2B-it.litertlm (केवल एक बार डालें)'
                : 'Model file: Download/gemma-4-E2B-it.litertlm (install once)',
            style: const TextStyle(color: AppTheme.grey, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(color: AppTheme.grey, fontSize: 8)),
          ],
        ),
      ),
    );
  }
}
