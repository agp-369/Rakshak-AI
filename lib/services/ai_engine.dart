import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rakshak_ai/data/disaster_knowledge.dart';
import 'package:rakshak_ai/data/survival_scenarios.dart';
import 'package:rakshak_ai/models/model_pack.dart';
import 'package:rakshak_ai/services/alert_service.dart';
import 'package:rakshak_ai/services/model_download_service.dart';
import 'package:rakshak_ai/services/voice_intent.dart';

/// Where an answer came from. Shown to the user, so AI output is never
/// silently passed off as a rule and vice versa.
enum AiSource { ai, rule }

/// Lifecycle of the on-device model. UI shows this so users understand
/// when they are getting model reasoning vs. deterministic guidance.
enum AiState { unavailable, loading, ready, error }

class DeviceCapabilities {
  DeviceCapabilities._();
  static const _channel = MethodChannel('rakshak_ai/device');

  static bool _supportsVision = false;
  static bool _isLowRam = false;

  static Future<void> initialize() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _supportsVision = await _channel.invokeMethod<bool>('hasGpu') ?? false;
        _isLowRam = await _channel.invokeMethod<bool>('isLowRamDevice') ?? false;
      }
    } catch (_) {
      _supportsVision = false;
      _isLowRam = false;
    }
  }

  static bool get supportsVision => _supportsVision;
  static bool get isLowRam => _isLowRam;
  static int get maxTokens => isLowRam ? 512 : 1024;
  static bool get enableSpeculativeDecoding => !isLowRam;
  static PreferredBackend get preferredBackend =>
      supportsVision ? PreferredBackend.gpu : PreferredBackend.cpu;
}

/// A single AI (or fallback) answer with provenance and citations.
class AiAnswer {
  final String text;
  final AiSource source;
  final double confidence;
  final List<String> citations;
  final Duration latency;
  final String? error;

  const AiAnswer({
    required this.text,
    required this.source,
    this.confidence = 0.7,
    this.citations = const [],
    this.latency = Duration.zero,
    this.error,
  });

  bool get isAi => source == AiSource.ai;
}

/// Structured interpretation of an official warning.
class AlertInterpretation {
  final String hazard;
  final AlertSeverity severity;
  final List<String> actions;
  final List<String> donts;
  final String speakText;
  final AiSource source;

  const AlertInterpretation({
    required this.hazard,
    required this.severity,
    required this.actions,
    required this.donts,
    required this.speakText,
    required this.source,
  });
}

/// Structured reading of a distressed voice message.
class DistressResult {
  final String intent; // beacon_safe | beacon_help | beacon_evac | open_survival | unknown
  final bool injured;
  final bool trapped;
  final int people;
  final String? landmark;
  final String summary;
  final AiSource source;

  const DistressResult({
    required this.intent,
    required this.summary,
    this.injured = false,
    this.trapped = false,
    this.people = 1,
    this.landmark,
    this.source = AiSource.rule,
  });
}

enum AiVisionTask { readSign, assessVisibleCondition }

/// The on-device AI layer.
///
/// Design contract:
///  * The model is the PRIMARY path for every intelligent decision.
///  * Every method has a deterministic fallback so the app never fails
///    silently when the model is absent, low on battery, or throttled.
///  * Nothing here ever blocks the UI or a life-safety action.
class AiEngine {
  static final AiEngine _instance = AiEngine._internal();
  factory AiEngine() => _instance;
  AiEngine._internal();

  InferenceModel? _model;
  AiState _state = AiState.unavailable;
  String _status = 'AI model not installed';
  String _lastError = '';
  int _totalInferences = 0;
  double _avgLatencyMs = 0;

  AiState get state => _state;
  ModelTier? _activeTier;
  ModelTier? get activeTier => _activeTier;

  bool get isReady => _state == AiState.ready && _model != null;
  String get status => _status;
  String get lastError => _lastError;
  int get totalInferences => _totalInferences;
  double get avgLatencyMs => _avgLatencyMs;
  bool get visionAvailable =>
      isReady && DeviceCapabilities.supportsVision && _activeTier == ModelTier.full;

  /// Load the model in the background. AI is opt-in in field-first v2.
  Future<void> initializeInBackground() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final enabled = sp.getBool('ai_enabled') == true;
      if (!enabled) {
        _model = null;
        _activeTier = null;
        _setState(AiState.unavailable, 'AI unloaded — running deterministic safety rules (0 MB RAM)');
        return;
      }

      final savedTierId = sp.getString('active_model_tier');
      final tier = ModelTier.values.firstWhere(
        (t) => t.id == savedTierId,
        orElse: () => DeviceCapabilities.isLowRam ? ModelTier.tiny : ModelTier.small,
      );

      await loadModelTier(tier);
    } catch (e) {
      debugPrint('[AiEngine] ai_enabled load failed: $e');
      _model = null;
      _activeTier = null;
      _setState(AiState.unavailable, 'AI unloaded — rule mode');
    }
  }

  /// Load a specific model tier into RAM.
  Future<void> loadModelTier(ModelTier tier, {String? customPath}) async {
    if (_state == AiState.loading) return;
    _setState(AiState.loading, 'Loading ${tier.displayNameEn} into RAM…');

    try {
      try {
        await FlutterGemma.initialize();
      } catch (_) {}
      await DeviceCapabilities.initialize();

      String? targetPath = customPath;
      targetPath ??= await findModelFileForTier(tier);
      if (targetPath == null) {
        throw StateError('Model file ${tier.modelFile} not found in app storage or Download folder');
      }

      // Close previous model if loaded
      await unloadModel(saveDisabledPreference: false);

      await FlutterGemma.installModel(
        modelType: tier.gemmaModelType,
        fileType: ModelFileType.litertlm,
      ).fromFile(targetPath).install();

      _model = await FlutterGemma.getActiveModel(
        maxTokens: DeviceCapabilities.maxTokens,
        preferredBackend: DeviceCapabilities.preferredBackend,
        supportImage: tier == ModelTier.full && DeviceCapabilities.supportsVision,
        maxNumImages: (tier == ModelTier.full && DeviceCapabilities.supportsVision) ? 1 : 0,
        enableSpeculativeDecoding: DeviceCapabilities.enableSpeculativeDecoding,
      );

      _activeTier = tier;
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('ai_enabled', true);
      await sp.setString('active_model_tier', tier.id);

      _setState(AiState.ready, 'AI ready — on-device (${tier.displayNameEn})');
    } catch (e) {
      _lastError = e.toString();
      _model = null;
      _activeTier = null;
      _setState(AiState.error, 'Running in rule mode: $e');
      rethrow;
    }
  }

  Future<void> unloadModel({bool saveDisabledPreference = true}) async {
    try {
      _model = null;
      _activeTier = null;
      try {
        final obj = FlutterGemma as dynamic;
        if (obj != null) {
          try { await obj.closeActiveModel(); } catch (_) {}
          try { await obj.clearActiveModel(); } catch (_) {}
          try { await obj.close(); } catch (_) {}
        }
      } catch (_) {}

      if (saveDisabledPreference) {
        final sp = await SharedPreferences.getInstance();
        await sp.setBool('ai_enabled', false);
      }
      _setState(AiState.unavailable, 'AI unloaded — running deterministic safety rules (0 MB RAM)');
    } catch (e) {
      debugPrint('[AiEngine] unload error: $e');
    }
  }

  Future<String?> findModelFileForTier(ModelTier tier) async {
    final downloadService = ModelDownloadService();
    final installedFile = await downloadService.getInstalledFile(tier);
    if (installedFile != null) return installedFile.path;

    final downloadFolderFile = await downloadService.getDownloadFolderFile(tier);
    if (downloadFolderFile != null) return downloadFolderFile.path;

    return null;
  }

  void _setState(AiState state, String status) {
    if (state == _state && status == _status) return;
    _state = state;
    _status = status;
    debugPrint('[AiEngine] state: $_state, status: $_status');
  }

  // ---------------------------------------------------------------------
  // Core generation
  // ---------------------------------------------------------------------

  Future<String?> _generate(
    String prompt, {
    String? system,
    int maxTokens = 512,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (!isReady) return null;
    final stopwatch = Stopwatch()..start();
    try {
      final session = await _model!.createSession();
      final full = system == null ? prompt : '$system\n\n$prompt';
      await session.addQueryChunk(Message.text(text: full, isUser: true));
      final text = await session.getResponse().timeout(timeout);
      await session.close();
      stopwatch.stop();
      _totalInferences++;
      _avgLatencyMs = (_avgLatencyMs * (_totalInferences - 1) +
              stopwatch.elapsedMilliseconds) /
          _totalInferences;
      return text;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[AI] generation failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // 1. Alert -> Action (the last-mile interpreter)
  // ---------------------------------------------------------------------

  static const _alertSystem =
      'You are Rakshak, an offline disaster assistant for rural India. '
      'You convert official weather/disaster warnings into short, safe, '
      'actionable instructions. You never invent facts. You never give '
      'medical diagnoses. Reply with JSON only.';

  Future<AlertInterpretation> interpretAlert({
    required String officialText,
    required AlertSeverity severity,
    required String hazardHint,
    required bool hindi,
  }) async {
    final rule = _ruleInterpretation(officialText, severity, hazardHint, hindi);
    if (!isReady) return rule;

    final prompt = '''
Official warning: "$officialText"
Hazard: $hazardHint
Severity: ${severity.name}
Return JSON with keys:
"hazard": one of rain, flood, landslide, earthquake, cyclone, heatwave, lightning, tsunami,
"severity": red|orange|yellow|green,
"actions": array of 3 short imperative steps in ${hindi ? 'Hindi (Devanagari)' : 'English'},
"donts": array of 2 things NOT to do,
"speak": one sentence to read aloud.
Keep each step under 12 words. JSON only.''';

    final raw = await _generate(prompt,
        system: _alertSystem, maxTokens: 400, timeout: const Duration(seconds: 35));
    final json = _extractJson(raw);
    if (json == null) return rule;

    try {
      final actions = (json['actions'] as List?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .take(4)
              .toList() ??
          [];
      if (actions.isEmpty) return rule;
      final donts = (json['donts'] as List?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .take(3)
              .toList() ??
          [];
      return AlertInterpretation(
        hazard: (json['hazard'] ?? hazardHint).toString(),
        severity: _parseSeverity((json['severity'] ?? severity.name).toString()),
        actions: actions,
        donts: donts,
        speakText: (json['speak'] ?? actions.first).toString(),
        source: AiSource.ai,
      );
    } catch (_) {
      return rule;
    }
  }

  AlertInterpretation _ruleInterpretation(
    String officialText,
    AlertSeverity severity,
    String hazardHint,
    bool hindi,
  ) {
    final text = AlertTranslator.translate(
      hazardType: hazardHint,
      severity: severity,
      officialText: officialText,
      hindi: hindi,
    );
    final scenario = findScenario(hazardHint);
    final steps = scenario == null
        ? [text]
        : (hindi ? scenario.immediateStepsHi : scenario.immediateStepsEn)
            .take(3)
            .toList();
    final donts = scenario == null
        ? <String>[]
        : (hindi ? scenario.dontsHi : scenario.dontsEn).take(2).toList();
    return AlertInterpretation(
      hazard: hazardHint,
      severity: severity,
      actions: steps,
      donts: donts,
      speakText: text,
      source: AiSource.rule,
    );
  }

  // ---------------------------------------------------------------------
  // 2. Distress voice -> structured intent (beacon + protocol routing)
  // ---------------------------------------------------------------------

  Future<DistressResult> parseDistress(String spoken, {required bool hindi}) async {
    final rule = _ruleDistress(spoken, hindi);
    if (!isReady) return rule;

    final prompt = '''
A person in a disaster just said (may be Hindi, English or mixed): "$spoken"
Return JSON with keys:
"intent": beacon_safe | beacon_help | beacon_evac | open_survival | unknown,
"injured": true/false,
"trapped": true/false,
"people": number of people affected (default 1),
"landmark": any place name mentioned or null,
"summary": one short sentence in ${hindi ? 'Hindi' : 'English'}.
JSON only.''';

    final raw = await _generate(prompt,
        system: _alertSystem, maxTokens: 220, timeout: const Duration(seconds: 25));
    final json = _extractJson(raw);
    if (json == null) return rule;
    try {
      final intent = (json['intent'] ?? rule.intent).toString();
      return DistressResult(
        intent: _validIntent(intent) ? intent : rule.intent,
        summary: (json['summary'] ?? rule.summary).toString(),
        injured: json['injured'] == true || rule.injured,
        trapped: json['trapped'] == true || rule.trapped,
        people: (json['people'] is num)
            ? (json['people'] as num).toInt().clamp(1, 500).toInt()
            : rule.people,
        landmark: json['landmark']?.toString(),
        source: AiSource.ai,
      );
    } catch (_) {
      return rule;
    }
  }

  DistressResult _ruleDistress(String spoken, bool hindi) {
    final intent = VoiceIntentParser.parse(spoken);
    final lower = spoken.toLowerCase();
    final numbers = RegExp(r'\b(\d{1,3})\b').firstMatch(spoken);
    return DistressResult(
      intent: intent.action,
      summary: spoken.trim().isEmpty
          ? (hindi ? 'संदेश समझ नहीं आया' : 'Could not understand the message')
          : spoken.trim(),
      injured: lower.contains('injured') ||
          lower.contains('bleed') ||
          spoken.contains('घायल') ||
          spoken.contains('खून'),
      trapped: lower.contains('trapped') ||
          lower.contains('buried') ||
          spoken.contains('फंस') ||
          spoken.contains('मलबा'),
      people: numbers == null ? 1 : int.tryParse(numbers.group(1)!) ?? 1,
      source: AiSource.rule,
    );
  }

  // ---------------------------------------------------------------------
  // 3. Grounded survival Q&A (RAG over offline NDMA/WHO knowledge)
  // ---------------------------------------------------------------------

  Future<AiAnswer> answerSurvival(String question, {required bool hindi}) async {
    final chunks = KnowledgeRetriever.search(question, limit: 3);
    final citations = chunks.map((c) => c.source).toSet().toList();

    if (chunks.isEmpty) {
      return AiAnswer(
        text: hindi
            ? 'इस सवाल के लिए सटीक निर्देश नहीं मिला। कृपया स्थिति बताएं (बाढ़, भूस्खलन, खून, फंसना) या 108 पर कॉल करें।'
            : 'I could not find a specific instruction for that. Please name the situation (flood, landslide, bleeding, trapped) or call 108.',
        source: AiSource.rule,
        confidence: 0.3,
      );
    }

    // Always have a deterministic, cited answer available first.
    final ruleAnswer = hindi
        ? '${chunks.first.titleHi}: ${chunks.first.textHi}'
        : '${chunks.first.titleEn}: ${chunks.first.textEn}';

    if (!isReady) {
      return AiAnswer(
        text: ruleAnswer,
        source: AiSource.rule,
        confidence: 0.7,
        citations: citations,
      );
    }

    final context = chunks
        .map((c) => hindi ? '${c.titleHi}: ${c.textHi}' : '${c.titleEn}: ${c.textEn}')
        .join('\n\n');

    final prompt = '''
Use ONLY the reference notes below to answer the question in 3 short sentences.
If the notes do not cover it, say you are not sure and tell them to call 108.
Answer in ${hindi ? 'Hindi (Devanagari)' : 'English'}.

REFERENCE NOTES:
$context

QUESTION: $question''';

    final raw = await _generate(prompt,
        system:
            'You are a careful offline disaster first-aid guide. Answer only from the notes. No diagnosis, no guessing.',
        maxTokens: 320,
        timeout: const Duration(seconds: 40));

    if (raw == null || raw.trim().length < 10) {
      return AiAnswer(
        text: ruleAnswer,
        source: AiSource.rule,
        confidence: 0.7,
        citations: citations,
      );
    }

    return AiAnswer(
      text: raw.trim(),
      source: AiSource.ai,
      confidence: 0.8,
      citations: citations,
    );
  }

  // ---------------------------------------------------------------------
  // 4. Multimodal vision (scoped to what vision can do safely)
  // ---------------------------------------------------------------------

  Future<AiAnswer> analyzeImage(
    Uint8List imageBytes, {
    required AiVisionTask task,
    required bool hindi,
  }) async {
    if (!visionAvailable) {
      return AiAnswer(
        text: hindi
            ? 'इस फ़ोन पर कैमरा-आधारित AI उपलब्ध नहीं है। ऊपर दिए गए कदम मानें या 108 पर कॉल करें।'
            : 'Camera AI is not available on this phone. Follow the steps shown or call 108.',
        source: AiSource.rule,
        confidence: 0.2,
        error: 'Vision requires GPU/NPU',
      );
    }

    final prompt = task == AiVisionTask.readSign
        ? 'Read any official warning sign or notice in this image. Translate it to '
            '${hindi ? 'Hindi' : 'English'} and state the single most important action. '
            'If there is no sign, say so.'
        : 'Look only at VISIBLE signs (bleeding, burns, unconscious, trapped, '
            'swelling). Do NOT diagnose. Say which first-aid protocol card applies '
            'and the immediate action, in ${hindi ? 'Hindi' : 'English'}.';

    try {
      final session = await _model!.createSession();
      await session.addQueryChunk(
          Message.withImage(text: prompt, imageBytes: imageBytes, isUser: true));
      final text =
          await session.getResponse().timeout(const Duration(seconds: 45));
      await session.close();
      return AiAnswer(
        text: text.trim(),
        source: AiSource.ai,
        confidence: 0.65,
      );
    } catch (e) {
      return AiAnswer(
        text: hindi
            ? 'तस्वीर पढ़ी नहीं जा सकी। कृपया दिए गए कदम मानें या 108 पर कॉल करें।'
            : 'Could not read the image. Follow the steps shown or call 108.',
        source: AiSource.rule,
        confidence: 0.2,
        error: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------
  // 5. Situation synthesis — alerts + family + time -> one brief
  // ---------------------------------------------------------------------

  Future<AiAnswer> synthesizeSituation({
    required List<String> activeHazards,
    required int familyNeedingHelp,
    required int familyUnknown,
    required bool night,
    required bool hindi,
  }) async {
    final rule = _ruleBrief(
      activeHazards: activeHazards,
      familyNeedingHelp: familyNeedingHelp,
      familyUnknown: familyUnknown,
      night: night,
      hindi: hindi,
    );
    if (!isReady) return rule;

    final prompt = '''
Write a 2-sentence situation brief in ${hindi ? 'Hindi' : 'English'} for a
person in a disaster with these facts. Be calm and specific about the next action.
Active hazards: ${activeHazards.isEmpty ? 'none' : activeHazards.join(', ')}
Family needing help: $familyNeedingHelp. Family with no contact: $familyUnknown.
Time: ${night ? 'night' : 'day'}.''';

    final raw = await _generate(prompt,
        system: _alertSystem, maxTokens: 160, timeout: const Duration(seconds: 25));
    if (raw == null || raw.trim().isEmpty) return rule;
    return AiAnswer(
      text: raw.trim(),
      source: AiSource.ai,
      confidence: 0.75,
    );
  }

  AiAnswer _ruleBrief({
    required List<String> activeHazards,
    required int familyNeedingHelp,
    required int familyUnknown,
    required bool night,
    required bool hindi,
  }) {
    if (familyNeedingHelp > 0) {
      return AiAnswer(
        text: hindi
            ? 'परिवार में $familyNeedingHelp को मदद चाहिए — बीकन भेजें और उनका स्थान साझा करें।'
            : '$familyNeedingHelp family member(s) need help — send a beacon and share their location.',
        source: AiSource.rule,
      );
    }
    if (activeHazards.isNotEmpty) {
      final h = activeHazards.first;
      return AiAnswer(
        text: hindi
            ? '$h के लिए सक्रिय चेतावनी है। पहले 10 मिनट के कदम देखें और ऊँची जगह तैयार रखें।${night ? ' रात है — अभी निकलने की तैयारी रखें।' : ''}'
            : 'There is an active $h warning. Follow the first-10-minutes steps and keep higher ground ready.${night ? ' It is night — be ready to leave now.' : ''}',
        source: AiSource.rule,
      );
    }
    return AiAnswer(
      text: hindi
          ? 'अभी कोई सक्रिय खतरा नहीं। परिवार बोर्ड जोड़ें और बीकन तैयार रखें।'
          : 'No active hazard right now. Add your family board and keep a beacon ready.',
      source: AiSource.rule,
    );
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  static Map<String, dynamic>? _extractJson(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    text = text.substring(start, end + 1);
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static AlertSeverity _parseSeverity(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('red')) return AlertSeverity.red;
    if (lower.contains('orange')) return AlertSeverity.orange;
    if (lower.contains('yellow')) return AlertSeverity.yellow;
    return AlertSeverity.green;
  }

  static bool _validIntent(String value) => const {
        'beacon_safe',
        'beacon_help',
        'beacon_evac',
        'open_survival',
        'unknown',
      }.contains(value);
}
