/// What the user wants, derived from speech (or later, typed input).
class Intent {
  final String action; // 'beacon_safe' | 'beacon_help' | 'beacon_evac' | 'open_survival' | 'where_am_i' | 'open_family' | 'open_alerts'
  final String? query;
  final Map<String, dynamic> params;

  const Intent(this.action, {this.query, this.params = const {}});

  @override
  String toString() => 'Intent($action, $query)';
}

/// Rule-based intent parser. Pure function of text — testable, instant,
/// zero-latency, works offline. The fine-tuned Gemma model will slot in
/// behind [VoiceIntentParser.parse] with the same signature later; the
/// rule engine stays as the always-available fallback (v1 lesson: model
/// must never be a dependency for a life-safety path).
class VoiceIntentParser {
  /// Map free-form speech (code-mixed Hindi/English, disaster context)
  /// to a structured [Intent]. Falls back to Intent('unknown') with the
  /// raw query attached so the UI can show it.
  static Intent parse(String text) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return const Intent('unknown');

    // Beacon intents — the three life-safety actions.
    if (_matches(t, safePatterns)) return const Intent('beacon_safe');
    if (_matches(t, helpPatterns)) return const Intent('beacon_help');
    if (_matches(t, evacPatterns)) return const Intent('beacon_evac');

    // Navigation intents.
    if (_matches(t, survivalPatterns)) {
      return Intent('open_survival', query: text);
    }
    if (_matches(t, whereAmIPatterns)) return const Intent('where_am_i');
    if (_matches(t, familyPatterns)) return const Intent('open_family');
    if (_matches(t, alertPatterns)) return const Intent('open_alerts');
    if (_matches(t, callPatterns)) {
      return Intent('open_sos', query: text);
    }

    // Default: if it looks like a survival question, open survival with query.
    if (t.split(' ').length >= 2) {
      return Intent('open_survival', query: text);
    }
    return Intent('unknown', query: text);
  }

  static bool _matches(String text, List<List<String>> families) {
    for (final family in families) {
      for (final keyword in family) {
        if (text.contains(keyword)) return true;
      }
    }
    return false;
  }

  // Each inner list is one semantic concept; any keyword in it matches.
  static const safePatterns = [
    ['safe', 'im safe', "i'm safe", 'i am fine', 'ठीक हूँ', 'सुरक्षित', 'मैं ठीक', 'sab theek', 'sab theek hai'],
  ];
  static const helpPatterns = [
    ['need help', 'help me', 'madad', 'मदद', 'बचाओ', 'bachao', 'bachao mujhe', 'फंसा', 'phansa', 'injured', 'घायल', 'ghayal'],
  ];
  static const evacPatterns = [
    ['evacuate', 'get out', 'निकालो', 'bahar', 'भागो', 'bhago', 'run', 'chhod do', 'leave now', 'खाली'],
  ];
  static const survivalPatterns = [
    ['what do i do', 'kya karun', 'क्या करूँ', 'guide', 'protocol', 'survival', 'landslide', 'flood', 'earthquake', 'भूकंप', 'बाढ़', 'भूस्खलन', 'bleeding', 'खून', 'heat'],
  ];
  static const whereAmIPatterns = [
    ['where am i', 'my location', 'coordinates', 'gps', 'mera location', 'मेरा स्थान', 'लोकेशन'],
  ];
  static const familyPatterns = [
    ['family', 'parivar', 'परिवार', 'wife', 'बीवी', 'father', 'पिता', 'mother', 'माँ', 'children', 'बच्चे'],
  ];
  static const alertPatterns = [
    ['alert', 'warning', 'चेतावनी', 'imd', 'weather', 'मौसम', 'sanket'],
  ];
  static const callPatterns = [
    ['call', 'phone', 'dial', '108', 'कॉल', 'फोन'],
  ];
}
