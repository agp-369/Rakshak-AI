import 'package:flutter/material.dart';

/// A survival scenario card. Ordered by real-world death patterns:
/// flash flood and landslide kill fastest in the Indian Himalaya
/// and Western Ghats; earthquake has the widest exposure.
class SurvivalScenario {
  final String id;
  final String titleEn;
  final String titleHi;
  final IconData icon;
  final Color color;
  final List<String> immediateStepsEn;
  final List<String> immediateStepsHi;
  final List<String> dontsEn;
  final List<String> dontsHi;
  final String speakEn;
  final String speakHi;

  const SurvivalScenario({
    required this.id,
    required this.titleEn,
    required this.titleHi,
    required this.icon,
    required this.color,
    required this.immediateStepsEn,
    required this.immediateStepsHi,
    required this.dontsEn,
    required this.dontsHi,
    required this.speakEn,
    required this.speakHi,
  });
}

/// The scenario library. Content follows NDMA/CBP public guidance —
/// plain, actionable, no medical theater.
const List<SurvivalScenario> survivalScenarios = [
  SurvivalScenario(
    id: 'flash_flood',
    titleEn: 'Flash Flood — water rising fast',
    titleHi: 'अचानक बाढ़ — पानी तेज़ी से बढ़ रहा',
    icon: Icons.water,
    color: Color(0xFF1971C2),
    immediateStepsEn: [
      'MOVE UP. Higher ground NOW — do not wait to pack.',
      'Never walk or drive through moving water. 15 cm sweeps an adult off their feet.',
      'If trapped on the ground floor, go to the roof — take something that floats.',
      'Stay off bridges — water may have weakened them.',
    ],
    immediateStepsHi: [
      'ऊपर जाएं। अभी तुरंत ऊँची जगह पर जाएं — सामान उठाने का इंतज़ार न करें।',
      'बहते पानी में कभी न चलें और न गाड़ी चलाएं। 15 सेंटीमीटर पानी भी बहा सकता है।',
      'अगर नीचे मजबूर हैं तो छत पर जाएं — कुछ तैरने वाला साथ लें।',
      'पुल पर न जाएं — पानी ने कमज़ोर किया हो सकता है।',
    ],
    dontsEn: [
      'Do NOT walk through floodwater — hidden drains and debris.',
      'Do NOT camp or sleep in a river bed even if it looks dry.',
      'Do NOT drive around barricades.',
    ],
    dontsHi: [
      'बाढ़ के पानी में न चलें — नाले और मलबा दिखता नहीं।',
      'सूखी दिखने वाली नदी में कभी डेरा न डालें।',
      'बैरिकेड हटाकर गाड़ी न चलाएं।',
    ],
    speakEn:
        'Flash flood. Move to higher ground immediately. Do not walk through moving water. Fifteen centimeters of water can sweep you off your feet. Go up now.',
    speakHi:
        'अचानक बाढ़। अभी ऊँची जगह पर जाएं। बहते पानी में न चलें। पंद्रह सेंटीमीटर पानी भी बहा सकता है। अभी ऊपर जाएं।',
  ),
  SurvivalScenario(
    id: 'landslide',
    titleEn: 'Landslide — ground moving, slope above you',
    titleHi: 'भूस्खलन — ज़मीन हिल रही, ऊपर ढलान है',
    icon: Icons.terrain,
    color: Color(0xFFE8590C),
    immediateStepsEn: [
      'Move HORIZONTALLY away from the slide path, then uphill if safe.',
      'If indoors, exit away from the slope — do not run downhill.',
      'After it stops, watch for a SECOND slide — they come in clusters.',
      'Listen for rumbling; ground vibration often precedes the slide.',
    ],
    immediateStepsHi: [
      'स्लाइड की दिशा से क्षैतिज दूरी बनाएं, फिर सुरक्षित हो तो ऊपर जाएं।',
      'घर के अंदर हों तो ढलान के विपरीत दिशा से निकलें — नीचे की ओर न भागें।',
      'रुकने के बाद भी दूसरी स्लाइड का इंतज़ार करें — यह एक साथ कई बार आती है।',
      'गुरुज और ज़मीन के कंपन पर ध्यान दें — स्लाइड से पहले अक्सर यही संकेत मिलता है।',
    ],
    dontsEn: [
      'Do NOT stop to collect belongings.',
      'Do NOT shelter under the slope or near cliff edges.',
      'Do NOT go near a dammed stream — it may burst.',
    ],
    dontsHi: [
      'सामान उठाने में समय बर्बाद न करें।',
      'ढलान के नीचे या चट्टान के पास न ठहरें।',
      'रुके हुए पानी के पास न जाएं — अचानक फूट सकता है।',
    ],
    speakEn:
        'Landslide. Move sideways away from the slide, then uphill. Do not run downhill. Watch for a second slide after the first stops.',
    speakHi:
        'भूस्खलन। स्लाइड की दिशा से दूर हटें, फिर ऊपर जाएं। नीचे की ओर न भागें। पहले रुकने के बाद दूसरी स्लाइड का इंतज़ार करें।',
  ),
  SurvivalScenario(
    id: 'earthquake',
    titleEn: 'Earthquake — shaking has started',
    titleHi: 'भूकंप — झटके आ रहे हैं',
    icon: Icons.terrain_outlined,
    color: Color(0xFFE03131),
    immediateStepsEn: [
      'DROP on hands and knees. Take Cover under a sturdy table. HOLD ON.',
      'If no table, cover your head and neck with arms against an interior wall.',
      'Stay away from windows, glass, and heavy objects that can fall.',
      'If in bed, stay there — cover your head with a pillow.',
      'If OUTSIDE, move to an open area away from buildings and power lines.',
    ],
    immediateStepsHi: [
      'घुटनों पर आ जाएं। मज़बूत मेज़ के नीचे शरण लें। पकड़े रहें।',
      'मेज़ न हो तो सिर और गर्दन हाथों से ढकें, भीतरी दीवार के पास रहें।',
      'खिड़की, कांच और भारी गिरने वाली वस्तुओं से दूर रहें।',
      'बिस्तर पर हों तो वहीं रहें — तकिये से सिर ढकें।',
      'बाहर हों तो खुले मैदान में जाएं, इमारत और बिजली के तारों से दूर।',
    ],
    dontsEn: [
      'Do NOT run outside DURING the shaking — falling debris kills.',
      'Do NOT use lifts.',
      'Do NOT light a match if you smell gas.',
    ],
    dontsHi: [
      'झटकों के दौरान बाहर न भागें — गिरा मलबा जान लेता है।',
      'लिफ्ट का उपयोग न करें।',
      'गैस की गंध आए तो माचिस न जलाएं।',
    ],
    speakEn:
        'Earthquake. Drop, cover and hold on. Stay away from windows. Do not use the lift. If outdoors, move to an open area. Wait for shaking to stop before going out.',
    speakHi:
        'भूकंप। झुकें, ढकें, पकड़ें। खिड़कियों से दूर रहें। लिफ्ट न लें। बाहर हों तो खुले मैदान में जाएं। झटके रुकने तक रुकें।',
  ),
  SurvivalScenario(
    id: 'trapped',
    titleEn: 'Trapped / buried in debris',
    titleHi: 'मलबे में फंसे हैं',
    icon: Icons.front_hand,
    color: Color(0xFF862E9C),
    immediateStepsEn: [
      'Cover your mouth with cloth — dust blocks airways.',
      'Do NOT shout continuously — it wastes energy and breath. Tap on pipes or walls in a rhythm rescuers recognize (3 taps, wait, repeat).',
      'If you have a phone, keep it in your hand — battery saves you.',
      'Stay calm. Rescue teams search collapsed structures for days.',
    ],
    immediateStepsHi: [
      'कपड़े से मुँह ढकें — धूल साँस रोकती है।',
      'लगातार चिल्लाएं न — ऊर्जा और साँस खर्च होती है। पाइप या दीवार पर लयबद्ध तीन थप्पी मारें, फिर रुकें, दोहराएं।',
      'फोन हाथ में रखें — बैटरी आपकी जान बचा सकती है।',
      'शांत रहें। राहत दल दिनों तक खोज करता है।',
    ],
    dontsEn: [
      'Do NOT move heavy debris above you — you may cause a further collapse.',
      'Do NOT light fires — air is scarce underground.',
    ],
    dontsHi: [
      'ऊपर का भारी मलबा न हिलाएं — और गिर सकता है।',
      'आग न जलाएं — नीचे हवा कम होती है।',
    ],
    speakEn:
        'You are trapped. Cover your mouth with cloth. Tap three times on pipes, wait, repeat. Do not shout continuously. Keep your phone in your hand.',
    speakHi:
        'आप फंसे हैं। कपड़े से मुँह ढकें। पाइप पर तीन थप्पी मारें, रुकें, दोहराएं। लगातार चिल्लाएं न। फोन हाथ में रखें।',
  ),
  SurvivalScenario(
    id: 'bleeding',
    titleEn: 'Severe bleeding — someone is bleeding heavily',
    titleHi: 'तेज़ खून बह रहा है',
    icon: Icons.bloodtype,
    color: Color(0xFFC92A2A),
    immediateStepsEn: [
      'Press hard directly on the wound with cloth or clean material. Do not remove it — add more layers if soaked.',
      'Raise the injured limb above heart level if possible.',
      'For an embedded object, do NOT pull it out — pad around it.',
      'Keep the person warm and still. Watch for shock (pale, cold, fast breathing).',
    ],
    immediateStepsHi: [
      'घाव पर सीधे कपड़े या साफ़ सामग्री से ज़ोर से दबाएं। न निकालें — भीगे तो और परतें चढ़ाएं।',
      'संभव हो तो चोटिल अंग हृदय के ऊपर उठाएं।',
      'शरीर में फंसी वस्तु न निकालें — उसके चारों ओर भरें।',
      'व्यक्ति को गर्म और स्थिर रखें। झटके (शॉक) पर नज़र रखें — पीलापन, ठंड, तेज़ साँस।',
    ],
    dontsEn: [
      'Do NOT remove a blood-soaked cloth — it pulls the clot.',
      'Do NOT give food or water if surgery may be needed.',
    ],
    dontsHi: [
      'खून से भीगा कपड़ा न निकालें — थक्का निकल जाता है।',
      'ऑपरेशन हो सकता है — पानी-भोजन न दें।',
    ],
    speakEn:
        'Severe bleeding. Press hard on the wound with cloth. Do not remove soaked cloth, add more. Raise the limb. Keep the person warm.',
    speakHi:
        'तेज़ खून बह रहा है। कपड़े से ज़ोर से दबाएं। भीगा कपड़ा न निकालें, और चढ़ाएं। अंग ऊपर उठाएं। व्यक्ति को गर्म रखें।',
  ),
  SurvivalScenario(
    id: 'night_evac',
    titleEn: 'Night evacuation — warning came at 2 AM',
    titleHi: 'रात में निकासी — चेतावनी रात 2 बजे आई',
    icon: Icons.nightlight,
    color: Color(0xFF5F3DC4),
    immediateStepsEn: [
      'Wayanad 2024: landslides hit at 2 AM — families asleep died. THIS is why you rehearse.',
      'Keep a go-bag at the bed: torch, water, phone charger, ID, cash, medicine.',
      'If warning arrives at night, LEAVE. Dress children while packing — do not wait for certainty.',
      'Walk uphill / away from rivers and slopes. Use torch, not phone screen — save battery.',
      'Designate a family meeting point in advance (temple, school, elevated road).',
    ],
    immediateStepsHi: [
      'वायनाड 2024: भूस्खलन रात 2 बजे आया — सोए परिवार मरे। इसीलिए पहले से तैयारी ज़रूरी है।',
      'बिस्तर के पास बैग रखें: टॉर्च, पानी, चार्जर, ID, नकद, दवा।',
      'रात में चेतावनी आए तो निकल जाएं। बच्चों को पहनाएं और साथ लें — पक्का इंतज़ार न करें।',
      'ऊपर या नदी-ढलान से दूर चलें। टॉर्च इस्तेमाल करें, फोन की स्क्रीन नहीं — बैटरी बचाएं।',
      'पहले से मिलने की जगह तय करें (मंदिर, स्कूल, ऊँची सड़क)।',
    ],
    dontsEn: [
      'Do NOT wait to lock up or pack everything.',
      'Do NOT go back for pets or possessions.',
      'Do NOT split the family — go together.',
    ],
    dontsHi: [
      'ताला लगाने या सब कुछ पैक करने में समय बर्बाद न करें।',
      'पालतू या सामान लेने वापस न जाएं।',
      'परिवार न बांटें — साथ चलें।',
    ],
    speakEn:
        'Night evacuation. Leave immediately. Dress the children and take the go bag. Walk uphill, away from rivers and slopes. Use a torch, save phone battery. Go to the family meeting point.',
    speakHi:
        'रात में निकासी। अभी निकल जाएं। बच्चों को पहनाएं और बैग लें। ऊपर चलें, नदी और ढलान से दूर। टॉर्च चलाएं, फोन की बैटरी बचाएं। परिवार की तय जगह पर जाएं।',
  ),
  SurvivalScenario(
    id: 'heatstroke',
    titleEn: 'Heat stroke — person hot, confused, stops sweating',
    titleHi: 'हीट स्ट्रोक — शरीर गर्म, भ्रमित, पसीना नहीं',
    icon: Icons.wb_sunny,
    color: Color(0xFFF59F00),
    immediateStepsEn: [
      'Move the person to shade immediately.',
      'Cool them: remove extra clothing, pour water on skin, fan vigorously.',
      'If conscious, give small sips of water ORS.',
      'Call 108 — heat stroke is a medical emergency, not just discomfort.',
    ],
    immediateStepsHi: [
      'व्यक्ति को तुरंत छाया में ले जाएं।',
      'ठंडा करें: अतिरिक्त कपड़े उतारें, त्वचा पर पानी डालें, ज़ोर से हवा करें।',
      'होश में हों तो थोड़ा-थोड़ा पानी या ORS पिलाएं।',
      '108 पर कॉल करें — हीट स्ट्रोक चिकित्सकीय आपातकाल है।',
    ],
    dontsEn: [
      'Do NOT give ice-cold water — shock risk.',
      'Do NOT assume it will pass — heat stroke kills within hours.',
    ],
    dontsHi: [
      'बर्फ़ ठंडा पानी न पिलाएं — झटका लग सकता है।',
      'यह अपने आप ठीक नहीं होता — हीट स्ट्रोक घंटों में जान लेता है।',
    ],
    speakEn:
        'Heat stroke. Move the person to shade. Remove extra clothing, pour water on skin, fan them. Give small sips of water if conscious. Call one zero eight.',
    speakHi:
        'हीट स्ट्रोक। व्यक्ति को छाया में ले जाएं। कपड़े उतारें, त्वचा पर पानी डालें, हवा करें। होश में हों तो थोड़ा पानी पिलाएं। एक ज़ीरो आठ पर कॉल करें।',
  ),
];

SurvivalScenario? findScenario(String query) {
  final lower = query.toLowerCase();
  for (final s in survivalScenarios) {
    if (lower.contains(s.id) ||
        lower.contains(s.titleEn.toLowerCase().split(' ').first)) {
      return s;
    }
  }
  // Fallback keyword families for voice intent.
  if (lower.contains('water') || lower.contains('flood') || lower.contains('पानी') || lower.contains('बाढ़')) {
    return survivalScenarios[0];
  }
  if (lower.contains('landslide') || lower.contains('slide') || lower.contains('भूस्खलन') || lower.contains('मिट्टी')) {
    return survivalScenarios[1];
  }
  if (lower.contains('quake') || lower.contains('earthquake') || lower.contains('भूकंप')) {
    return survivalScenarios[2];
  }
  if (lower.contains('trapped') || lower.contains('buried') || lower.contains('फंस') || lower.contains('मलबा')) {
    return survivalScenarios[3];
  }
  if (lower.contains('bleed') || lower.contains('blood') || lower.contains('खून')) {
    return survivalScenarios[4];
  }
  if (lower.contains('heat') || lower.contains('गर्मी') || lower.contains('लू')) {
    return survivalScenarios[6];
  }
  return null;
}
