/// Offline disaster knowledge base used for retrieval-augmented answers.
/// Each chunk is short, sourced from public NDMA / NDRF / WHO / CBP
/// guidance, and written as an action — never a diagnosis. The model is
/// only allowed to answer FROM these chunks, which keeps it grounded and
/// keeps a phone from inventing medical advice.
class KnowledgeChunk {
  final String id;
  final String hazard;
  final String titleEn;
  final String titleHi;
  final String textEn;
  final String textHi;
  final List<String> tags;
  final String source;

  const KnowledgeChunk({
    required this.id,
    required this.hazard,
    required this.titleEn,
    required this.titleHi,
    required this.textEn,
    required this.textHi,
    required this.tags,
    required this.source,
  });

  String title(bool hindi) => hindi ? titleHi : titleEn;
  String body(bool hindi) => hindi ? textHi : textEn;
}

const List<KnowledgeChunk> disasterKnowledge = [
  KnowledgeChunk(
    id: 'flood_moving_water',
    hazard: 'flood',
    titleEn: 'Moving water kills — go up, never through',
    titleHi: 'बहता पानी जान लेता है — ऊपर जाएं, पार न करें',
    textEn:
        'Move to higher ground immediately. Never walk or drive through moving water: 15 cm can knock an adult down, 30 cm can move a car. If water enters the room, go to the roof and take something that floats. Stay off bridges that water has hit.',
    textHi:
        'तुरंत ऊँची जगह जाएं। बहते पानी में कभी न चलें या गाड़ी न चलाएं: 15 सेंटीमीटर पानी वयस्क को गिरा सकता है, 30 सेंटीमीटर गाड़ी बहा सकता है। पानी कमरे में आए तो छत पर जाएं और तैरने वाली चीज़ साथ लें। पानी से टकराए पुलों पर न जाएं।',
    tags: ['flood', 'water', 'बाढ़', 'पानी', 'rising', 'बहाव', 'roof', 'छत'],
    source: 'NDMA flood dos and don\'ts',
  ),
  KnowledgeChunk(
    id: 'flood_night',
    hazard: 'flood',
    titleEn: 'Night flood warning — leave before it is certain',
    titleHi: 'रात में बाढ़ की चेतावनी — पक्का होने से पहले निकलें',
    textEn:
        'If a warning arrives at night, leave. Do not wait for certainty. Dress children, take the go-bag (torch, water, phone, charger, ID, medicine), and walk uphill away from streams and slopes. Use a torch, not the phone screen, to save battery. Go to a pre-agreed family meeting point.',
    textHi:
        'रात में चेतावनी आए तो निकल जाएं। पक्का होने का इंतज़ार न करें। बच्चों को पहनाएं, बैग लें (टॉर्च, पानी, फोन, चार्जर, पहचान पत्र, दवा), और नालों व ढलानों से दूर ऊपर चलें। बैटरी बचाने के लिए टॉर्च चलाएं, फोन स्क्रीन नहीं। पहले से तय परिवार की जगह पर जाएं।',
    tags: ['night', 'रात', 'evacuate', 'निकासी', 'flash flood', 'अचानक'],
    source: 'Wayanad 2024 after-action + NDMA guidance',
  ),
  KnowledgeChunk(
    id: 'landslide_slope',
    hazard: 'landslide',
    titleEn: 'Landslide — move sideways, expect a second slide',
    titleHi: 'भूस्खलन — बगल में हटें, दूसरी स्लाइड की तैयारी रखें',
    textEn:
        'Move horizontally out of the slide path, then uphill if it is safe. Do not run downhill in front of it. After it stops, stay away — landslides come in clusters, and rain after the first slide keeps the ground unstable. Never sleep below a slope, in a ravine, or near a cliff during heavy rain.',
    textHi:
        'स्लाइड के रास्ते से बगल में हटें, सुरक्षित हो तो ऊपर जाएं। इसके सामने नीचे की ओर न भागें। रुकने के बाद दूर रहें — भूस्खलन एक साथ कई बार आते हैं, और बारिश ज़मीन को अस्थिर रखती है। भारी बारिश में ढलान के नीचे, नाले या चट्टान के पास कभी न सोएं।',
    tags: ['landslide', 'भूस्खलन', 'slope', 'ढलान', 'rain', 'बारिश', 'debris'],
    source: 'GSI landslide guidance + NDMA',
  ),
  KnowledgeChunk(
    id: 'earthquake_drop_cover',
    hazard: 'earthquake',
    titleEn: 'Earthquake — drop, cover, hold on',
    titleHi: 'भूकंप — झुकें, ढकें, पकड़ें',
    textEn:
        'Drop to hands and knees, take cover under a sturdy table, and hold on. If there is no table, cover your head and neck against an interior wall. Stay away from windows and heavy objects. Do not run outside while the ground is shaking. Do not use lifts. If outdoors, move to an open area away from buildings and power lines.',
    textHi:
        'घुटनों पर आएं, मज़बूत मेज़ के नीचे शरण लें, और पकड़े रहें। मेज़ न हो तो भीतरी दीवार के पास सिर और गर्दन ढकें। खिड़कियों और भारी सामान से दूर रहें। ज़मीन हिलते समय बाहर न भागें। लिफ्ट न लें। बाहर हों तो खुले मैदान में जाएं।',
    tags: ['earthquake', 'भूकंप', 'shaking', 'झटके', 'building', 'इमारत'],
    source: 'NDMA earthquake dos and don\'ts',
  ),
  KnowledgeChunk(
    id: 'trapped_debris',
    hazard: 'trapped',
    titleEn: 'Trapped in debris — save breath, signal with taps',
    titleHi: 'मलबे में फंसे — साँस बचाएं, थप्पी से संकेत दें',
    textEn:
        'Cover your mouth and nose with cloth to keep dust out. Do not shout continuously; it wastes breath and energy. Tap on a pipe or wall in a rhythm rescuers recognise: three taps, pause, repeat. Keep your phone in your hand and use it only for beacons, not the torch, to save battery. Do not move heavy debris above you.',
    textHi:
        'धूल से बचने के लिए कपड़े से मुँह-नाक ढकें। लगातार चिल्लाएं न; साँस और ऊर्जा बचाएं। पाइप या दीवार पर लय में थप्पी मारें: तीन थप्पी, रुकें, दोहराएं। फोन हाथ में रखें, बैटरी बचाने के लिए टॉर्च की तरह इस्तेमाल न करें। ऊपर का भारी मलबा न हिलाएं।',
    tags: ['trapped', 'फंसा', 'debris', 'मलबा', 'buried', 'rescued', 'rescue'],
    source: 'NDRF collapsed-structure guidance',
  ),
  KnowledgeChunk(
    id: 'bleeding_control',
    hazard: 'bleeding',
    titleEn: 'Severe bleeding — press hard, do not remove soaked cloth',
    titleHi: 'तेज़ खून — ज़ोर से दबाएं, भीगा कपड़ा न हटाएं',
    textEn:
        'Press hard directly on the wound with cloth. Do not remove a soaked cloth — add more layers on top. Raise the limb above heart level if possible. If an object is embedded, do not pull it out; pad around it. Keep the person warm and still, and watch for shock: pale skin, cold sweat, fast breathing. Call 108.',
    textHi:
        'घाव पर कपड़े से सीधे ज़ोर से दबाएं। भीगा कपड़ा न हटाएं — ऊपर और परतें चढ़ाएं। संभव हो तो अंग को हृदय से ऊपर उठाएं। फंसी वस्तु न निकालें, उसके आसपास दबाएं। व्यक्ति को गर्म और स्थिर रखें, शॉक पर नज़र रखें: पीली त्वचा, ठंडा पसीना, तेज़ साँस। 108 पर कॉल करें।',
    tags: ['bleeding', 'खून', 'blood', 'wound', 'घाव', 'injury', 'चोट'],
    source: 'WHO basic emergency care + NDMA',
  ),
  KnowledgeChunk(
    id: 'cpr',
    hazard: 'bleeding',
    titleEn: 'Not breathing — start chest compressions',
    titleHi: 'साँस नहीं — छाती दबाना शुरू करें',
    textEn:
        'If the person is unresponsive and not breathing normally, start chest compressions: place the heel of your hand on the centre of the chest, press hard and fast at about 100–120 per minute, and let the chest rise fully between presses. Continue until help arrives. Call 108 on speaker while you do this.',
    textHi:
        'व्यक्ति बेहोश है और सामान्य साँस नहीं ले रहा, तो छाती दबाना शुरू करें: हथेली की जड़ छाती के बीच रखें, तेज़ और गहरा दबाएं, लगभग 100–120 बार प्रति मिनट, और बीच में छाती पूरी उठने दें। मदद आने तक जारी रखें। ऐसा करते समय 108 स्पीकर पर चलाएं।',
    tags: ['not breathing', 'साँस', 'cpr', 'unconscious', 'बेहोश', 'chest', 'छाती'],
    source: 'WHO basic emergency care',
  ),
  KnowledgeChunk(
    id: 'heat_stroke',
    hazard: 'heatwave',
    titleEn: 'Heat stroke — cool fast, it kills within hours',
    titleHi: 'हीट स्ट्रोक — तुरंत ठंडा करें, घंटों में जान लेता है',
    textEn:
        'Move the person to shade. Remove extra clothing, pour water on the skin and fan vigorously. If conscious, give small sips of water or ORS. If confused, hot and not sweating, it is heat stroke — call 108 immediately. Do not give ice-cold water.',
    textHi:
        'व्यक्ति को छाया में ले जाएं। अतिरिक्त कपड़े उतारें, त्वचा पर पानी डालें और ज़ोर से हवा करें। होश में हों तो थोड़ा पानी या ORS पिलाएं। भ्रम, गर्मी और पसीना न आना हीट स्ट्रोक है — तुरंत 108 पर कॉल करें। बर्फ़ जैसा ठंडा पानी न दें।',
    tags: ['heat', 'गर्मी', 'heatstroke', 'लू', 'sun', 'धूप'],
    source: 'NDMA heat wave guidance',
  ),
  KnowledgeChunk(
    id: 'lightning',
    hazard: 'lightning',
    titleEn: 'Lightning — get low and away from tall things',
    titleHi: 'बिजली — नीचे रहें और ऊँची चीज़ों से दूर',
    textEn:
        'Move away from open fields, isolated trees, and tall metal objects. Do not shelter under a lone tree. Get inside a building or a vehicle. If caught in the open, crouch low on the balls of your feet and keep away from water. Stay off the phone unless it is an emergency.',
    textHi:
        'खुले मैदान, अकेले पेड़ और ऊँची धातु की चीज़ों से दूर जाएं। अकेले पेड़ के नीचे शरण न लें। इमारत या गाड़ी में जाएं। खुले में फंसे हों तो पंजों पर नीचे झुकें और पानी से दूर रहें। आपातकाल के अलावा फोन न करें।',
    tags: ['lightning', 'बिजली', 'thunder', 'तूफान', 'storm'],
    source: 'NDMA lightning guidance',
  ),
  KnowledgeChunk(
    id: 'cyclone',
    hazard: 'cyclone',
    titleEn: 'Cyclone — shelter in an interior room, expect outages',
    titleHi: 'चक्रवात — भीतरी कमरे में शरण, बिजली जाने की तैयारी',
    textEn:
        'Stay away from windows. Shelter in a small interior room near a thick wall, ideally on the lowest floor of a strong building, or in an official cyclone shelter. Keep away from the coast. Expect power and water outages for days — store drinking water and charge your phone. Do not go outside during the calm eye of the storm.',
    textHi:
        'खिड़कियों से दूर रहें। मज़बूत इमारत के निचले हिस्से के छोटे भीतरी कमरे में, मोटी दीवार के पास शरण लें, या सरकारी चक्रवात आश्रय में जाएं। तट से दूर रहें। कई दिन बिजली-पानी बंद रह सकता है — पीने का पानी रखें और फोन चार्ज करें। तूफान की शांत आँख के दौरान बाहर न जाएं।',
    tags: ['cyclone', 'चक्रवात', 'storm', 'तूफान', 'coast', 'तट'],
    source: 'NDMA cyclone guidance',
  ),
  KnowledgeChunk(
    id: 'sign_reading',
    hazard: 'general',
    titleEn: 'Read official warning boards before you rely on them',
    titleHi: 'आधिकारिक चेतावनी बोर्ड पढ़ें, उससे पहले भरोसा न करें',
    textEn:
        'Official warning boards and temple/road notices in hill states are often in the local script. If you cannot read it, use the camera feature to translate and simplify it. A red or orange board means act or prepare now; yellow means watch. Never assume a quiet board means no danger.',
    textHi:
        'पहाड़ी राज्यों के आधिकारिक चेतावनी बोर्ड और मंदिर/सड़क सूचनाएं अक्सर स्थानीय लिपि में होती हैं। पढ़ न पाएं तो कैमरा से अनुवाद और सरल करें। लाल या नारंगी बोर्ड का मतलब अभी कार्रवाई या तैयारी; पीला मतलब नज़र रखें। शांत बोर्ड का मतलब खतरा नहीं, यह न मानें।',
    tags: ['sign', 'बोर्ड', 'notice', 'सूचना', 'warning', 'चेतावनी', 'translate'],
    source: 'IMD colour-code warning system',
  ),
];

/// Very small, dependency-free retriever. Scores chunks by token overlap
/// with the query (English + Devanagari aware) and returns the best few.
/// Runs in microseconds and works with zero model, so RAG grounding is
/// always available even when the LLM is not.
class KnowledgeRetriever {
  static List<KnowledgeChunk> search(
    String query, {
    int limit = 3,
    String? hazardHint,
  }) {
    final queryTokens = _tokens(query);
    if (queryTokens.isEmpty) return [];

    final scored = <MapEntry<KnowledgeChunk, double>>[];
    for (final chunk in disasterKnowledge) {
      var score = 0.0;
      final haystack = _tokens(
          '${chunk.titleEn} ${chunk.titleHi} ${chunk.textEn} ${chunk.textHi} ${chunk.tags.join(' ')}');
      for (final q in queryTokens) {
        if (haystack.contains(q)) score += 2.0;
        // partial/prefix match (helps Hindi inflections + English variants)
        if (q.length >= 3 && haystack.any((h) => h.startsWith(q))) {
          score += 0.5;
        }
      }
      if (hazardHint != null && chunk.hazard == hazardHint) score += 3.0;
      if (score > 0) scored.add(MapEntry(chunk, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  static Set<String> _tokens(String input) {
    final lower = input.toLowerCase();
    // Split on anything that is not a letter (Latin or Devanagari) or digit.
    final parts = lower.split(RegExp(r'[^a-z0-9\u0900-\u097F]+'));
    return parts.where((p) => p.isNotEmpty && p.length > 1).toSet();
  }
}
