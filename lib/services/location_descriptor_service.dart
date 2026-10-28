import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'gps_service.dart';

class LocationDescription {
  final String directionFromLandmarkEn;
  final String directionFromLandmarkHi;
  final String landmarkEn;
  final String landmarkHi;
  final double distanceMeters;
  final String compassDirectionEn;
  final String compassDirectionHi;
  final String villageOrLocalityEn;
  final String villageOrLocalityHi;
  final String districtEn;
  final String districtHi;
  final String stateEn;
  final String stateHi;
  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isFromOnline;

  const LocationDescription({
    required this.directionFromLandmarkEn,
    required this.directionFromLandmarkHi,
    required this.landmarkEn,
    required this.landmarkHi,
    required this.distanceMeters,
    required this.compassDirectionEn,
    required this.compassDirectionHi,
    required this.villageOrLocalityEn,
    required this.villageOrLocalityHi,
    required this.districtEn,
    required this.districtHi,
    required this.stateEn,
    required this.stateHi,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.isFromOnline = false,
  });

  String formattedEn({bool includeCoords = true}) {
    final buffer = StringBuffer();
    if (directionFromLandmarkEn.isNotEmpty) {
      buffer.write(directionFromLandmarkEn);
    }
    if (villageOrLocalityEn.isNotEmpty && villageOrLocalityEn != landmarkEn) {
      if (buffer.isNotEmpty) buffer.write(', ');
      buffer.write(villageOrLocalityEn);
    }
    if (districtEn.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(', ');
      buffer.write(districtEn);
    }
    if (stateEn.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(', ');
      buffer.write(stateEn);
    }
    if (includeCoords) {
      buffer.write(' (${latitude.toStringAsFixed(5)}° N, ${longitude.toStringAsFixed(5)}° E');
      if (accuracy > 0) {
        buffer.write(' ±${accuracy.toStringAsFixed(0)}m');
      }
      buffer.write(')');
    }
    return buffer.toString();
  }

  String formattedHi({bool includeCoords = true}) {
    final buffer = StringBuffer();
    if (directionFromLandmarkHi.isNotEmpty) {
      buffer.write(directionFromLandmarkHi);
    }
    if (villageOrLocalityHi.isNotEmpty && villageOrLocalityHi != landmarkHi) {
      if (buffer.isNotEmpty) buffer.write(', ');
      buffer.write(villageOrLocalityHi);
    }
    if (districtHi.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(', ');
      buffer.write(districtHi);
    }
    if (stateHi.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(', ');
      buffer.write(stateHi);
    }
    if (includeCoords) {
      buffer.write(' (${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}');
      if (accuracy > 0) {
        buffer.write(' ±${accuracy.toStringAsFixed(0)} मी');
      }
      buffer.write(')');
    }
    return buffer.toString();
  }

  String radioScriptEn() {
    return 'MAYDAY/ALERT: My location is $directionFromLandmarkEn, locality $villageOrLocalityEn, $districtEn, $stateEn. Coordinates: ${latitude.toStringAsFixed(5)} North, ${longitude.toStringAsFixed(5)} East (accuracy ±${accuracy.toStringAsFixed(0)} meters).';
  }

  String radioScriptHi() {
    return 'राहत संदेश: मेरा स्थान $directionFromLandmarkHi, क्षेत्र $villageOrLocalityHi, $districtHi, $stateHi है। निर्देशांक: ${latitude.toStringAsFixed(5)} उत्तर, ${longitude.toStringAsFixed(5)} पूर्व (सटीकता ±${accuracy.toStringAsFixed(0)} मीटर)।';
  }
}

class LandmarkPOI {
  final String nameEn;
  final String nameHi;
  final String localityEn;
  final String localityHi;
  final String districtEn;
  final String districtHi;
  final String stateEn;
  final String stateHi;
  final double lat;
  final double lon;

  const LandmarkPOI({
    required this.nameEn,
    required this.nameHi,
    required this.localityEn,
    required this.localityHi,
    required this.districtEn,
    required this.districtHi,
    required this.stateEn,
    required this.stateHi,
    required this.lat,
    required this.lon,
  });
}

class LocationDescriptorService {
  static final LocationDescriptorService _instance = LocationDescriptorService._internal();
  factory LocationDescriptorService() => _instance;
  LocationDescriptorService._internal();

  static const List<LandmarkPOI> _gazetteer = [
    // Uttarakhand - Dehradun & Mussoorie
    LandmarkPOI(
      nameEn: 'Clock Tower (Ghanta Ghar)',
      nameHi: 'घंटाघर',
      localityEn: 'Paltan Bazaar / Rajpur Road',
      localityHi: 'पलटन बाज़ार / राजपुर रोड',
      districtEn: 'Dehradun',
      districtHi: 'देहरादून',
      stateEn: 'Uttarakhand',
      stateHi: 'उत्तराखंड',
      lat: 30.3255,
      lon: 78.0413,
    ),
    LandmarkPOI(
      nameEn: 'ISBT Dehradun',
      nameHi: 'आई.एस.बी.टी. देहरादून',
      localityEn: 'Transport Nagar / Majra',
      localityHi: 'ट्रांसपोर्ट नगर / माजरा',
      districtEn: 'Dehradun',
      districtHi: 'देहरादून',
      stateEn: 'Uttarakhand',
      stateHi: 'उत्तराखंड',
      lat: 30.2858,
      lon: 78.0076,
    ),
    LandmarkPOI(
      nameEn: 'Sahastradhara',
      nameHi: 'सहस्रधारा',
      localityEn: 'Sahastradhara Village',
      localityHi: 'सहस्रधारा गाँव',
      districtEn: 'Dehradun',
      districtHi: 'देहरादून',
      stateEn: 'Uttarakhand',
      stateHi: 'उत्तराखंड',
      lat: 30.3846,
      lon: 78.1311,
    ),
    LandmarkPOI(
      nameEn: 'Jolly Grant Airport',
      nameHi: 'जॉली ग्रांट एयरपोर्ट',
      localityEn: 'Bhaniawala / Rishikesh Road',
      localityHi: 'भानियावाला / ऋषिकेश मार्ग',
      districtEn: 'Dehradun',
      districtHi: 'देहरादून',
      stateEn: 'Uttarakhand',
      stateHi: 'उत्तराखंड',
      lat: 30.1897,
      lon: 78.1803,
    ),
    LandmarkPOI(
      nameEn: 'Laxman Jhula',
      nameHi: 'लक्ष्मण झूला',
      localityEn: 'Tapovan / Swargashram',
      localityHi: 'तपोवन / स्वर्गाश्रम',
      districtEn: 'Rishikesh (Dehradun/Pauri)',
      districtHi: 'ऋषिकेश',
      stateEn: 'Uttarakhand',
      stateHi: 'उत्तराखंड',
      lat: 30.1264,
      lon: 78.3283,
    ),
    LandmarkPOI(
      nameEn: 'Triveni Ghat',
      nameHi: 'त्रिवेणी घाट',
      localityEn: 'Mayakund',
      localityHi: 'मायाकुंड',
      districtEn: 'Rishikesh',
      districtHi: 'ऋषिकेश',
      stateEn: 'Uttarakhand',
      stateHi: 'उत्तराखंड',
      lat: 30.1039,
      lon: 78.2981,
    ),
    LandmarkPOI(
      nameEn: 'Har Ki Pauri',
      nameHi: 'हर की पौड़ी',
      localityEn: 'Bara Bazaar',
      localityHi: 'बड़ा बाज़ार',
      districtEn: 'Haridwar',
      districtHi: 'हरिद्वार',
      stateEn: 'Uttarakhand',
      stateHi: 'उत्तराखंड',
      lat: 29.9566,
      lon: 78.1706,
    ),
    LandmarkPOI(
      nameEn: 'Kedarnath Temple',
      nameHi: 'केदारनाथ मंदिर',
      localityEn: 'Kedarnath Valley',
      localityHi: 'केदारनाथ घाटी',
      districtEn: 'Rudraprayag',
      districtHi: 'रुद्रप्रयाग',
      stateEn: 'Uttarakhand',
      stateHi: 'उत्तराखंड',
      lat: 30.7352,
      lon: 79.0669,
    ),
    LandmarkPOI(
      nameEn: 'Badrinath Temple',
      nameHi: 'बद्रीनाथ मंदिर',
      localityEn: 'Badrinath Nagar',
      localityHi: 'बद्रीनाथ नगर',
      districtEn: 'Chamoli',
      districtHi: 'चमोली',
      stateEn: 'Uttarakhand',
      stateHi: 'उत्तराखंड',
      lat: 30.7433,
      lon: 79.4938,
    ),
    LandmarkPOI(
      nameEn: 'Joshimath Town',
      nameHi: 'जोशीमठ',
      localityEn: 'Sunil / Marwari',
      localityHi: 'सुनील / मारवाड़ी',
      districtEn: 'Chamoli',
      districtHi: 'चमोली',
      stateEn: 'Uttarakhand',
      stateHi: 'उत्तराखंड',
      lat: 30.5564,
      lon: 79.5658,
    ),
    LandmarkPOI(
      nameEn: 'Uttarkashi Town',
      nameHi: 'उत्तरकाशी',
      localityEn: 'Bhatwari Road',
      localityHi: 'भटवाड़ी रोड',
      districtEn: 'Uttarkashi',
      districtHi: 'उत्तरकाशी',
      stateEn: 'Uttarakhand',
      stateHi: 'उत्तराखंड',
      lat: 30.7268,
      lon: 78.4354,
    ),
    LandmarkPOI(
      nameEn: 'Mussoorie Mall Road',
      nameHi: 'मसूरी माल रोड',
      localityEn: 'Library Chowk',
      localityHi: 'लाइब्रेरी चौक',
      districtEn: 'Dehradun',
      districtHi: 'देहरादून',
      stateEn: 'Uttarakhand',
      stateHi: 'उत्तराखंड',
      lat: 30.4598,
      lon: 78.0644,
    ),

    // Himachal Pradesh
    LandmarkPOI(
      nameEn: 'Shimla Ridge / Mall Road',
      nameHi: 'शिमला रिज / माल रोड',
      localityEn: 'The Ridge',
      localityHi: 'द रिज',
      districtEn: 'Shimla',
      districtHi: 'शिमला',
      stateEn: 'Himachal Pradesh',
      stateHi: 'हिमाचल प्रदेश',
      lat: 31.1048,
      lon: 77.1734,
    ),
    LandmarkPOI(
      nameEn: 'Manali Mall Road',
      nameHi: 'मनाली माल रोड',
      localityEn: 'Model Town',
      localityHi: 'मॉडल टाउन',
      districtEn: 'Kullu',
      districtHi: 'कुल्लू',
      stateEn: 'Himachal Pradesh',
      stateHi: 'हिमाचल प्रदेश',
      lat: 32.2396,
      lon: 77.1887,
    ),
    LandmarkPOI(
      nameEn: 'Kullu Bus Stand',
      nameHi: 'कुल्लू बस स्टैंड',
      localityEn: 'Sarvari',
      localityHi: 'सरवरी',
      districtEn: 'Kullu',
      districtHi: 'कुल्लू',
      stateEn: 'Himachal Pradesh',
      stateHi: 'हिमाचल प्रदेश',
      lat: 31.9579,
      lon: 77.1095,
    ),
    LandmarkPOI(
      nameEn: 'Dharamshala Kotwali Bazaar',
      nameHi: 'धर्मशाला कोतवाली बाज़ार',
      localityEn: 'Kotwali Bazaar / McLeod Ganj',
      localityHi: 'कोतवाली बाज़ार',
      districtEn: 'Kangra',
      districtHi: 'कांगड़ा',
      stateEn: 'Himachal Pradesh',
      stateHi: 'हिमाचल प्रदेश',
      lat: 32.2190,
      lon: 76.3234,
    ),
    LandmarkPOI(
      nameEn: 'Mandi Victoria Bridge',
      nameHi: 'मंडी विक्टोरिया ब्रिज',
      localityEn: 'Purani Mandi',
      localityHi: 'पुरानी मंडी',
      districtEn: 'Mandi',
      districtHi: 'मंडी',
      stateEn: 'Himachal Pradesh',
      stateHi: 'हिमाचल प्रदेश',
      lat: 31.7088,
      lon: 76.9320,
    ),

    // Kerala - Wayanad & Disaster Prone Zones
    LandmarkPOI(
      nameEn: 'Chooralmala Town Bridge',
      nameHi: 'चूरलमाला टाउन ब्रिज',
      localityEn: 'Chooralmala Village',
      localityHi: 'चूरलमाला गाँव',
      districtEn: 'Wayanad',
      districtHi: 'वायनाड',
      stateEn: 'Kerala',
      stateHi: 'केरल',
      lat: 11.5362,
      lon: 76.1751,
    ),
    LandmarkPOI(
      nameEn: 'Meppadi Town',
      nameHi: 'मेप्पाडी टाउन',
      localityEn: 'Meppadi Junction',
      localityHi: 'मेप्पाडी जंक्शन',
      districtEn: 'Wayanad',
      districtHi: 'वायनाड',
      stateEn: 'Kerala',
      stateHi: 'केरल',
      lat: 11.5539,
      lon: 76.1264,
    ),
    LandmarkPOI(
      nameEn: 'Mundakkai Village',
      nameHi: 'मुंडकई गाँव',
      localityEn: 'Mundakkai Estate',
      localityHi: 'मुंडकई एस्टेट',
      districtEn: 'Wayanad',
      districtHi: 'वायनाड',
      stateEn: 'Kerala',
      stateHi: 'केरल',
      lat: 11.5230,
      lon: 76.1950,
    ),
    LandmarkPOI(
      nameEn: 'Kalpetta Civil Station',
      nameHi: 'कलपेट्टा सिविल स्टेशन',
      localityEn: 'Kalpetta Town',
      localityHi: 'कलपेट्टा',
      districtEn: 'Wayanad',
      districtHi: 'वायनाड',
      stateEn: 'Kerala',
      stateHi: 'केरल',
      lat: 11.6103,
      lon: 76.0827,
    ),
    LandmarkPOI(
      nameEn: 'Munnar Town',
      nameHi: 'मुन्नार टाउन',
      localityEn: 'Old Munnar',
      localityHi: 'ओल्ड मुन्नार',
      districtEn: 'Idukki',
      districtHi: 'इदुक्की',
      stateEn: 'Kerala',
      stateHi: 'केरल',
      lat: 10.0889,
      lon: 77.0595,
    ),
    LandmarkPOI(
      nameEn: 'Alappuzha KSRTC Stand',
      nameHi: 'अलप्पुझा बस स्टैंड',
      localityEn: 'Vellakinar',
      localityHi: 'वेल्लाकिनार',
      districtEn: 'Alappuzha',
      districtHi: 'अलप्पुझा',
      stateEn: 'Kerala',
      stateHi: 'केरल',
      lat: 9.4981,
      lon: 76.3388,
    ),

    // Assam & North East
    LandmarkPOI(
      nameEn: 'Guwahati Brahmaputra Ghat',
      nameHi: 'गुवाहाटी ब्रह्मपुत्र घाट',
      localityEn: 'Panbazar / Fancy Bazar',
      localityHi: 'पानबाज़ार / फैंसी बाज़ार',
      districtEn: 'Kamrup Metropolitan',
      districtHi: 'कामरूप',
      stateEn: 'Assam',
      stateHi: 'असम',
      lat: 26.1859,
      lon: 91.7478,
    ),
    LandmarkPOI(
      nameEn: 'Silchar Sadar Ghat',
      nameHi: 'सिलचर सदर घाट',
      localityEn: 'Fataks',
      localityHi: 'फाटक',
      districtEn: 'Cachar',
      districtHi: 'कछार',
      stateEn: 'Assam',
      stateHi: 'असम',
      lat: 24.8333,
      lon: 92.7789,
    ),
    LandmarkPOI(
      nameEn: 'Dibrugarh Bogibeel Bridge',
      nameHi: 'डिब्रूगढ़ बोगीबील ब्रिज',
      localityEn: 'Bogibeel',
      localityHi: 'बोगीबील',
      districtEn: 'Dibrugarh',
      districtHi: 'डिब्रूगढ़',
      stateEn: 'Assam',
      stateHi: 'असम',
      lat: 27.4022,
      lon: 94.8153,
    ),
    LandmarkPOI(
      nameEn: 'Kaziranga National Park HQ',
      nameHi: 'काजीरंगा मुख्यालय',
      localityEn: 'Kohora',
      localityHi: 'कोहोरा',
      districtEn: 'Golaghat',
      districtHi: 'गोलाघाट',
      stateEn: 'Assam',
      stateHi: 'असम',
      lat: 26.5828,
      lon: 93.3644,
    ),
    LandmarkPOI(
      nameEn: 'Majuli Kamalabari Ghat',
      nameHi: 'माजुली कमलाबाड़ी घाट',
      localityEn: 'Kamalabari',
      localityHi: 'कमलाबाड़ी',
      districtEn: 'Majuli',
      districtHi: 'माजुली',
      stateEn: 'Assam',
      stateHi: 'असम',
      lat: 26.9200,
      lon: 94.1950,
    ),

    // Odisha & Coastal
    LandmarkPOI(
      nameEn: 'Puri Jagannath Temple',
      nameHi: 'पुरी जगन्नाथ मंदिर',
      localityEn: 'Bada Danda',
      localityHi: 'बड़ा डांडा',
      districtEn: 'Puri',
      districtHi: 'पुरी',
      stateEn: 'Odisha',
      stateHi: 'ओडिशा',
      lat: 19.8049,
      lon: 85.8179,
    ),
    LandmarkPOI(
      nameEn: 'Bhubaneswar Master Canteen',
      nameHi: 'भुवनेश्वर मास्टर कैंटीन',
      localityEn: 'Kharvela Nagar',
      localityHi: 'खारवेल नगर',
      districtEn: 'Khordha',
      districtHi: 'खोरधा',
      stateEn: 'Odisha',
      stateHi: 'ओडिशा',
      lat: 20.2644,
      lon: 85.8427,
    ),
    LandmarkPOI(
      nameEn: 'Paradip Port Light House',
      nameHi: 'पारादीप लाइट हाउस',
      localityEn: 'Sector 21',
      localityHi: 'सेक्टर २१',
      districtEn: 'Jagatsinghpur',
      districtHi: 'जगतसिंहपुर',
      stateEn: 'Odisha',
      stateHi: 'ओडिशा',
      lat: 20.2640,
      lon: 86.6870,
    ),

    // National Capital & Key Centers
    LandmarkPOI(
      nameEn: 'India Gate',
      nameHi: 'इंडिया गेट',
      localityEn: 'Kartavya Path / Central Secretariat',
      localityHi: 'कर्तव्य पथ',
      districtEn: 'New Delhi',
      districtHi: 'नई दिल्ली',
      stateEn: 'Delhi',
      stateHi: 'दिल्ली',
      lat: 28.6129,
      lon: 77.2295,
    ),
    LandmarkPOI(
      nameEn: 'Gateway of India',
      nameHi: 'गेटवे ऑफ इंडिया',
      localityEn: 'Colaba / Apollo Bunder',
      localityHi: 'कोलाबा',
      districtEn: 'Mumbai City',
      districtHi: 'मुंबई',
      stateEn: 'Maharashtra',
      stateHi: 'महाराष्ट्र',
      lat: 18.9220,
      lon: 72.8347,
    ),
    LandmarkPOI(
      nameEn: 'Howrah Bridge',
      nameHi: 'हावड़ा ब्रिज',
      localityEn: 'Strand Road / Howrah Station',
      localityHi: 'हावड़ा',
      districtEn: 'Kolkata',
      districtHi: 'कोलकाता',
      stateEn: 'West Bengal',
      stateHi: 'पश्चिम बंगाल',
      lat: 22.5851,
      lon: 88.3468,
    ),
    LandmarkPOI(
      nameEn: 'Lal Chowk',
      nameHi: 'लाल चौक',
      localityEn: 'City Center',
      localityHi: 'सिटी सेंटर',
      districtEn: 'Srinagar',
      districtHi: 'श्रीनगर',
      stateEn: 'Jammu & Kashmir',
      stateHi: 'जम्मू और कश्मीर',
      lat: 34.0706,
      lon: 74.8080,
    ),
  ];

  static const Map<String, String> _hindiTranslationMap = {
    'Uttarakhand': 'उत्तराखंड',
    'Himachal Pradesh': 'हिमाचल प्रदेश',
    'Kerala': 'केरल',
    'Assam': 'असम',
    'Odisha': 'ओडिशा',
    'West Bengal': 'पश्चिम बंगाल',
    'Jammu and Kashmir': 'जम्मू और कश्मीर',
    'Jammu & Kashmir': 'जम्मू और कश्मीर',
    'Delhi': 'दिल्ली',
    'Maharashtra': 'महाराष्ट्र',
    'Gujarat': 'गुजरात',
    'Rajasthan': 'राजस्थान',
    'Uttar Pradesh': 'उत्तर प्रदेश',
    'Madhya Pradesh': 'मध्य प्रदेश',
    'Bihar': 'बिहार',
    'Punjab': 'पंजाब',
    'Haryana': 'हरियाणा',
    'Karnataka': 'कर्नाटक',
    'Tamil Nadu': 'तमिलनाडु',
    'Andhra Pradesh': 'आंध्र प्रदेश',
    'Telangana': 'तेलंगाना',
    'Wayanad': 'वायनाड',
    'Dehradun': 'देहरादून',
    'Haridwar': 'हरिद्वार',
    'Rishikesh': 'ऋषिकेश',
    'Chamoli': 'चमोली',
    'Rudraprayag': 'रुद्रप्रयाग',
    'Shimla': 'शिमला',
    'Kullu': 'कुल्लू',
    'Mandi': 'मंडी',
    'Kangra': 'कांगड़ा',
    'Kamrup Metropolitan': 'कामरूप',
    'Cachar': 'कछार',
    'Dibrugarh': 'डिब्रूगढ़',
    'Puri': 'पुरी',
    'Khordha': 'खोरधा',
  };

  /// Get comprehensive human-readable location description for coordinates.
  /// Runs completely offline using our built-in high-precision gazetteer,
  /// with opportunistic online enrichment when network is accessible.
  Future<LocationDescription> describeLocation(GeoPoint point, {bool forceOffline = false}) async {
    // 1. Calculate closest POI and relative bearing
    LandmarkPOI? closest;
    double minDistance = double.infinity;

    for (final poi in _gazetteer) {
      final d = _haversine(point.latitude, point.longitude, poi.lat, poi.lon);
      if (d < minDistance) {
        minDistance = d;
        closest = poi;
      }
    }

    if (closest == null) {
      return _fallbackDescription(point);
    }

    final bearing = _bearing(closest.lat, closest.lon, point.latitude, point.longitude);
    final compass = _compassDirection(bearing);

    final distStr = minDistance < 1000
        ? '${minDistance.toStringAsFixed(0)} m'
        : '${(minDistance / 1000).toStringAsFixed(1)} km';
    final distStrHi = minDistance < 1000
        ? '${minDistance.toStringAsFixed(0)} मी'
        : '${(minDistance / 1000).toStringAsFixed(1)} किमी';

    final dirEn = minDistance < 50
        ? 'At ${closest.nameEn}'
        : '~$distStr ${compass.en} of ${closest.nameEn}';
    final dirHi = minDistance < 50
        ? '${closest.nameHi} पर'
        : '${closest.nameHi} के ~$distStrHi ${compass.hi}';

    if (!forceOffline) {
      // 2. Check local offline cache for reverse geocode at this lat/lon grid
      final cached = await _getCachedReverse(point.latitude, point.longitude);
      if (cached != null) {
        final dStr = cached['district'] ?? closest.districtEn;
        final sStr = cached['state'] ?? closest.stateEn;
        return LocationDescription(
          directionFromLandmarkEn: dirEn,
          directionFromLandmarkHi: dirHi,
          landmarkEn: closest.nameEn,
          landmarkHi: closest.nameHi,
          distanceMeters: minDistance,
          compassDirectionEn: compass.en,
          compassDirectionHi: compass.hi,
          villageOrLocalityEn: cached['locality'] ?? closest.localityEn,
          villageOrLocalityHi: cached['localityHi'] ?? closest.localityHi,
          districtEn: dStr,
          districtHi: _hindiTranslationMap[dStr] ?? cached['districtHi'] ?? closest.districtHi,
          stateEn: sStr,
          stateHi: _hindiTranslationMap[sStr] ?? cached['stateHi'] ?? closest.stateHi,
          latitude: point.latitude,
          longitude: point.longitude,
          accuracy: point.accuracy,
          isFromOnline: true,
        );
      }

      // 3. Try quick opportunistic reverse geocode (max 2.5s) if online
      try {
        final onlineInfo = await _tryOnlineReverseGeocode(point.latitude, point.longitude, closest: closest);
        if (onlineInfo != null) {
          await _saveCachedReverse(point.latitude, point.longitude, onlineInfo);
          final dStr = onlineInfo['district'] ?? closest.districtEn;
          final sStr = onlineInfo['state'] ?? closest.stateEn;
          return LocationDescription(
            directionFromLandmarkEn: dirEn,
            directionFromLandmarkHi: dirHi,
            landmarkEn: closest.nameEn,
            landmarkHi: closest.nameHi,
            distanceMeters: minDistance,
            compassDirectionEn: compass.en,
            compassDirectionHi: compass.hi,
            villageOrLocalityEn: onlineInfo['locality'] ?? closest.localityEn,
            villageOrLocalityHi: onlineInfo['localityHi'] ?? closest.localityHi,
            districtEn: dStr,
            districtHi: _hindiTranslationMap[dStr] ?? onlineInfo['districtHi'] ?? closest.districtHi,
            stateEn: sStr,
            stateHi: _hindiTranslationMap[sStr] ?? onlineInfo['stateHi'] ?? closest.stateHi,
            latitude: point.latitude,
            longitude: point.longitude,
            accuracy: point.accuracy,
            isFromOnline: true,
          );
        }
      } catch (_) {
        // Offline: gracefully fallback to gazetteer
      }
    }

    // 4. Return offline gazetteer match
    return LocationDescription(
      directionFromLandmarkEn: dirEn,
      directionFromLandmarkHi: dirHi,
      landmarkEn: closest.nameEn,
      landmarkHi: closest.nameHi,
      distanceMeters: minDistance,
      compassDirectionEn: compass.en,
      compassDirectionHi: compass.hi,
      villageOrLocalityEn: closest.localityEn,
      villageOrLocalityHi: closest.localityHi,
      districtEn: closest.districtEn,
      districtHi: closest.districtHi,
      stateEn: closest.stateEn,
      stateHi: closest.stateHi,
      latitude: point.latitude,
      longitude: point.longitude,
      accuracy: point.accuracy,
      isFromOnline: false,
    );
  }

  LocationDescription _fallbackDescription(GeoPoint point) {
    return LocationDescription(
      directionFromLandmarkEn: '',
      directionFromLandmarkHi: '',
      landmarkEn: '',
      landmarkHi: '',
      distanceMeters: 0,
      compassDirectionEn: '',
      compassDirectionHi: '',
      villageOrLocalityEn: 'Coordinates: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
      villageOrLocalityHi: 'निर्देशांक: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
      districtEn: '',
      districtHi: '',
      stateEn: 'India',
      stateHi: 'भारत',
      latitude: point.latitude,
      longitude: point.longitude,
      accuracy: point.accuracy,
    );
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _bearing(double lat1, double lon1, double lat2, double lon2) {
    final latRad1 = lat1 * math.pi / 180.0;
    final latRad2 = lat2 * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(latRad2);
    final x = math.cos(latRad1) * math.sin(latRad2) -
        math.sin(latRad1) * math.cos(latRad2) * math.cos(dLon);
    final bearingRad = math.atan2(y, x);
    return (bearingRad * 180.0 / math.pi + 360.0) % 360.0;
  }

  ({String en, String hi}) _compassDirection(double bearing) {
    if (bearing >= 348.75 || bearing < 11.25) return (en: 'North', hi: 'उत्तर');
    if (bearing >= 11.25 && bearing < 33.75) return (en: 'NNE', hi: 'उत्तर-उत्तर-पूर्व');
    if (bearing >= 33.75 && bearing < 56.25) return (en: 'North-East', hi: 'उत्तर-पूर्व');
    if (bearing >= 56.25 && bearing < 78.75) return (en: 'ENE', hi: 'पूर्व-उत्तर-पूर्व');
    if (bearing >= 78.75 && bearing < 101.25) return (en: 'East', hi: 'पूर्व');
    if (bearing >= 101.25 && bearing < 123.75) return (en: 'ESE', hi: 'पूर्व-दक्षिण-पूर्व');
    if (bearing >= 123.75 && bearing < 146.25) return (en: 'South-East', hi: 'दक्षिण-पूर्व');
    if (bearing >= 146.25 && bearing < 168.75) return (en: 'SSE', hi: 'दक्षिण-दक्षिण-पूर्व');
    if (bearing >= 168.75 && bearing < 191.25) return (en: 'South', hi: 'दक्षिण');
    if (bearing >= 191.25 && bearing < 213.75) return (en: 'SSW', hi: 'दक्षिण-दक्षिण-पश्चिम');
    if (bearing >= 213.75 && bearing < 236.25) return (en: 'South-West', hi: 'दक्षिण-पश्चिम');
    if (bearing >= 236.25 && bearing < 258.75) return (en: 'WSW', hi: 'पश्चिम-दक्षिण-पश्चिम');
    if (bearing >= 258.75 && bearing < 281.25) return (en: 'West', hi: 'पश्चिम');
    if (bearing >= 281.25 && bearing < 303.75) return (en: 'WNW', hi: 'पश्चिम-उत्तर-पश्चिम');
    if (bearing >= 303.75 && bearing < 326.25) return (en: 'North-West', hi: 'उत्तर-पश्चिम');
    return (en: 'NNW', hi: 'उत्तर-उत्तर-पश्चिम');
  }

  Future<Map<String, String>?> _tryOnlineReverseGeocode(double lat, double lon, {LandmarkPOI? closest}) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat.toStringAsFixed(5)}&lon=${lon.toStringAsFixed(5)}&zoom=16&addressdetails=1',
      );
      final resp = await http.get(url, headers: {
        'User-Agent': 'Rakshak-AI-Disaster-Companion/2.1',
      }).timeout(const Duration(milliseconds: 2500));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final locality = address['village'] ??
            address['suburb'] ??
            address['neighbourhood'] ??
            address['residential'] ??
            address['road'] ??
            address['town'] ??
            '';
        final district = address['state_district'] ?? address['county'] ?? address['city'] ?? '';
        final state = address['state'] ?? 'India';

        if (locality.isNotEmpty || district.isNotEmpty) {
          final dStr = district.toString();
          final sStr = state.toString();
          return {
            'locality': locality.toString(),
            'localityHi': locality.toString(),
            'district': dStr,
            'districtHi': _hindiTranslationMap[dStr] ?? closest?.districtHi ?? dStr,
            'state': sStr,
            'stateHi': _hindiTranslationMap[sStr] ?? closest?.stateHi ?? sStr,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  String _cacheKey(double lat, double lon) {
    // 2-decimal grid precision (~1.1 km)
    return 'rev_geo_${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
  }

  Future<Map<String, String>?> _getCachedReverse(double lat, double lon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(lat, lon));
      if (raw != null) {
        return Map<String, String>.from(jsonDecode(raw) as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveCachedReverse(double lat, double lon, Map<String, String> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(lat, lon), jsonEncode(data));
    } catch (_) {}
    return;
  }
}
