import 'gemma_service.dart';

class Strings {
  static bool get _hi => GemmaInferenceService.useHindi;

  static String get appTitle => _hi ? 'रक्षक AI' : 'Rakshak AI';
  static String get settings => _hi ? 'सेटिंग्स' : 'Settings';
  static String get triage => _hi ? 'ट्राइएज' : 'Triage';
  static String get dashboard => _hi ? 'डैशबोर्ड' : 'Dashboard';
  static String get sos => _hi ? 'SOS' : 'SOS';
  static String get patients => _hi ? 'मरीज़' : 'Patients';
  static String get offlineMaps => _hi ? 'ऑफ़लाइन मानचित्र' : 'Offline Maps';
  static String get scanQr => _hi ? 'QR स्कैन करें' : 'Scan QR';
  static String get syncData => _hi ? 'डेटा सिंक करें' : 'Sync Data';
  static String get addPatient => _hi ? 'मरीज़ जोड़ें' : 'Add Patient';
  static String get noPatients => _hi ? 'कोई मरीज़ नहीं' : 'No patients';
  static String get clearAll => _hi ? 'सब हटाएं' : 'Clear All';
  static String get cancel => _hi ? 'रद्द करें' : 'Cancel';
  static String get confirm => _hi ? 'पुष्टि करें' : 'Confirm';
  static String get delete => _hi ? 'हटाएं' : 'Delete';
  static String get edit => _hi ? 'संपादित करें' : 'Edit';
  static String get save => _hi ? 'सहेजें' : 'Save';
  static String get back => _hi ? 'वापस' : 'Back';
  static String get loading => _hi ? 'लोड हो रहा है...' : 'Loading...';
  static String get error => _hi ? 'त्रुटि' : 'Error';
  static String get success => _hi ? 'सफल' : 'Success';
  static String get search => _hi ? 'खोजें' : 'Search';
  static String get done => _hi ? 'हो गया' : 'Done';
  static String get retry => _hi ? 'पुनः प्रयास करें' : 'Retry';
  static String get appVersion => _hi ? 'एप वर्जन' : 'App Version';
  static String get aiModel => _hi ? 'AI मॉडल' : 'AI Model';
  static String get theme => _hi ? 'थीम' : 'Theme';
  static String get languageSettings => _hi ? 'भाषा सेटिंग्स' : 'Language Settings';
  static String get hindiTriage => _hi ? 'हिंदी ट्राइएज' : 'Hindi Triage';
  static String get english => _hi ? 'अंग्रेज़ी' : 'English';
  static String get hindi => _hi ? 'हिंदी' : 'Hindi';
}
