import 'package:flutter/material.dart';
import 'package:rakshak_ai/data/survival_scenarios.dart';
import 'package:rakshak_ai/services/ai_engine.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/services/voice_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:rakshak_ai/ui/widgets/ai_badge.dart';
import 'package:rakshak_ai/ui/widgets/voice_input_button.dart';

/// "First 10 Minutes" — scenario-first survival guides plus "Ask Rakshak",
/// the on-device AI that answers a plain-language question using only the
/// bundled NDMA/WHO knowledge base. Every answer is cited.
class SurvivalScreen extends StatefulWidget {
  const SurvivalScreen({super.key});

  @override
  State<SurvivalScreen> createState() => _SurvivalScreenState();
}

class _SurvivalScreenState extends State<SurvivalScreen> {
  final _controller = TextEditingController();
  final _tts = VoiceService();
  AiAnswer? _answer;
  String? _asked;
  bool _asking = false;
  bool _speaking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask([String? preset]) async {
    final q = (preset ?? _controller.text).trim();
    if (q.isEmpty || _asking) return;
    if (preset != null) _controller.text = preset;
    setState(() {
      _asking = true;
      _asked = q;
      _answer = null;
    });
    final res =
        await AiEngine().answerSurvival(q, hindi: AppLang.hindi);
    if (!mounted) return;
    setState(() {
      _asking = false;
      _answer = res;
    });
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
    final lang = AppLang.hindi;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          lang ? 'पहले 10 मिनट' : 'First 10 Minutes',
          style: const TextStyle(
              color: AppTheme.white, fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          lang
              ? 'सबसे पहले क्या करें — एक-एक कदम। पूरी तरह ऑफ़लाइन।'
              : 'What to do first — step by step. Fully offline.',
          style: const TextStyle(color: AppTheme.grey, fontSize: 12),
        ),
        const SizedBox(height: 14),
        _AskRakshakCard(
          lang: lang,
          controller: _controller,
          asking: _asking,
          asked: _asked,
          answer: _answer,
          speaking: _speaking,
          onAsk: _ask,
          onSpeak: _speak,
          onVoice: (t) => _ask(t),
        ),
        const SizedBox(height: 20),
        ...survivalScenarios.map((s) => _ScenarioCard(scenario: s, lang: lang)),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _AskRakshakCard extends StatelessWidget {
  final bool lang;
  final TextEditingController controller;
  final bool asking;
  final String? asked;
  final AiAnswer? answer;
  final bool speaking;
  final ValueChanged<String?> onAsk;
  final ValueChanged<String> onSpeak;
  final ValueChanged<String> onVoice;

  const _AskRakshakCard({
    required this.lang,
    required this.controller,
    required this.asking,
    required this.asked,
    required this.answer,
    required this.speaking,
    required this.onAsk,
    required this.onSpeak,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = lang
        ? const [
            'पानी बढ़ रहा है',
            'खून बह रहा है',
            'मलबे में फंसा हूँ',
            'रात में बाढ़ आई',
          ]
        : const [
            'Flood water is rising',
            'Bleeding heavily',
            'Trapped in debris',
            'Night flood warning',
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.teal.withValues(alpha: 0.22),
            AppTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.tealLight.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: AppTheme.tealLight, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang ? 'रक्षक से पूछें' : 'Ask Rakshak',
                  style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900),
                ),
              ),
              AiStatusChip(state: AiEngine().state, hindi: lang),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            lang
                ? 'अपनी स्थिति अपने शब्दों में लिखें या बोलें — जवाब NDMA/WHO निर्देशों से, फ़ोन पर ही।'
                : 'Type or speak your situation — answered from NDMA/WHO guidance, on the phone.',
            style: const TextStyle(
                color: AppTheme.grey, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                      color: AppTheme.white, fontSize: 13),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onAsk(null),
                  decoration: InputDecoration(
                    hintText: lang
                        ? 'जैसे: पानी कमरे में आ रहा है…'
                        : 'e.g. water is entering my room…',
                    hintStyle: const TextStyle(
                        color: AppTheme.grey, fontSize: 12),
                    filled: true,
                    fillColor: AppTheme.navy.withValues(alpha: 0.55),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              VoiceInputButton(onResult: onVoice, size: 40),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestions
                .map((s) => ActionChip(
                      backgroundColor: AppTheme.surfaceLight,
                      side: BorderSide(
                          color: AppTheme.tealLight.withValues(alpha: 0.3)),
                      label: Text(s,
                          style: const TextStyle(
                              color: AppTheme.white, fontSize: 10)),
                      onPressed: () => onAsk(s),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: asking ? null : () => onAsk(null),
              icon: asking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 16),
              label: Text(
                asking
                    ? (lang ? 'सोच रहा है…' : 'Thinking…')
                    : (lang ? 'जवाब पाएं' : 'Get answer'),
              ),
            ),
          ),
          if (asked != null) ...[
            const SizedBox(height: 14),
            const Divider(color: AppTheme.surfaceLight),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '"$asked"',
                    style: const TextStyle(
                        color: AppTheme.grey,
                        fontSize: 11,
                        fontStyle: FontStyle.italic),
                  ),
                ),
                if (answer != null) AiBadge(source: answer!.source),
              ],
            ),
            const SizedBox(height: 8),
            if (asking)
              Row(
                children: [
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(
                    lang
                        ? 'ऑफ़लाइन ज्ञान से जवाब बन रहा है…'
                        : 'Building an answer from offline knowledge…',
                    style:
                        const TextStyle(color: AppTheme.grey, fontSize: 11),
                  ),
                ],
              )
            else if (answer != null) ...[
              Text(
                answer!.text,
                style: const TextStyle(
                    color: AppTheme.white, fontSize: 13, height: 1.55),
              ),
              if (answer!.citations.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${lang ? "स्रोत" : "Source"}: ${answer!.citations.join(" · ")}',
                  style: const TextStyle(
                      color: AppTheme.grey, fontSize: 10, height: 1.4),
                ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onSpeak(answer!.text),
                  icon: Icon(
                      speaking ? Icons.stop : Icons.volume_up,
                      size: 16,
                      color: AppTheme.saffronLight),
                  label: Text(
                    speaking
                        ? (lang ? 'रोकें' : 'Stop')
                        : (lang ? 'सुनें' : 'Listen'),
                    style: const TextStyle(
                        color: AppTheme.saffronLight, fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final SurvivalScenario scenario;
  final bool lang;
  const _ScenarioCard({required this.scenario, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SurvivalDetailScreen(scenario: scenario),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                  left: BorderSide(color: scenario.color, width: 4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scenario.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(scenario.icon, color: scenario.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    lang ? scenario.titleHi : scenario.titleEn,
                    style: const TextStyle(
                        color: AppTheme.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.3),
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

/// Detailed steps for one scenario, with TTS read-aloud.
class SurvivalDetailScreen extends StatefulWidget {
  final SurvivalScenario scenario;
  const SurvivalDetailScreen({super.key, required this.scenario});

  @override
  State<SurvivalDetailScreen> createState() => _SurvivalDetailScreenState();
}

class _SurvivalDetailScreenState extends State<SurvivalDetailScreen> {
  final _tts = VoiceService();
  bool _speaking = false;

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stopSpeaking();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final text = AppLang.hindi
        ? widget.scenario.speakHi
        : widget.scenario.speakEn;
    setState(() => _speaking = true);
    await _tts.speak(text);
    if (mounted) setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scenario;
    final lang = AppLang.hindi;
    final steps = lang ? s.immediateStepsHi : s.immediateStepsEn;
    final donts = lang ? s.dontsHi : s.dontsEn;

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(lang ? s.titleHi : s.titleEn,
            style: const TextStyle(fontSize: 14)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [s.color, s.color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(s.icon, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    lang ? s.titleHi : s.titleEn,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _toggleSpeak,
              icon: Icon(_speaking ? Icons.stop : Icons.volume_up,
                  color: AppTheme.saffronLight, size: 18),
              label: Text(
                _speaking
                    ? (lang ? 'रोकें' : 'Stop')
                    : (lang ? 'सुनें' : 'Listen aloud'),
                style: const TextStyle(color: AppTheme.saffronLight),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.saffron),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            lang ? 'अभी करें' : 'DO NOW',
            style: const TextStyle(
                color: AppTheme.green,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map((e) => _StepRow(
                number: e.key + 1,
                text: e.value,
                color: AppTheme.green,
              )),
          const SizedBox(height: 20),
          Text(
            lang ? 'बिल्कुल न करें' : 'NEVER DO',
            style: const TextStyle(
                color: AppTheme.red,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          ...donts.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.close, color: AppTheme.red, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(d,
                          style: const TextStyle(
                              color: AppTheme.white,
                              fontSize: 13,
                              height: 1.45)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final String text;
  final Color color;
  const _StepRow({
    required this.number,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('$number',
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppTheme.white, fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
