import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rakshak_ai/services/ai_engine.dart';
import 'package:rakshak_ai/services/alert_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/services/voice_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:rakshak_ai/ui/widgets/ai_badge.dart';

/// Official alerts screen. Fetches IMD/CWC warnings when online, caches
/// them, and serves the cache offline. Each alert is rewritten into
/// plain-language action by the on-device model (with a verified rule
/// fallback), and the badge tells the user which one produced the text.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _service = AlertService();
  List<HazardAlert> _alerts = [];
  DateTime? _lastFetch;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final cached = await _service.getCached();
    if (mounted) setState(() => _alerts = cached);

    try {
      final fresh = await _service.fetchAlerts(
        timeout: const Duration(seconds: 8),
      );
      if (!mounted) return;
      setState(() {
        _alerts = fresh;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_alerts.isEmpty) _error = e.toString();
      });
    }
    final t = await _service.lastFetchTime();
    if (mounted) setState(() => _lastFetch = t);
  }

  Color _severityColor(AlertSeverity s) {
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

  Future<void> _speak(HazardAlert a) async {
    final tts = VoiceService();
    await tts.speak(a.actionText);
  }

  Future<void> _explain(HazardAlert a) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExplainSheet(
        alert: a,
        lang: AppLang.hindi,
        color: _severityColor(a.severity),
      ),
    );
  }

  /// Scoped vision: read an official sign/notice the user cannot read and
  /// turn it into a plain-language action. This is the one place a camera
  /// is genuinely safer than guessing — not structural analysis.
  Future<void> _readSign() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1440,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SignSheet(
        imageBytes: bytes,
        lang: AppLang.hindi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLang.hindi;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber,
                  color: AppTheme.saffronLight, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang
                      ? 'आधिकारिक चेतावनी — IMD / NDMA'
                      : 'Official alerts — IMD / NDMA',
                  style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
              AiStatusChip(state: AiEngine().state, hindi: lang),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.grey),
                onPressed: _load,
                tooltip: 'Refresh',
              ),
            ],
          ),
          if (_lastFetch != null)
            Text(
              lang
                  ? 'अंतिम अपडेट: ${_lastFetch.toString().substring(0, 16)}'
                  : 'Last updated: ${_lastFetch.toString().substring(0, 16)}',
              style: const TextStyle(color: AppTheme.grey, fontSize: 11),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _readSign,
              icon: const Icon(Icons.document_scanner_outlined, size: 15),
              label: Text(
                lang
                    ? 'बोर्ड/सूचना की फोटो पढ़ें — AI'
                    : 'Read a warning board photo — AI',
                style: const TextStyle(fontSize: 11),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.tealLight,
                side: BorderSide(
                    color: AppTheme.tealLight.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading && _alerts.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if (_alerts.isEmpty)
            _EmptyAlerts(lang: lang, error: _error)
          else
            ..._alerts.map((a) => _AlertCard(
                  alert: a,
                  color: _severityColor(a.severity),
                  lang: lang,
                  onSpeak: () => _speak(a),
                  onExplain: () => _explain(a),
                )),
          const SizedBox(height: 24),
          Text(
            lang
                ? 'चेतावनी न मिलने का मतलब खतरा नहीं — हालात तेज़ी से बदलते हैं। रेडियो और स्थानीय सूचना पर भी भरोसा करें।'
                : 'No alert shown does not mean no danger — conditions change fast. Also trust local radio and official announcements.',
            style: const TextStyle(color: AppTheme.grey, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final HazardAlert alert;
  final Color color;
  final bool lang;
  final VoidCallback onSpeak;
  final VoidCallback onExplain;

  const _AlertCard({
    required this.alert,
    required this.color,
    required this.lang,
    required this.onSpeak,
    required this.onExplain,
  });

  String get _hazardEmoji {
    switch (alert.hazardType) {
      case 'flood':
      case 'flashflood':
        return '🌊';
      case 'landslide':
        return '⛰️';
      case 'earthquake':
        return '🌍';
      case 'cyclone':
        return '🌀';
      case 'heatwave':
        return '🔥';
      case 'lightning':
        return '⚡';
      default:
        return '🌧️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = lang
        ? alert.actionText
        : alert.actionText;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_hazardEmoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${alert.hazardType.toUpperCase()} — ${alert.area}',
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    alert.source,
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              action,
              style: const TextStyle(
                  color: AppTheme.white, fontSize: 13, height: 1.5),
            ),
            if (alert.officialText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${lang ? "आधिकारिक" : "Official"}: ${alert.officialText}',
                style: const TextStyle(
                    color: AppTheme.grey, fontSize: 11, height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onExplain,
                icon: const Icon(Icons.auto_awesome, size: 15),
                label: Text(
                  lang ? 'AI से समझें — अभी क्या करें' : 'Explain with AI — what to do',
                  style: const TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.tealLight,
                  side: BorderSide(
                      color: AppTheme.tealLight.withValues(alpha: 0.45)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 12, color: AppTheme.grey),
                const SizedBox(width: 4),
                Text(
                  alert.issuedAt.toString().substring(0, 16),
                  style: const TextStyle(color: AppTheme.grey, fontSize: 10),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.volume_up,
                      size: 18, color: AppTheme.saffronLight),
                  onPressed: onSpeak,
                  tooltip: lang ? 'सुनें' : 'Listen',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  final bool lang;
  final String? error;
  const _EmptyAlerts({required this.lang, this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off,
              color: AppTheme.grey.withValues(alpha: 0.6), size: 40),
          const SizedBox(height: 12),
          Text(
            lang ? 'कोई चेतावनी कैश नहीं मिली' : 'No cached alerts found',
            style: const TextStyle(color: AppTheme.white, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            lang
                ? 'इंटरनेट होने पर चेतावनी अपने आप आ जाएंगी और सेव रहेंगी।'
                : 'When internet is available, alerts load and stay saved offline.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppTheme.grey, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// The AI "last mile" sheet: turns an arbitrary official warning into a
/// numbered action plan, with a visible AI/rule provenance badge.
class _ExplainSheet extends StatefulWidget {
  final HazardAlert alert;
  final bool lang;
  final Color color;

  const _ExplainSheet({
    required this.alert,
    required this.lang,
    required this.color,
  });

  @override
  State<_ExplainSheet> createState() => _ExplainSheetState();
}

class _ExplainSheetState extends State<_ExplainSheet> {
  final _tts = VoiceService();
  AlertInterpretation? _result;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final raw = widget.alert.officialText.trim().isEmpty
        ? widget.alert.actionText
        : widget.alert.officialText;
    final res = await AiEngine().interpretAlert(
      officialText: raw,
      severity: widget.alert.severity,
      hazardHint: widget.alert.hazardType,
      hindi: widget.lang,
    );
    if (mounted) setState(() => _result = res);
  }

  Future<void> _speak() async {
    final r = _result;
    if (r == null) return;
    if (_speaking) {
      await _tts.stopSpeaking();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await _tts.speak(r.speakText);
    if (mounted) setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final r = _result;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: widget.color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.alert.hazardType.toUpperCase()} · ${widget.alert.severity.name.toUpperCase()}',
                      style: TextStyle(
                          color: widget.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5),
                    ),
                  ),
                  if (r != null) AiBadge(source: r.source),
                ],
              ),
              if (r != null && r.hazard.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${lang ? "पहचाना गया खतरा" : "Detected hazard"}: ${r.hazard}',
                  style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                ),
              ],
              const SizedBox(height: 16),
              if (r == null)
                Row(
                  children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text(
                      lang
                          ? 'AI चेतावनी पढ़ रहा है…'
                          : 'AI is reading the warning…',
                      style: const TextStyle(
                          color: AppTheme.grey, fontSize: 12),
                    ),
                  ],
                )
              else ...[
                Text(
                  lang ? 'अभी करें' : 'DO NOW',
                  style: const TextStyle(
                      color: AppTheme.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                ...r.actions.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.green.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Text('${e.key + 1}',
                                style: const TextStyle(
                                    color: AppTheme.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(e.value,
                                style: const TextStyle(
                                    color: AppTheme.white,
                                    fontSize: 13,
                                    height: 1.45)),
                          ),
                        ],
                      ),
                    )),
                if (r.donts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    lang ? 'बिल्कुल न करें' : 'NEVER DO',
                    style: const TextStyle(
                        color: AppTheme.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  ...r.donts.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.close,
                                color: AppTheme.red, size: 15),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(d,
                                  style: const TextStyle(
                                      color: AppTheme.white,
                                      fontSize: 12,
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      )),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _speak,
                    icon: Icon(
                        _speaking ? Icons.stop : Icons.volume_up,
                        size: 16,
                        color: AppTheme.saffronLight),
                    label: Text(
                      _speaking
                          ? (lang ? 'रोकें' : 'Stop')
                          : (lang ? 'सुनें' : 'Listen aloud'),
                      style: const TextStyle(color: AppTheme.saffronLight),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.saffron),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Reads an official sign/notice photo with the on-device model and
/// returns a plain-language action. If vision is unavailable, the sheet
/// says so honestly instead of pretending.
class _SignSheet extends StatefulWidget {
  final Uint8List imageBytes;
  final bool lang;

  const _SignSheet({required this.imageBytes, required this.lang});

  @override
  State<_SignSheet> createState() => _SignSheetState();
}

class _SignSheetState extends State<_SignSheet> {
  final _tts = VoiceService();
  AiAnswer? _answer;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final res = await AiEngine().analyzeImage(
      widget.imageBytes,
      task: AiVisionTask.readSign,
      hindi: widget.lang,
    );
    if (mounted) setState(() => _answer = res);
  }

  Future<void> _speak() async {
    final a = _answer;
    if (a == null) return;
    if (_speaking) {
      await _tts.stopSpeaking();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await _tts.speak(a.text);
    if (mounted) setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final a = _answer;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.document_scanner_outlined,
                      color: AppTheme.tealLight, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang ? 'AI बोर्ड पढ़ रहा है' : 'AI is reading the board',
                      style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (a != null) AiBadge(source: a.source),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  widget.imageBytes,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 14),
              if (a == null)
                Row(
                  children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang
                            ? 'तस्वीर पढ़ी जा रही है… (फ़ोन पर ही)'
                            : 'Reading the image… (on this phone)',
                        style: const TextStyle(
                            color: AppTheme.grey, fontSize: 12),
                      ),
                    ),
                  ],
                )
              else ...[
                Text(
                  a.text,
                  style: const TextStyle(
                      color: AppTheme.white, fontSize: 13, height: 1.5),
                ),
                if (a.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    lang
                        ? 'कैमरा AI इस फ़ोन पर उपलब्ध नहीं। दिए गए कदम या 108 पर भरोसा करें।'
                        : 'Camera AI is not available on this phone. Follow the steps or call 108.',
                    style: const TextStyle(
                        color: AppTheme.grey, fontSize: 10, height: 1.4),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _speak,
                    icon: Icon(_speaking ? Icons.stop : Icons.volume_up,
                        size: 16, color: AppTheme.saffronLight),
                    label: Text(
                      _speaking
                          ? (lang ? 'रोकें' : 'Stop')
                          : (lang ? 'सुनें' : 'Listen aloud'),
                      style: const TextStyle(color: AppTheme.saffronLight),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.saffron),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
