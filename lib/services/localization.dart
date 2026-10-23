import 'package:shared_preferences/shared_preferences.dart';

/// Simple language preference backed by SharedPreferences.
/// Hindi-first is the default for disaster-facing copy —
/// the audience this app is built for reads Hindi.
class AppLang {
  static bool _hindi = true;
  static bool get hindi => _hindi;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _hindi = prefs.getBool('use_hindi') ?? true;
  }

  static Future<void> setHindi(bool value) async {
    _hindi = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_hindi', value);
  }
}

class Strings {
  static bool get _hi => AppLang.hindi;

  static String get appTitle => _hi ? 'रक्षक' : 'RAKSHAK';
  static String get tagline =>
      _hi ? 'ऑफ़लाइन आपदा साथी' : 'Offline Disaster Companion';
  static String get home => _hi ? 'होम' : 'HOME';
  static String get beacon => _hi ? 'बीकन' : 'BEACON';
  static String get alerts => _hi ? 'चेतावनी' : 'ALERTS';
  static String get more => _hi ? 'और' : 'MORE';
  static String get family => _hi ? 'परिवार' : 'FAMILY';
  static String get settings => _hi ? 'सेटिंग्स' : 'Settings';
  static String get sos => _hi ? 'SOS' : 'SOS';
  static String get cancel => _hi ? 'रद्द करें' : 'Cancel';
  static String get confirm => _hi ? 'पुष्टि करें' : 'Confirm';
  static String get delete => _hi ? 'हटाएं' : 'Delete';
  static String get save => _hi ? 'सहेजें' : 'Save';
  static String get back => _hi ? 'वापस' : 'Back';
  static String get loading => _hi ? 'लोड हो रहा है...' : 'Loading...';
  static String get error => _hi ? 'त्रुटि' : 'Error';
  static String get success => _hi ? 'सफल' : 'Success';
  static String get retry => _hi ? 'पुनः प्रयास करें' : 'Retry';
  static String get done => _hi ? 'हो गया' : 'Done';
  static String get english => _hi ? 'अंग्रेज़ी' : 'English';
  static String get hindi => _hi ? 'हिंदी' : 'Hindi';
  static String get languageSettings => _hi ? 'भाषा' : 'Language';
  static String get whereAmI => _hi ? 'मैं कहाँ हूँ' : 'WHERE AM I';
  static String get firstTenMinutes =>
      _hi ? 'पहले 10 मिनट' : 'FIRST 10 MINUTES';
  static String get emergencyNumbers =>
      _hi ? 'आपातकालीन नंबर' : 'Emergency Numbers';
  static String get batteryMode => _hi ? 'बैटरी मोड' : 'BATTERY MODE';
  static String get about => _hi ? 'ऐप के बारे में' : 'About';
  static String get appVersion => _hi ? 'ऐप वर्जन' : 'App Version';
  static String get familyBoard => _hi ? 'परिवार बोर्ड' : 'Family Board';
  static String get officialAlerts =>
      _hi ? 'आधिकारिक चेतावनी' : 'Official Alerts';
  static String get survivalGuides =>
      _hi ? 'बचाव निर्देश' : 'Survival Guides';
}
