#!/usr/bin/env python3
"""Build Rakshak's task-specific supervised fine-tuning data.

Prompts are copied from lib/services/ai_engine.dart so training matches
on-device inference. Run:

    python fine-tuning/build_dataset.py

Outputs (fine-tuning/data/):
  rakshak_train.jsonl    mixed-task training split
  rakshak_eval.jsonl     held-out evaluation split (stratified)
  alert_actions.jsonl    alert -> action JSON
  distress.jsonl         voice distress -> intent JSON
  survival_qa.jsonl      grounded RAG answers
  situation_brief.jsonl  2-sentence situation briefs
  dataset-metadata.json  Kaggle dataset metadata
  stats.json             counts used by the README

No third-party dependencies. Python 3.9+.
"""
from __future__ import annotations

import argparse
import json
import random
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"

ALERT_SYSTEM = (
    "You are Rakshak, an offline disaster assistant for rural India. "
    "You convert official weather/disaster warnings into short, safe, "
    "actionable instructions. You never invent facts. You never give "
    "medical diagnoses. Reply with JSON only."
)
FIRST_AID_SYSTEM = (
    "You are a careful offline disaster first-aid guide. "
    "Answer only from the notes. No diagnosis, no guessing."
)

INTENTS = ["beacon_safe", "beacon_help", "beacon_evac", "open_survival", "unknown"]
HAZARDS = ["rain", "flood", "landslide", "earthquake", "cyclone", "heatwave", "lightning", "tsunami"]
SEVERITIES = ["red", "orange", "yellow", "green"]
HI_HAZARD = {
    "rain": "भारी बारिश",
    "flood": "बाढ़",
    "landslide": "भूस्खलन",
    "earthquake": "भूकंप",
    "cyclone": "चक्रवात",
    "heatwave": "लू",
    "lightning": "बिजली",
    "tsunami": "सुनामी",
}


def alert_user(official: str, hazard: str, severity: str, hindi: bool) -> str:
    lang = "Hindi (Devanagari)" if hindi else "English"
    return (
        f'\nOfficial warning: "{official}"\n'
        f"Hazard: {hazard}\n"
        f"Severity: {severity}\n"
        "Return JSON with keys:\n"
        '"hazard": one of rain, flood, landslide, earthquake, cyclone, heatwave, lightning, tsunami,\n'
        '"severity": red|orange|yellow|green,\n'
        f'"actions": array of 3 short imperative steps in {lang},\n'
        '"donts": array of 2 things NOT to do,\n'
        '"speak": one sentence to read aloud.\n'
        "Keep each step under 12 words. JSON only."
    )


def distress_user(spoken: str, hindi: bool) -> str:
    lang = "Hindi" if hindi else "English"
    return (
        f'\nA person in a disaster just said (may be Hindi, English or mixed): "{spoken}"\n'
        "Return JSON with keys:\n"
        '"intent": beacon_safe | beacon_help | beacon_evac | open_survival | unknown,\n'
        '"injured": true/false,\n'
        '"trapped": true/false,\n'
        '"people": number of people affected (default 1),\n'
        '"landmark": any place name mentioned or null,\n'
        f'"summary": one short sentence in {lang}.\n'
        "JSON only."
    )


def rag_user(question: str, context: str, hindi: bool) -> str:
    lang = "Hindi (Devanagari)" if hindi else "English"
    return (
        "\nUse ONLY the reference notes below to answer the question in 3 short sentences.\n"
        "If the notes do not cover it, say you are not sure and tell them to call 108.\n"
        f"Answer in {lang}.\n\n"
        "REFERENCE NOTES:\n"
        f"{context}\n\n"
        f"QUESTION: {question}"
    )


def brief_user(hazards, help_count, unknown, night, hindi):
    lang = "Hindi" if hindi else "English"
    active = ", ".join(hazards) if hazards else "none"
    return (
        f"\nWrite a 2-sentence situation brief in {lang} for a\n"
        "person in a disaster with these facts. Be calm and specific about the next action.\n"
        f"Active hazards: {active}\n"
        f"Family needing help: {help_count}. Family with no contact: {unknown}.\n"
        f"Time: {'night' if night else 'day'}."
    )


# ---------------------------------------------------------------------------
# Alert content
# ---------------------------------------------------------------------------

ALERT_HAZARDS = {
    "rain": {
        "hi": "भारी बारिश",
        "districts": ["Dehradun", "Mumbai", "Guwahati", "Kolkata"],
        "warnings": [
            ("red", "Red alert: extremely heavy rainfall over 20 cm in 24 hours with flash flood risk."),
            ("red", "Red alert: cloudburst-like intense rain and thunderstorm likely over the next 12 hours."),
            ("orange", "Orange alert: heavy to very heavy rainfall likely at isolated places. Rivers may rise."),
            ("yellow", "Yellow alert: moderate rain with heavy spells likely. Stay alert."),
            ("green", "No warning: light to moderate rain expected. No immediate danger."),
        ],
        "actions_en": [
            "Move to higher ground if you are near a stream.",
            "Never walk or drive through moving water.",
            "If trapped, go to the roof with something that floats.",
            "Stay off bridges that floodwater has hit.",
            "Keep your phone, torch and drinking water ready.",
            "Listen for official warnings and be ready to move.",
        ],
        "actions_hi": [
            "नदी-नालों के पास से ऊँची जगह जाएं।",
            "बहते पानी में कभी न चलें या गाड़ी न चलाएं।",
            "फंसे हों तो छत पर जाएं और तैरने वाली चीज़ लें।",
            "पानी से टकराए पुलों पर न जाएं।",
            "फोन, टॉर्च और पीने का पानी तैयार रखें।",
            "आधिकारिक चेतावनी सुनें और निकलने के लिए तैयार रहें।",
        ],
        "donts_en": [
            "Do not walk or drive through floodwater.",
            "Do not sleep in a riverbed.",
            "Do not cross a bridge hit by water.",
        ],
        "donts_hi": [
            "बाढ़ के पानी में न चलें, न गाड़ी चलाएं।",
            "नदी किनारे न सोएं।",
            "पानी से टकराए पुल पर न जाएं।",
        ],
        "core_en": "move away from streams and low ground, and keep a torch and water ready",
        "core_hi": "नदी-नालों और निचली जगह से दूर जाएं, और टॉर्च-पानी तैयार रखें",
    },
    "flood": {
        "hi": "बाढ़",
        "districts": ["Wayanad", "Guwahati", "Puri", "Surat"],
        "warnings": [
            ("red", "CWC red alert: severe flood situation. River is flowing above danger level and rising."),
            ("red", "Flash flood warning: water level rising rapidly after a cloudburst. Move away from the stream."),
            ("orange", "CWC warning: river approaching danger level. Low-lying areas may be inundated."),
            ("yellow", "Flood watch: water levels are rising slowly in the river."),
            ("green", "No flood warning: river levels are normal."),
        ],
        "actions_en": [
            "Move to higher ground now.",
            "Never walk or drive through moving water.",
            "If trapped, go to the roof with something that floats.",
            "Stay off bridges that floodwater has hit.",
            "Keep your phone and torch dry.",
            "Signal rescuers from a visible place.",
        ],
        "actions_hi": [
            "अभी ऊँची जगह जाएं।",
            "बहते पानी में न चलें, न गाड़ी चलाएं।",
            "फंसे हों तो छत पर जाएं और तैरने वाली चीज़ लें।",
            "पानी से टकराए पुलों पर न जाएं।",
            "फोन और टॉर्च सूखे रखें।",
            "दिखने वाली जगह से बचाव दल को संकेत दें।",
        ],
        "donts_en": [
            "Do not enter floodwater.",
            "Do not return home until officials say it is safe.",
            "Do not drink floodwater.",
        ],
        "donts_hi": [
            "बाढ़ के पानी में न उतरें।",
            "अधिकारी सुरक्षित कहें तब तक घर न लौटें।",
            "बाढ़ का पानी न पिएं।",
        ],
        "core_en": "move to higher ground now and never walk through moving water",
        "core_hi": "अभी ऊँची जगह जाएं और बहते पानी में कभी न चलें",
    },
    "landslide": {
        "hi": "भूस्खलन",
        "districts": ["Wayanad", "Kedarnath", "Darjeeling", "Shimla"],
        "warnings": [
            ("red", "GSI red alert: very high landslide risk due to continuous heavy rain. Avoid slopes."),
            ("red", "Landslide reported on the highway. Debris is blocking the road and the slope is unstable."),
            ("orange", "GSI orange alert: high landslide risk along hill roads and slopes."),
            ("yellow", "Landslide watch: saturated soil may trigger isolated slides."),
            ("green", "No landslide warning: soil moisture is normal."),
        ],
        "actions_en": [
            "Move sideways out of the slide path.",
            "Then go uphill only if it is safe.",
            "Watch for a second slide after the first stops.",
            "Listen for rumbling and ground vibration.",
            "Stay away from slopes and cliff edges.",
            "Warn neighbours and move together.",
        ],
        "actions_hi": [
            "स्लाइड के रास्ते से बगल में हटें।",
            "सुरक्षित हो तो ऊपर जाएं।",
            "पहली स्लाइड रुकने के बाद दूसरी का ध्यान रखें।",
            "गुरुज और ज़मीन के कंपन पर ध्यान दें।",
            "ढलान और चट्टान के किनारों से दूर रहें।",
            "पड़ोसियों को चेताएं और साथ चलें।",
        ],
        "donts_en": [
            "Do not run downhill in front of the slide.",
            "Do not shelter under a slope.",
            "Do not go near a dammed stream.",
        ],
        "donts_hi": [
            "स्लाइड के सामने नीचे न भागें।",
            "ढलान के नीचे शरण न लें।",
            "रुके पानी के पास न जाएं।",
        ],
        "core_en": "move sideways out of the slide path and stay away from slopes",
        "core_hi": "स्लाइड के रास्ते से बगल में हटें और ढलानों से दूर रहें",
    },
    "earthquake": {
        "hi": "भूकंप",
        "districts": ["Guwahati", "Imphal", "Dehradun", "Kohima"],
        "warnings": [
            ("red", "Earthquake of magnitude 6.2 recorded. Strong shaking felt. Aftershocks likely."),
            ("red", "Major earthquake warning after a 6.8 magnitude event. Buildings may be damaged."),
            ("orange", "Earthquake of magnitude 5.1 recorded. Moderate shaking felt in the district."),
            ("yellow", "Minor earthquake of magnitude 3.8 recorded. No damage expected."),
            ("green", "No earthquake warning. Seismic activity is normal."),
        ],
        "actions_en": [
            "Drop, cover under a sturdy table, and hold on.",
            "Cover your head and neck if there is no table.",
            "Stay away from windows and heavy falling objects.",
            "If outdoors, move to an open area.",
            "After shaking, check for injuries and gas leaks.",
            "Use the stairs and never the lift.",
        ],
        "actions_hi": [
            "घुटनों पर आएं, मेज़ के नीचे शरण लें, पकड़े रहें।",
            "मेज़ न हो तो सिर और गर्दन ढकें।",
            "खिड़कियों और भारी गिरने वाली चीज़ों से दूर रहें।",
            "बाहर हों तो खुले मैदान में जाएं।",
            "झटकों के बाद चोट और गैस लीक जांचें।",
            "सीढ़ियां इस्तेमाल करें, लिफ्ट कभी नहीं।",
        ],
        "donts_en": [
            "Do not run outside during shaking.",
            "Do not use lifts.",
            "Do not light a match if you smell gas.",
        ],
        "donts_hi": [
            "झटकों के दौरान बाहर न भागें।",
            "लिफ्ट न लें।",
            "गैस की गंध पर माचिस न जलाएं।",
        ],
        "core_en": "drop, cover and hold on, and stay away from windows",
        "core_hi": "झुकें, ढकें, पकड़ें, और खिड़कियों से दूर रहें",
    },
}

ALERT_HAZARDS.update({
    "cyclone": {
        "hi": "चक्रवात",
        "districts": ["Puri", "Chennai", "Kolkata", "Visakhapatnam"],
        "warnings": [
            ("red", "Cyclone red alert: very severe cyclonic storm expected to cross the coast in 12 hours."),
            ("red", "Extremely severe cyclone approaching. Evacuate coastal areas immediately."),
            ("orange", "Cyclone orange alert: cyclonic storm likely to bring heavy wind and rain."),
            ("yellow", "Cyclone watch: depression over the sea may intensify."),
            ("green", "No cyclone warning. Sea conditions are normal."),
        ],
        "actions_en": [
            "Move to an official cyclone shelter or a strong building.",
            "Shelter in a small interior room away from windows.",
            "Stay away from the coast and low-lying areas.",
            "Store drinking water and charge your phone.",
            "Stay indoors during the calm eye of the storm.",
            "Secure loose objects before the wind rises.",
        ],
        "actions_hi": [
            "सरकारी चक्रवात आश्रय या मज़बूत इमारत में जाएं।",
            "खिड़कियों से दूर छोटे भीतरी कमरे में शरण लें।",
            "तट और निचले इलाकों से दूर रहें।",
            "पीने का पानी रखें और फोन चार्ज करें।",
            "तूफान की शांत आँख में घर के अंदर रहें।",
            "हवा तेज़ होने से पहले ढीली चीज़ें बांधें।",
        ],
        "donts_en": [
            "Do not go outside during the eye.",
            "Do not shelter under trees or tin roofs.",
            "Do not ignore evacuation orders.",
        ],
        "donts_hi": [
            "आँख के दौरान बाहर न जाएं।",
            "पेड़ या टिन की छत के नीचे शरण न लें।",
            "निकासी आदेश न टालें।",
        ],
        "core_en": "shelter in a strong interior room and stay away from the coast",
        "core_hi": "मज़बूत भीतरी कमरे में शरण लें और तट से दूर रहें",
    },
    "heatwave": {
        "hi": "लू",
        "districts": ["Nagpur", "Delhi", "Jaipur", "Ahmedabad"],
        "warnings": [
            ("red", "Red heat wave alert: severe heat wave conditions for the next 3 days."),
            ("red", "Severe heat wave declared. Day temperatures above 45 degrees Celsius."),
            ("orange", "Orange heat wave alert: heat wave likely in isolated pockets."),
            ("yellow", "Yellow heat wave watch: above-normal temperatures likely."),
            ("green", "No heat wave warning. Temperatures are normal."),
        ],
        "actions_en": [
            "Stay indoors between noon and four PM.",
            "Drink water often, even if you are not thirsty.",
            "Keep ORS ready for children and elderly people.",
            "Move a hot, confused person to shade.",
            "Cool them with water and strong fanning.",
            "Call 108 immediately for heat stroke.",
        ],
        "actions_hi": [
            "दोपहर 12 से 4 बजे तक घर में रहें।",
            "प्यास न लगे तो भी पानी पिएं।",
            "बच्चों और बुज़ुर्गों के लिए ORS रखें।",
            "गर्म, भ्रमित व्यक्ति को छाया में ले जाएं।",
            "पानी और तेज़ हवा से ठंडा करें।",
            "हीट स्ट्रोक पर तुरंत 108 पर कॉल करें।",
        ],
        "donts_en": [
            "Do not go out in the afternoon heat.",
            "Do not give ice-cold water.",
            "Do not leave children in a parked vehicle.",
        ],
        "donts_hi": [
            "दोपहर की गर्मी में बाहर न जाएं।",
            "बर्फ़ जैसा ठंडा पानी न दें।",
            "बच्चों को खड़ी गाड़ी में न छोड़ें।",
        ],
        "core_en": "stay out of the afternoon heat and drink water often",
        "core_hi": "दोपहर की गर्मी से बचें और पानी पीते रहें",
    },
    "lightning": {
        "hi": "बिजली",
        "districts": ["Kolkata", "Patna", "Bhubaneswar", "Ranchi"],
        "warnings": [
            ("red", "Red alert: thunderstorm with frequent lightning and hail likely."),
            ("red", "Severe thunderstorm with dense lightning strikes moving across the district."),
            ("orange", "Orange alert: thunderstorm with lightning likely at isolated places."),
            ("yellow", "Yellow alert: thunderstorm with lightning possible."),
            ("green", "No thunderstorm warning."),
        ],
        "actions_en": [
            "Move inside a building or a vehicle.",
            "Stay away from open fields and isolated trees.",
            "Get low on the balls of your feet outside.",
            "Keep away from water and metal objects.",
            "Stay off the phone unless it is urgent.",
            "Wait 30 minutes after the last thunder.",
        ],
        "actions_hi": [
            "इमारत या गाड़ी के अंदर जाएं।",
            "खुले मैदान और अकेले पेड़ों से दूर रहें।",
            "बाहर हों तो पंजों पर नीचे झुकें।",
            "पानी और धातु की चीज़ों से दूर रहें।",
            "ज़रूरी न हो तो फोन न करें।",
            "आखिरी गड़गड़ाहट के 30 मिनट बाद तक रुकें।",
        ],
        "donts_en": [
            "Do not shelter under a lone tree.",
            "Do not stand in open ground.",
            "Do not use wired electrical equipment.",
        ],
        "donts_hi": [
            "अकेले पेड़ के नीचे शरण न लें।",
            "खुले मैदान में खड़े न रहें।",
            "तार वाले बिजली के उपकरण न इस्तेमाल करें।",
        ],
        "core_en": "get inside a building or vehicle and stay away from trees",
        "core_hi": "इमारत या गाड़ी में जाएं और पेड़ों से दूर रहें",
    },
    "tsunami": {
        "hi": "सुनामी",
        "districts": ["Puri", "Chennai", "Andaman", "Kanyakumari"],
        "warnings": [
            ("red", "Tsunami red alert: large waves expected to hit the coast within 30 minutes."),
            ("red", "Tsunami warning after a major undersea earthquake. Move inland immediately."),
            ("orange", "Tsunami orange alert: possible tsunami waves along the coast."),
            ("yellow", "Tsunami watch: undersea earthquake may generate waves."),
            ("green", "No tsunami warning."),
        ],
        "actions_en": [
            "Move inland and to higher ground immediately.",
            "Follow evacuation signs and official routes.",
            "Stay away from the beach and river mouths.",
            "Do not wait to see the wave.",
            "Stay on high ground until the all-clear.",
            "Help children, elderly and disabled neighbours.",
        ],
        "actions_hi": [
            "तुरंत अंदर और ऊँची जगह जाएं।",
            "निकासी संकेत और सरकारी रास्ते अपनाएं।",
            "समुद्र तट और नदी मुहाने से दूर रहें।",
            "लहर देखने के लिए न रुकें।",
            "अधिकारी सुरक्षित कहें तब तक ऊँची जगह रहें।",
            "बच्चों, बुज़ुर्गों और दिव्यांग पड़ोसियों की मदद करें।",
        ],
        "donts_en": [
            "Do not go to the coast to watch.",
            "Do not return until the all-clear.",
            "Do not use the phone unless urgent.",
        ],
        "donts_hi": [
            "लहर देखने तट पर न जाएं।",
            "ऑल-क्लियर से पहले न लौटें।",
            "ज़रूरी न हो तो फोन न करें।",
        ],
        "core_en": "move inland and to higher ground immediately",
        "core_hi": "तुरंत अंदर और ऊँची जगह जाएं",
    },
})

GREEN_ACTIONS_EN = [
    "No immediate action is needed.",
    "Keep your phone charged.",
    "Monitor official updates.",
]
GREEN_ACTIONS_HI = [
    "अभी कोई तुरंत कार्रवाई नहीं चाहिए।",
    "फोन चार्ज रखें।",
    "आधिकारिक अपडेट देखते रहें।",
]
GREEN_DONTS_EN = ["Do not ignore official updates.", "Do not spread rumours."]
GREEN_DONTS_HI = ["आधिकारिक अपडेट नजरअंदाज न करें।", "अफवाह न फैलाएं।"]


def alert_records() -> list:
    records = []
    n = 0
    for hazard, block in ALERT_HAZARDS.items():
        for severity, official in block["warnings"]:
            for district in block["districts"][:2]:
                for hindi in (False, True):
                    n += 1
                    text = f"District: {district}. {official}"
                    if severity == "green":
                        actions = GREEN_ACTIONS_HI if hindi else GREEN_ACTIONS_EN
                        donts = GREEN_DONTS_HI if hindi else GREEN_DONTS_EN
                    else:
                        actions = (block["actions_hi"] if hindi else block["actions_en"])[:3]
                        donts = (block["donts_hi"] if hindi else block["donts_en"])[:2]
                    if hindi:
                        if severity == "red":
                            speak = f"लाल अलर्ट, {block['hi']}: {block['core_hi']}।"
                        elif severity == "orange":
                            speak = f"ऑरेंज अलर्ट, {block['hi']}: तैयार रहें और {block['core_hi']}।"
                        elif severity == "yellow":
                            speak = f"येलो अलर्ट, {block['hi']}: सावधान रहें और {block['core_hi']}।"
                        else:
                            speak = (
                                f"ग्रीन अलर्ट, {block['hi']}: अभी कोई तुरंत खतरा नहीं, "
                                "आधिकारिक अपडेट देखते रहें।"
                            )
                    else:
                        if severity == "red":
                            speak = f"Red alert for {hazard}: {block['core_en']}."
                        elif severity == "orange":
                            speak = f"Orange alert for {hazard}: be ready to act, and {block['core_en']}."
                        elif severity == "yellow":
                            speak = f"Yellow alert for {hazard}: stay alert, and {block['core_en']}."
                        else:
                            speak = (
                                f"Green alert for {hazard}: no immediate danger, "
                                "but monitor official updates."
                            )
                    assistant = {
                        "hazard": hazard,
                        "severity": severity,
                        "actions": actions,
                        "donts": donts,
                        "speak": speak,
                    }
                    records.append({
                        "id": f"alert_{hazard}_{severity}_{district}_{int(hindi)}_{n:04d}",
                        "task": "alert",
                        "lang": "hi" if hindi else "en",
                        "system": ALERT_SYSTEM,
                        "user": alert_user(text, hazard, severity, hindi),
                        "assistant": json.dumps(assistant, ensure_ascii=False),
                        "meta": {
                            "hazard": hazard,
                            "severity": severity,
                            "district": district,
                            "hindi": hindi,
                        },
                    })
    return records


# ---------------------------------------------------------------------------
# Distress content: (spoken, intent, injured, trapped, people, landmark, en, hi)
# ---------------------------------------------------------------------------

DISTRESS_ROWS = [
    ("We are all safe at the school", "beacon_safe", False, False, 4, "school", "The family is safe at the school.", "परिवार स्कूल में सुरक्षित है।"),
    ("Hum log mandir ke paas safe hain", "beacon_safe", False, False, 5, "temple", "Five people are safe near the temple.", "पाँच लोग मंदिर के पास सुरक्षित हैं।"),
    ("मैं और मेरा परिवार सुरक्षित हैं", "beacon_safe", False, False, 3, None, "The family is safe.", "परिवार सुरक्षित है।"),
    ("All five of us reached the hill top", "beacon_safe", False, False, 5, "hill top", "Five people reached the hill top safely.", "पाँच लोग सुरक्षित रूप से पहाड़ी की चोटी पर पहुँच गए।"),
    ("We are safe, staying on the roof", "beacon_safe", False, False, 2, "roof", "Two people are safe on the roof.", "दो लोग छत पर सुरक्षित हैं।"),
    ("Hum sab theek hain, ghar ke bahar hain", "beacon_safe", False, False, 4, None, "Four people are safe outside the house.", "चार लोग घर के बाहर सुरक्षित हैं।"),
    ("My mother and I are safe at the relief camp", "beacon_safe", False, False, 2, "relief camp", "Two people are safe at the relief camp.", "दो लोग राहत शिविर में सुरक्षित हैं।"),
    ("हम दो लोग सुरक्षित हैं, स्कूल में हैं", "beacon_safe", False, False, 2, "school", "Two people are safe at the school.", "दो लोग स्कूल में सुरक्षित हैं।"),
    ("We reached the temple, everyone is safe", "beacon_safe", False, False, 6, "temple", "Six people are safe at the temple.", "छह लोग मंदिर में सुरक्षित हैं।"),
    ("Bachche safe hain, hum pahadi par hain", "beacon_safe", False, False, 3, "hill", "The children are safe on the hill.", "बच्चे पहाड़ी पर सुरक्षित हैं।"),
    ("I am safe, I am with my family", "beacon_safe", False, False, 4, None, "The person is safe with family.", "व्यक्ति परिवार के साथ सुरक्षित है।"),
    ("हम सब ठीक हैं, मदद की ज़रूरत नहीं", "beacon_safe", False, False, 5, None, "Everyone is safe and no help is needed.", "सब सुरक्षित हैं, मदद की ज़रूरत नहीं।"),
    ("I am injured near the bridge", "beacon_help", True, False, 1, "bridge", "One injured person needs help near the bridge.", "एक घायल व्यक्ति को पुल के पास मदद चाहिए।"),
    ("Mera pair tut gaya, hum do log phanse hain", "beacon_help", True, True, 2, None, "Two people are trapped and one has a broken leg.", "दो लोग फंसे हैं और एक का पैर टूटा है।"),
    ("मेरी माँ घायल है, हम मंदिर के पास हैं", "beacon_help", True, False, 2, "temple", "Two people need help and the mother is injured near the temple.", "दो लोगों को मदद चाहिए और माँ मंदिर के पास घायल है।"),
    ("We are trapped under debris, 4 people", "beacon_help", False, True, 4, None, "Four people are trapped under debris.", "चार लोग मलबे के नीचे फंसे हैं।"),
    ("Paani ghar mein aa gaya, bachao", "beacon_help", False, False, 3, None, "Three people need help as water enters the house.", "घर में पानी आ गया है और तीन लोगों को मदद चाहिए।"),
    ("Mera bhai behosh hai, school ke paas", "beacon_help", True, False, 2, "school", "Two people need help and the brother is unconscious near the school.", "दो लोगों को मदद चाहिए और भाई स्कूल के पास बेहोश है।"),
    ("We need help, three children with us near the river", "beacon_help", False, False, 4, "river", "Four people, including three children, need help near the river.", "नदी के पास तीन बच्चों सहित चार लोगों को मदद चाहिए।"),
    ("मैं मलबे में फंसा हूँ, पैर में चोट है", "beacon_help", True, True, 1, None, "One injured person is trapped in debris.", "एक घायल व्यक्ति मलबे में फंसा है।"),
    ("Please help, my father is bleeding", "beacon_help", True, False, 2, None, "Two people need help and the father is bleeding.", "दो लोगों को मदद चाहिए और पिता का खून बह रहा है।"),
    ("Hum paanch log chhat par hain, paani badh raha hai", "beacon_help", False, False, 5, "roof", "Five people are on the roof as water rises.", "पानी बढ़ रहा है और पाँच लोग छत पर हैं।"),
    ("There is a landslide, we are stuck near the temple", "beacon_help", False, True, 3, "temple", "Three people are stuck near the temple after a landslide.", "भूस्खलन के बाद तीन लोग मंदिर के पास फंसे हैं।"),
    ("Meri maa ko saans nahi aa rahi, jaldi aao", "beacon_help", True, False, 2, None, "Two people need urgent help and the mother is not breathing.", "दो लोगों को तुरंत मदद चाहिए और माँ की साँस रुक रही है।"),
    ("We are buried, please send help", "beacon_help", False, True, 3, None, "Three people are buried and need rescue.", "तीन लोग मलबे में दबे हैं और बचाव चाहिए।"),
    ("मेरा बच्चा घायल है, हम नदी के पास हैं", "beacon_help", True, False, 2, "river", "Two people need help and the child is injured near the river.", "दो लोगों को मदद चाहिए और बच्चा नदी के पास घायल है।"),
    ("I am stuck on the first floor, water is rising", "beacon_help", False, True, 1, "first floor", "One person is stuck on the first floor as water rises.", "पानी बढ़ रहा है और एक व्यक्ति पहली मंज़िल पर फंसा है।"),
    ("Gaadi paani mein phansi hai, hum teen log hain", "beacon_help", False, True, 3, "car", "Three people are trapped in a car in the water.", "तीन लोग पानी में फंसी गाड़ी में हैं।"),
    ("We are leaving for higher ground", "beacon_evac", False, False, 4, None, "Four people are evacuating to higher ground.", "चार लोग ऊँची जगह की ओर निकल रहे हैं।"),
    ("Hum gaon khaali kar rahe hain", "beacon_evac", False, False, 6, None, "Six people are evacuating the village.", "छह लोग गाँव खाली कर रहे हैं।"),
    ("हम स्कूल की ओर निकल रहे हैं", "beacon_evac", False, False, 4, "school", "Four people are moving toward the school.", "चार लोग स्कूल की ओर निकल रहे हैं।"),
    ("Family is moving to the temple on the hill", "beacon_evac", False, False, 5, "temple", "Five people are moving to the temple on the hill.", "पाँच लोग पहाड़ी के मंदिर की ओर जा रहे हैं।"),
    ("We are evacuating now, taking the children", "beacon_evac", False, False, 4, None, "Four people are evacuating with the children.", "चार लोग बच्चों के साथ अभी निकल रहे हैं।"),
    ("Hum sab nadi ke us paar ja rahe hain", "beacon_evac", False, False, 5, "river", "Five people are moving away from the river.", "पाँच लोग नदी से दूर जा रहे हैं।"),
    ("हम ऊपर पहाड़ी पर जा रहे हैं, छह लोग हैं", "beacon_evac", False, False, 6, "hill", "Six people are moving up the hill.", "छह लोग पहाड़ी पर ऊपर जा रहे हैं।"),
    ("We left the house and are going to the camp", "beacon_evac", False, False, 3, "relief camp", "Three people left the house and are going to the camp.", "तीन लोग घर छोड़कर शिविर जा रहे हैं।"),
    ("What do I do in a flood", "open_survival", False, False, 1, None, "The person is asking what to do in a flood.", "व्यक्ति पूछ रहा है कि बाढ़ में क्या करें।"),
    ("Bleeding kaise rokhein", "open_survival", True, False, 1, None, "The person is asking how to stop bleeding.", "व्यक्ति पूछ रहा है कि खून कैसे रोकें।"),
    ("भूकंप में क्या करें", "open_survival", False, False, 1, None, "The person is asking what to do in an earthquake.", "व्यक्ति पूछ रहा है कि भूकंप में क्या करें।"),
    ("Landslide ho raha hai kya karun", "open_survival", False, False, 1, None, "The person is asking what to do during a landslide.", "व्यक्ति पूछ रहा है कि भूस्खलन में क्या करें।"),
    ("Snake bite ho gaya kya karun", "open_survival", True, False, 1, None, "The person is asking what to do for a snake bite.", "व्यक्ति पूछ रहा है कि साँप के काटने पर क्या करें।"),
    ("How do I do CPR", "open_survival", False, False, 1, None, "The person is asking how to do CPR.", "व्यक्ति पूछ रहा है कि सीपीआर कैसे करें।"),
    ("हीट स्ट्रोक में क्या करें", "open_survival", False, False, 1, None, "The person is asking what to do for heat stroke.", "व्यक्ति पूछ रहा है कि हीट स्ट्रोक में क्या करें।"),
    ("Bijli gir rahi hai, kya karein", "open_survival", False, False, 1, None, "The person is asking what to do during lightning.", "व्यक्ति पूछ रहा है कि बिजली गिरने पर क्या करें।"),
    ("Cyclone aa raha hai, kahan jayein", "open_survival", False, False, 1, None, "The person is asking where to go during a cyclone.", "व्यक्ति पूछ रहा है कि चक्रवात में कहाँ जाएँ।"),
    ("What should I do if someone is not breathing", "open_survival", True, False, 1, None, "The person is asking what to do if someone is not breathing.", "व्यक्ति पूछ रहा है कि किसी की साँस रुकने पर क्या करें।"),
    ("Hello, can you hear me", "unknown", False, False, 1, None, "The message could not be understood.", "संदेश समझ नहीं आया।"),
    ("Koi hai?", "unknown", False, False, 1, None, "The message could not be understood.", "संदेश समझ नहीं आया।"),
    ("...", "unknown", False, False, 1, None, "The message could not be understood.", "संदेश समझ नहीं आया।"),
    ("Test test", "unknown", False, False, 1, None, "The message could not be understood.", "संदेश समझ नहीं आया।"),
    ("मेरा नाम राहुल है", "unknown", False, False, 1, None, "The message does not contain a clear request.", "संदेश में स्पष्ट अनुरोध नहीं है।"),
]


def distress_records() -> list:
    records = []
    for n, row in enumerate(DISTRESS_ROWS, start=1):
        spoken, intent, injured, trapped, people, landmark, sm_en, sm_hi = row
        for hindi in (False, True):
            assistant = {
                "intent": intent,
                "injured": injured,
                "trapped": trapped,
                "people": people,
                "landmark": landmark,
                "summary": sm_hi if hindi else sm_en,
            }
            records.append({
                "id": f"distress_{intent}_{n:04d}_{int(hindi)}",
                "task": "distress",
                "lang": "hi" if hindi else "en",
                "system": ALERT_SYSTEM,
                "user": distress_user(spoken, hindi),
                "assistant": json.dumps(assistant, ensure_ascii=False),
                "meta": {
                    "intent": intent,
                    "injured": injured,
                    "trapped": trapped,
                    "people": people,
                    "landmark": landmark,
                    "hindi": hindi,
                },
            })
    return records


# ---------------------------------------------------------------------------
# Survival RAG content (copied from lib/data/disaster_knowledge.dart)
# ---------------------------------------------------------------------------

KNOWLEDGE = [
    {
        "id": "flood_moving_water",
        "title_en": "Moving water kills — go up, never through",
        "title_hi": "बहता पानी जान लेता है — ऊपर जाएं, पार न करें",
        "text_en": "Move to higher ground immediately. Never walk or drive through moving water: 15 cm can knock an adult down, 30 cm can move a car. If water enters the room, go to the roof and take something that floats. Stay off bridges that water has hit.",
        "text_hi": "तुरंत ऊँची जगह जाएं। बहते पानी में कभी न चलें या गाड़ी न चलाएं: 15 सेंटीमीटर पानी वयस्क को गिरा सकता है, 30 सेंटीमीटर गाड़ी बहा सकता है। पानी कमरे में आए तो छत पर जाएं और तैरने वाली चीज़ साथ लें। पानी से टकराए पुलों पर न जाएं।",
        "source": "NDMA flood dos and don'ts",
    },
    {
        "id": "flood_night",
        "title_en": "Night flood warning — leave before it is certain",
        "title_hi": "रात में बाढ़ की चेतावनी — पक्का होने से पहले निकलें",
        "text_en": "If a warning arrives at night, leave. Do not wait for certainty. Dress children, take the go-bag (torch, water, phone, charger, ID, medicine), and walk uphill away from streams and slopes. Use a torch, not the phone screen, to save battery. Go to a pre-agreed family meeting point.",
        "text_hi": "रात में चेतावनी आए तो निकल जाएं। पक्का होने का इंतज़ार न करें। बच्चों को पहनाएं, बैग लें (टॉर्च, पानी, फोन, चार्जर, पहचान पत्र, दवा), और नालों व ढलानों से दूर ऊपर चलें। बैटरी बचाने के लिए टॉर्च चलाएं, फोन स्क्रीन नहीं। पहले से तय परिवार की जगह पर जाएं।",
        "source": "Wayanad 2024 after-action + NDMA guidance",
    },
    {
        "id": "landslide_slope",
        "title_en": "Landslide — move sideways, expect a second slide",
        "title_hi": "भूस्खलन — बगल में हटें, दूसरी स्लाइड की तैयारी रखें",
        "text_en": "Move horizontally out of the slide path, then uphill if it is safe. Do not run downhill in front of it. After it stops, stay away — landslides come in clusters, and rain after the first slide keeps the ground unstable. Never sleep below a slope, in a ravine, or near a cliff during heavy rain.",
        "text_hi": "स्लाइड के रास्ते से बगल में हटें, सुरक्षित हो तो ऊपर जाएं। इसके सामने नीचे की ओर न भागें। रुकने के बाद दूर रहें — भूस्खलन एक साथ कई बार आते हैं, और बारिश ज़मीन को अस्थिर रखती है। भारी बारिश में ढलान के नीचे, नाले या चट्टान के पास कभी न सोएं।",
        "source": "GSI landslide guidance + NDMA",
    },
    {
        "id": "earthquake_drop_cover",
        "title_en": "Earthquake — drop, cover, hold on",
        "title_hi": "भूकंप — झुकें, ढकें, पकड़ें",
        "text_en": "Drop to hands and knees, take cover under a sturdy table, and hold on. If there is no table, cover your head and neck against an interior wall. Stay away from windows and heavy objects. Do not run outside while the ground is shaking. Do not use lifts. If outdoors, move to an open area away from buildings and power lines.",
        "text_hi": "घुटनों पर आएं, मज़बूत मेज़ के नीचे शरण लें, और पकड़े रहें। मेज़ न हो तो भीतरी दीवार के पास सिर और गर्दन ढकें। खिड़कियों और भारी सामान से दूर रहें। ज़मीन हिलते समय बाहर न भागें। लिफ्ट न लें। बाहर हों तो खुले मैदान में जाएं।",
        "source": "NDMA earthquake dos and don'ts",
    },
    {
        "id": "trapped_debris",
        "title_en": "Trapped in debris — save breath, signal with taps",
        "title_hi": "मलबे में फंसे — साँस बचाएं, थप्पी से संकेत दें",
        "text_en": "Cover your mouth and nose with cloth to keep dust out. Do not shout continuously; it wastes breath and energy. Tap on a pipe or wall in a rhythm rescuers recognise: three taps, pause, repeat. Keep your phone in your hand and use it only for beacons, not the torch, to save battery. Do not move heavy debris above you.",
        "text_hi": "धूल से बचने के लिए कपड़े से मुँह-नाक ढकें। लगातार चिल्लाएं न; साँस और ऊर्जा बचाएं। पाइप या दीवार पर लय में थप्पी मारें: तीन थप्पी, रुकें, दोहराएं। फोन हाथ में रखें, बैटरी बचाने के लिए टॉर्च की तरह इस्तेमाल न करें। ऊपर का भारी मलबा न हिलाएं।",
        "source": "NDRF collapsed-structure guidance",
    },
    {
        "id": "bleeding_control",
        "title_en": "Severe bleeding — press hard, do not remove soaked cloth",
        "title_hi": "तेज़ खून — ज़ोर से दबाएं, भीगा कपड़ा न हटाएं",
        "text_en": "Press hard directly on the wound with cloth. Do not remove a soaked cloth — add more layers on top. Raise the limb above heart level if possible. If an object is embedded, do not pull it out; pad around it. Keep the person warm and still, and watch for shock: pale skin, cold sweat, fast breathing. Call 108.",
        "text_hi": "घाव पर कपड़े से सीधे ज़ोर से दबाएं। भीगा कपड़ा न हटाएं — ऊपर और परतें चढ़ाएं। संभव हो तो अंग को हृदय से ऊपर उठाएं। फंसी वस्तु न निकालें, उसके आसपास दबाएं। व्यक्ति को गर्म और स्थिर रखें, शॉक पर नज़र रखें: पीली त्वचा, ठंडा पसीना, तेज़ साँस। 108 पर कॉल करें।",
        "source": "WHO basic emergency care + NDMA",
    },
    {
        "id": "cpr",
        "title_en": "Not breathing — start chest compressions",
        "title_hi": "साँस नहीं — छाती दबाना शुरू करें",
        "text_en": "If the person is unresponsive and not breathing normally, start chest compressions: place the heel of your hand on the centre of the chest, press hard and fast at about 100–120 per minute, and let the chest rise fully between presses. Continue until help arrives. Call 108 on speaker while you do this.",
        "text_hi": "व्यक्ति बेहोश है और सामान्य साँस नहीं ले रहा, तो छाती दबाना शुरू करें: हथेली की जड़ छाती के बीच रखें, तेज़ और गहरा दबाएं, लगभग 100–120 बार प्रति मिनट, और बीच में छाती पूरी उठने दें। मदद आने तक जारी रखें। ऐसा करते समय 108 स्पीकर पर चलाएं।",
        "source": "WHO basic emergency care",
    },
    {
        "id": "heat_stroke",
        "title_en": "Heat stroke — cool fast, it kills within hours",
        "title_hi": "हीट स्ट्रोक — तुरंत ठंडा करें, घंटों में जान लेता है",
        "text_en": "Move the person to shade. Remove extra clothing, pour water on the skin and fan vigorously. If conscious, give small sips of water or ORS. If confused, hot and not sweating, it is heat stroke — call 108 immediately. Do not give ice-cold water.",
        "text_hi": "व्यक्ति को छाया में ले जाएं। अतिरिक्त कपड़े उतारें, त्वचा पर पानी डालें और ज़ोर से हवा करें। होश में हों तो थोड़ा पानी या ORS पिलाएं। भ्रम, गर्मी और पसीना न आना हीट स्ट्रोक है — तुरंत 108 पर कॉल करें। बर्फ़ जैसा ठंडा पानी न दें।",
        "source": "NDMA heat wave guidance",
    },
    {
        "id": "lightning",
        "title_en": "Lightning — get low and away from tall things",
        "title_hi": "बिजली — नीचे रहें और ऊँची चीज़ों से दूर",
        "text_en": "Move away from open fields, isolated trees, and tall metal objects. Do not shelter under a lone tree. Get inside a building or a vehicle. If caught in the open, crouch low on the balls of your feet and keep away from water. Stay off the phone unless it is an emergency.",
        "text_hi": "खुले मैदान, अकेले पेड़ और ऊँची धातु की चीज़ों से दूर जाएं। अकेले पेड़ के नीचे शरण न लें। इमारत या गाड़ी में जाएं। खुले में फंसे हों तो पंजों पर नीचे झुकें और पानी से दूर रहें। आपातकाल के अलावा फोन न करें।",
        "source": "NDMA lightning guidance",
    },
    {
        "id": "cyclone",
        "title_en": "Cyclone — shelter in an interior room, expect outages",
        "title_hi": "चक्रवात — भीतरी कमरे में शरण, बिजली जाने की तैयारी",
        "text_en": "Stay away from windows. Shelter in a small interior room near a thick wall, ideally on the lowest floor of a strong building, or in an official cyclone shelter. Keep away from the coast. Expect power and water outages for days — store drinking water and charge your phone. Do not go outside during the calm eye of the storm.",
        "text_hi": "खिड़कियों से दूर रहें। मज़बूत इमारत के निचले हिस्से के छोटे भीतरी कमरे में, मोटी दीवार के पास शरण लें, या सरकारी चक्रवात आश्रय में जाएं। तट से दूर रहें। कई दिन बिजली-पानी बंद रह सकता है — पीने का पानी रखें और फोन चार्ज करें। तूफान की शांत आँख के दौरान बाहर न जाएं।",
        "source": "NDMA cyclone guidance",
    },
    {
        "id": "sign_reading",
        "title_en": "Read official warning boards before you rely on them",
        "title_hi": "आधिकारिक चेतावनी बोर्ड पढ़ें, उससे पहले भरोसा न करें",
        "text_en": "Official warning boards and temple/road notices in hill states are often in the local script. If you cannot read it, use the camera feature to translate and simplify it. A red or orange board means act or prepare now; yellow means watch. Never assume a quiet board means no danger.",
        "text_hi": "पहाड़ी राज्यों के आधिकारिक चेतावनी बोर्ड और मंदिर/सड़क सूचनाएं अक्सर स्थानीय लिपि में होती हैं। पढ़ न पाएं तो कैमरा से अनुवाद और सरल करें। लाल या नारंगी बोर्ड का मतलब अभी कार्रवाई या तैयारी; पीला मतलब नज़र रखें। शांत बोर्ड का मतलब खतरा नहीं, यह न मानें।",
        "source": "IMD colour-code warning system",
    },
]

QA_ROWS = [
    ("flood_moving_water", "What should I do if floodwater is rising?", "बाढ़ का पानी बढ़ रहा है, क्या करूँ?",
     "Move to higher ground immediately. Never walk or drive through moving water, because 15 cm can knock an adult down. If water enters the room, go to the roof with something that floats.",
     "तुरंत ऊँची जगह जाएं। बहते पानी में कभी न चलें या गाड़ी न चलाएं, क्योंकि 15 सेंटीमीटर पानी वयस्क को गिरा सकता है। पानी कमरे में आए तो तैरने वाली चीज़ लेकर छत पर जाएं।"),
    ("flood_moving_water", "Can I walk through moving water?", "क्या बहते पानी में चल सकते हैं?",
     "No. Even 15 cm of moving water can knock an adult down, and 30 cm can move a car. Go up and around, never through.",
     "नहीं। 15 सेंटीमीटर बहता पानी भी वयस्क को गिरा सकता है, और 30 सेंटीमीटर गाड़ी बहा सकता है। ऊपर से जाएं, पानी के पार कभी न जाएं।"),
    ("flood_moving_water", "Is it safe to cross a bridge after a flood?", "बाढ़ के बाद पुल पार करना सुरक्षित है?",
     "Stay off bridges that water has hit. Floodwater may have weakened the structure. Use higher ground and wait for officials to declare it safe.",
     "पानी से टकराए पुलों पर न जाएं। बाढ़ ने ढांचा कमज़ोर किया हो सकता है। ऊँची जगह पर रुकें और अधिकारियों के सुरक्षित कहने का इंतज़ार करें।"),
    ("flood_night", "A flood warning came at night, should we wait?", "रात में बाढ़ की चेतावनी आई, रुकें या निकलें?",
     "Leave now. Do not wait for certainty when a warning comes at night. Dress the children, take the go-bag, and walk uphill away from streams.",
     "अभी निकल जाएं। रात में चेतावनी आए तो पक्का होने का इंतज़ार न करें। बच्चों को पहनाएं, बैग लें, और नालों से दूर ऊपर चलें।"),
    ("flood_night", "What should I take when evacuating at night?", "रात में निकलते समय क्या ले जाएं?",
     "Take a torch, water, phone, charger, ID, cash and medicine. Use a torch instead of the phone screen to save battery. Go to a pre-agreed family meeting point.",
     "टॉर्च, पानी, फोन, चार्जर, पहचान पत्र, नकद और दवा लें। बैटरी बचाने के लिए फोन स्क्रीन की जगह टॉर्च चलाएं। पहले से तय परिवार की जगह पर जाएं।"),
    ("flood_night", "Should we split up during a night evacuation?", "रात की निकासी में परिवार अलग हो सकता है?",
     "No. Keep the family together and move to the agreed meeting point. Do not go back for pets or possessions. Leave immediately.",
     "नहीं। परिवार को साथ रखें और तय जगह पर जाएं। पालतू या सामान लेने वापस न जाएं। अभी निकलें।"),
    ("landslide_slope", "What should I do during a landslide?", "भूस्खलन में क्या करें?",
     "Move sideways out of the slide path, then uphill only if it is safe. Do not run downhill in front of the slide. Stay away from slopes and cliff edges.",
     "स्लाइड के रास्ते से बगल में हटें, फिर सुरक्षित हो तो ऊपर जाएं। स्लाइड के सामने नीचे न भागें। ढलान और चट्टान के किनारों से दूर रहें।"),
    ("landslide_slope", "Is it safe after a landslide stops?", "भूस्खलन रुकने के बाद सुरक्षित है?",
     "No, stay away because landslides come in clusters. Rain after the first slide keeps the ground unstable. Do not sleep below a slope or in a ravine.",
     "नहीं, दूर रहें क्योंकि भूस्खलन एक साथ कई बार आते हैं। पहली स्लाइड के बाद बारिश ज़मीन को अस्थिर रखती है। ढलान के नीचे या नाले में न सोएं।"),
    ("landslide_slope", "Where is it unsafe to sleep during heavy rain?", "भारी बारिश में कहाँ नहीं सोना चाहिए?",
     "Do not sleep below a slope, in a ravine, or near a cliff during heavy rain. Move to stable higher ground. Watch for rumbling and ground vibration.",
     "भारी बारिश में ढलान के नीचे, नाले में या चट्टान के पास न सोएं। स्थिर ऊँची जगह पर जाएं। गुरुज और ज़मीन के कंपन पर ध्यान दें।"),
    ("earthquake_drop_cover", "What do I do during an earthquake?", "भूकंप के झटकों में क्या करें?",
     "Drop to hands and knees, take cover under a sturdy table, and hold on. If there is no table, cover your head and neck against an interior wall. Stay away from windows and heavy objects.",
     "घुटनों पर आएं, मज़बूत मेज़ के नीचे शरण लें, और पकड़े रहें। मेज़ न हो तो भीतरी दीवार के पास सिर और गर्दन ढकें। खिड़कियों और भारी सामान से दूर रहें।"),
    ("earthquake_drop_cover", "Should I run outside during shaking?", "क्या झटकों में बाहर भागें?",
     "No. Do not run outside while the ground is shaking, because falling debris kills. Wait for the shaking to stop. If outdoors, move to an open area away from buildings and power lines.",
     "नहीं। ज़मीन हिलते समय बाहर न भागें, क्योंकि गिरा मलबा जान लेता है। झटके रुकने का इंतज़ार करें। बाहर हों तो इमारत और बिजली के तारों से दूर खुले मैदान में जाएं।"),
    ("earthquake_drop_cover", "Can I use the lift after an earthquake?", "भूकंप के बाद लिफ्ट इस्तेमाल कर सकते हैं?",
     "No, do not use lifts. Use the stairs only after the shaking stops. Check for injuries and gas leaks before moving.",
     "नहीं, लिफ्ट न लें। झटके रुकने के बाद ही सीढ़ियां इस्तेमाल करें। निकलने से पहले चोट और गैस लीक जांचें।"),
]

QA_ROWS += [
    ("trapped_debris", "I am trapped under debris, what should I do?", "मैं मलबे में फंसा हूँ, क्या करूँ?",
     "Cover your mouth and nose with cloth to keep dust out. Do not shout continuously; it wastes breath and energy. Tap on a pipe or wall in threes, pause, and repeat.",
     "धूल से बचने के लिए कपड़े से मुँह-नाक ढकें। लगातार चिल्लाएं न; साँस और ऊर्जा बचाएं। पाइप या दीवार पर तीन थप्पी मारें, रुकें, और दोहराएं।"),
    ("trapped_debris", "How do I signal rescuers if trapped?", "फंसे होने पर बचाव दल को कैसे संकेत दें?",
     "Tap on a pipe or wall in a rhythm rescuers recognise: three taps, pause, repeat. Keep your phone in your hand for beacons. Do not move heavy debris above you.",
     "पाइप या दीवार पर लय में थप्पी मारें: तीन थप्पी, रुकें, दोहराएं। बीकन के लिए फोन हाथ में रखें। ऊपर का भारी मलबा न हिलाएं।"),
    ("trapped_debris", "Should I use my phone torch while trapped?", "फंसे होने पर फोन की टॉर्च इस्तेमाल करें?",
     "No, keep the phone in your hand and use it only for beacons. The torch drains the battery you need for rescue. Save your breath and signal with taps.",
     "नहीं, फोन हाथ में रखें और सिर्फ बीकन के लिए इस्तेमाल करें। टॉर्च बैटरी खत्म करती है जो बचाव के लिए चाहिए। साँस बचाएं और थप्पी से संकेत दें।"),
    ("bleeding_control", "How do I stop severe bleeding?", "तेज़ खून बह रहा है, कैसे रोकें?",
     "Press hard directly on the wound with cloth. Do not remove a soaked cloth; add more layers on top. Raise the limb above heart level if possible and call 108.",
     "घाव पर कपड़े से सीधे ज़ोर से दबाएं। भीगा कपड़ा न हटाएं; ऊपर और परतें चढ़ाएं। संभव हो तो अंग को हृदय से ऊपर उठाएं और 108 पर कॉल करें।"),
    ("bleeding_control", "Can I remove a soaked cloth from a wound?", "घाव से भीगा कपड़ा हटा सकते हैं?",
     "No, do not remove a soaked cloth because it pulls the clot. Add more layers on top and keep pressing. Keep the person warm and watch for shock.",
     "नहीं, भीगा कपड़ा न हटाएं क्योंकि थक्का निकल जाता है। ऊपर और परतें चढ़ाएं और दबाते रहें। व्यक्ति को गर्म रखें और शॉक पर नज़र रखें।"),
    ("bleeding_control", "What are the signs of shock?", "शॉक के संकेत क्या हैं?",
     "Watch for pale skin, cold sweat, and fast breathing. Keep the person warm and still. Call 108 and do not give food or water if surgery may be needed.",
     "पीली त्वचा, ठंडा पसीना और तेज़ साँस देखें। व्यक्ति को गर्म और स्थिर रखें। 108 पर कॉल करें और ऑपरेशन हो सकता है तो पानी-भोजन न दें।"),
    ("bleeding_control", "What if an object is stuck in the wound?", "घाव में कोई वस्तु फंसी है तो क्या करें?",
     "Do not pull it out. Pad around the object and press beside it to control bleeding. Keep the person still and call 108.",
     "उसे न निकालें। वस्तु के चारों ओर भरें और उसके बगल में दबाकर खून रोकें। व्यक्ति को स्थिर रखें और 108 पर कॉल करें।"),
    ("cpr", "How do I do CPR?", "सीपीआर कैसे करें?",
     "Place the heel of your hand on the centre of the chest. Press hard and fast at about 100 to 120 per minute and let the chest rise fully. Continue until help arrives and call 108 on speaker.",
     "हथेली की जड़ छाती के बीच रखें। लगभग 100 से 120 बार प्रति मिनट तेज़ और गहरा दबाएं और बीच में छाती पूरी उठने दें। मदद आने तक जारी रखें और 108 स्पीकर पर चलाएं।"),
    ("cpr", "What if the person is not breathing?", "व्यक्ति साँस नहीं ले रहा तो क्या करें?",
     "If they are unresponsive and not breathing normally, start chest compressions. Press hard and fast at 100 to 120 per minute. Call 108 on speaker while you do this.",
     "अगर व्यक्ति बेहोश है और सामान्य साँस नहीं ले रहा, तो छाती दबाना शुरू करें। 100 से 120 बार प्रति मिनट तेज़ और गहरा दबाएं। ऐसा करते समय 108 स्पीकर पर चलाएं।"),
    ("cpr", "How fast should chest compressions be?", "छाती कितनी तेज़ी से दबाएं?",
     "Press at about 100 to 120 compressions per minute. Let the chest rise fully between presses. Continue until help arrives.",
     "लगभग 100 से 120 दबाव प्रति मिनट करें। हर दबाव के बीच छाती पूरी उठने दें। मदद आने तक जारी रखें।"),
    ("heat_stroke", "What should I do for heat stroke?", "हीट स्ट्रोक में क्या करें?",
     "Move the person to shade and remove extra clothing. Pour water on the skin and fan vigorously. If they are confused, hot and not sweating, call 108 immediately.",
     "व्यक्ति को छाया में ले जाएं और अतिरिक्त कपड़े उतारें। त्वचा पर पानी डालें और ज़ोर से हवा करें। भ्रम, गर्मी और पसीना न आना हीट स्ट्रोक है — तुरंत 108 पर कॉल करें।"),
    ("heat_stroke", "Can I give ice-cold water in heat stroke?", "हीट स्ट्रोक में बर्फ़ जैसा पानी दे सकते हैं?",
     "No, do not give ice-cold water because it can cause shock. Give small sips of water or ORS only if the person is conscious. Cool the skin with water and fanning.",
     "नहीं, बर्फ़ जैसा ठंडा पानी न दें क्योंकि झटका लग सकता है। होश में हों तो थोड़ा पानी या ORS पिलाएं। त्वचा को पानी और हवा से ठंडा करें।"),
    ("heat_stroke", "Is heat stroke an emergency?", "क्या हीट स्ट्रोक आपातकाल है?",
     "Yes, heat stroke kills within hours and is a medical emergency. Call 108 immediately. Cool the person while you wait.",
     "हाँ, हीट स्ट्रोक घंटों में जान लेता है और चिकित्सकीय आपातकाल है। तुरंत 108 पर कॉल करें। इंतज़ार करते समय व्यक्ति को ठंडा करें।"),
    ("lightning", "How do I stay safe in lightning?", "बिजली से कैसे बचें?",
     "Move inside a building or a vehicle. Stay away from open fields, isolated trees, and tall metal objects. Wait 30 minutes after the last thunder.",
     "इमारत या गाड़ी के अंदर जाएं। खुले मैदान, अकेले पेड़ और ऊँची धातु की चीज़ों से दूर रहें। आखिरी गड़गड़ाहट के 30 मिनट बाद तक सावधान रहें।"),
    ("lightning", "Is it safe under a lone tree during lightning?", "बिजली के समय अकेले पेड़ के नीचे सुरक्षित हैं?",
     "No, never shelter under a lone tree. Move to a building or a vehicle. If caught in the open, crouch low on the balls of your feet.",
     "नहीं, अकेले पेड़ के नीचे कभी शरण न लें। इमारत या गाड़ी में जाएं। खुले में फंसे हों तो पंजों पर नीचे झुकें।"),
    ("lightning", "Can I use my phone during a thunderstorm?", "तूफान में फोन इस्तेमाल कर सकते हैं?",
     "Stay off the phone unless it is an emergency. Keep away from water and metal objects. Wait 30 minutes after the last thunder before going outside.",
     "आपातकाल के अलावा फोन न करें। पानी और धातु की चीज़ों से दूर रहें। बाहर जाने से पहले आखिरी गड़गड़ाहट के 30 मिनट इंतज़ार करें।"),
    ("cyclone", "What should I do in a cyclone?", "चक्रवात में क्या करें?",
     "Shelter in a small interior room near a thick wall, ideally on the lowest floor of a strong building. Stay away from windows and the coast. Store drinking water and charge your phone.",
     "मज़बूत इमारत के निचले हिस्से के छोटे भीतरी कमरे में, मोटी दीवार के पास शरण लें। खिड़कियों और तट से दूर रहें। पीने का पानी रखें और फोन चार्ज करें।"),
    ("cyclone", "Can I go outside during the cyclone eye?", "चक्रवात की शांत आँख में बाहर जा सकते हैं?",
     "No, do not go outside during the calm eye of the storm. The winds will return from the other side. Stay in your shelter until officials say it is safe.",
     "नहीं, तूफान की शांत आँख के दौरान बाहर न जाएं। हवाएं दूसरी तरफ से लौटेंगी। अधिकारी सुरक्षित कहें तब तक शरण में रहें।"),
    ("cyclone", "What should I prepare before a cyclone?", "चक्रवात से पहले क्या तैयारी करें?",
     "Store drinking water and charge your phone. Expect power and water outages for days. Move to an official cyclone shelter if your home is weak.",
     "पीने का पानी रखें और फोन चार्ज करें। कई दिन बिजली-पानी बंद रह सकता है। घर कमज़ोर हो तो सरकारी चक्रवात आश्रय में जाएं।"),
    ("sign_reading", "How do I read an official warning board?", "आधिकारिक चेतावनी बोर्ड कैसे पढ़ें?",
     "Use the camera feature to translate and simplify it if you cannot read the local script. A red or orange board means act or prepare now. Never assume a quiet board means no danger.",
     "स्थानीय लिपि न पढ़ पाएं तो कैमरा से अनुवाद और सरल करें। लाल या नारंगी बोर्ड का मतलब अभी कार्रवाई या तैयारी। शांत बोर्ड का मतलब खतरा नहीं, यह न मानें।"),
    ("sign_reading", "What does a red warning board mean?", "लाल चेतावनी बोर्ड का क्या मतलब है?",
     "A red board means act now. An orange board means prepare now. A yellow board means watch for updates.",
     "लाल बोर्ड का मतलब अभी कार्रवाई करें। नारंगी बोर्ड का मतलब अभी तैयारी करें। पीला बोर्ड का मतलब अपडेट पर नज़र रखें।"),
    ("sign_reading", "Is a quiet warning board safe?", "क्या शांत चेतावनी बोर्ड सुरक्षित है?",
     "Do not assume a quiet board means no danger. Check official updates and ask local authorities. Use the camera to read boards in another script.",
     "शांत बोर्ड का मतलब खतरा नहीं, यह न मानें। आधिकारिक अपडेट देखें और स्थानीय अधिकारियों से पूछें। दूसरी लिपि के बोर्ड कैमरा से पढ़ें।"),
]

NEGATIVE_ROWS = [
    ("What is the dose of paracetamol for a child?", "बच्चे के लिए पैरासिटामोल की खुराक क्या है?",
     "I am not sure about medicine doses. The notes do not cover children's medicine. Call 108 or ask a doctor.",
     "मुझे दवा की खुराक के बारे में पक्का नहीं पता। नोट्स में बच्चों की दवा नहीं है। 108 पर कॉल करें या डॉक्टर से पूछें।"),
    ("How do I treat a snake bite?", "साँप के काटने का इलाज कैसे करें?",
     "I am not sure about snake bite treatment. The notes do not cover it. Call 108 and keep the person still.",
     "मुझे साँप के काटने के इलाज के बारे में पक्का नहीं पता। नोट्स में यह नहीं है। 108 पर कॉल करें और व्यक्ति को स्थिर रखें।"),
    ("What should I do for a dog bite?", "कुत्ते के काटने पर क्या करें?",
     "I am not sure about dog bite treatment. The notes do not cover it. Call 108 or go to the nearest hospital.",
     "मुझे कुत्ते के काटने के इलाज के बारे में पक्का नहीं पता। नोट्स में यह नहीं है। 108 पर कॉल करें या नज़दीकी अस्पताल जाएं।"),
    ("Can I give medicine to a pregnant woman?", "क्या गर्भवती महिला को दवा दे सकते हैं?",
     "I am not sure about medicine in pregnancy. The notes do not cover it. Call 108 or ask a doctor.",
     "मुझे गर्भावस्था में दवा के बारे में पक्का नहीं पता। नोट्स में यह नहीं है। 108 पर कॉल करें या डॉक्टर से पूछें।"),
    ("What is the first aid for poisoning?", "ज़हर के लिए प्राथमिक उपचार क्या है?",
     "I am not sure about poisoning treatment. The notes do not cover it. Call 108 immediately.",
     "मुझे ज़हर के इलाज के बारे में पक्का नहीं पता। नोट्स में यह नहीं है। तुरंत 108 पर कॉल करें।"),
    ("How do I help someone after an electric shock?", "बिजली के झटके के बाद कैसे मदद करें?",
     "I am not sure about electric shock treatment. The notes do not cover it. Call 108 and do not touch the person until the power is off.",
     "मुझे बिजली के झटके के इलाज के बारे में पक्का नहीं पता। नोट्स में यह नहीं है। 108 पर कॉल करें और बिजली बंद होने तक व्यक्ति को न छुएं।"),
]


def _context(chunks):
    return "\n\n".join(f"{c['title_en']}: {c['text_en']}" for c in chunks)


def _context_hi(chunks):
    return "\n\n".join(f"{c['title_hi']}: {c['text_hi']}" for c in chunks)


def rag_records() -> list:
    by_id = {c["id"]: c for c in KNOWLEDGE}
    records = []
    for n, (cid, q_en, q_hi, a_en, a_hi) in enumerate(QA_ROWS, start=1):
        chunk = by_id[cid]
        for hindi in (False, True):
            ctx = _context_hi([chunk]) if hindi else _context([chunk])
            question = q_hi if hindi else q_en
            answer = a_hi if hindi else a_en
            records.append({
                "id": f"survival_{cid}_{n:04d}_{int(hindi)}",
                "task": "survival",
                "lang": "hi" if hindi else "en",
                "system": FIRST_AID_SYSTEM,
                "user": rag_user(question, ctx, hindi),
                "assistant": answer,
                "meta": {"chunk": cid, "kind": "grounded", "hindi": hindi},
            })
    unrelated = [by_id["flood_moving_water"], by_id["earthquake_drop_cover"], by_id["lightning"]]
    for n, (q_en, q_hi, a_en, a_hi) in enumerate(NEGATIVE_ROWS, start=1):
        chunk = unrelated[(n - 1) % len(unrelated)]
        for hindi in (False, True):
            ctx = _context_hi([chunk]) if hindi else _context([chunk])
            question = q_hi if hindi else q_en
            answer = a_hi if hindi else a_en
            records.append({
                "id": f"survival_negative_{n:04d}_{int(hindi)}",
                "task": "survival",
                "lang": "hi" if hindi else "en",
                "system": FIRST_AID_SYSTEM,
                "user": rag_user(question, ctx, hindi),
                "assistant": answer,
                "meta": {"chunk": chunk["id"], "kind": "not_covered", "hindi": hindi},
            })
    return records


# ---------------------------------------------------------------------------
# Situation brief content
# ---------------------------------------------------------------------------

BRIEF_ROWS = [
    (["flood"], 2, 0, True, "Two family members need help in the flood; send a beacon and share their location now. It is night, so be ready to leave immediately."),
    (["flood"], 2, 0, True, "बाढ़ में दो सदस्यों को मदद चाहिए; अभी बीकन भेजें और उनका स्थान साझा करें। रात है, इसलिए अभी निकलने के लिए तैयार रहें।"),
    (["landslide"], 0, 1, True, "There is an active landslide warning; keep higher ground ready. It is night, so be ready to leave immediately."),
    (["landslide"], 0, 1, True, "भूस्खलन की सक्रिय चेतावनी है; ऊँची जगह तैयार रखें। रात है, इसलिए अभी निकलने के लिए तैयार रहें।"),
    (["cyclone"], 1, 2, False, "One family member needs help during the cyclone; send a beacon now. Stay in a strong interior room away from windows."),
    (["cyclone"], 1, 2, False, "चक्रवात में एक सदस्य को मदद चाहिए; अभी बीकन भेजें। खिड़कियों से दूर मज़बूत भीतरी कमरे में रहें।"),
    (["rain"], 0, 0, False, "There is an active rain warning; follow the first-10-minutes steps. Keep higher ground ready."),
    (["rain"], 0, 0, False, "बारिश की सक्रिय चेतावनी है; पहले दस मिनट के कदम अपनाएं। ऊँची जगह तैयार रखें।"),
    (["earthquake"], 0, 0, False, "There is an active earthquake warning; stay away from windows. Be ready to use open ground if needed."),
    (["earthquake"], 0, 0, False, "भूकंप की सक्रिय चेतावनी है; खिड़कियों से दूर रहें। जरूरत पड़ने पर खुले मैदान के लिए तैयार रहें।"),
    (["heatwave"], 0, 0, True, "Heat wave conditions persist at night; keep water ready. Watch children and elderly people for heat stress."),
    (["heatwave"], 0, 0, True, "रात में भी लू चल रही है; पानी तैयार रखें। बच्चों और बुज़ुर्गों पर नज़र रखें।"),
    ([], 0, 0, False, "No active hazard right now. Add your family board and keep a beacon ready."),
    ([], 0, 0, False, "अभी कोई सक्रिय खतरा नहीं। परिवार बोर्ड जोड़ें और बीकन तैयार रखें।"),
    (["flood", "landslide"], 1, 0, False, "Flood and landslide warnings are active; prioritize higher ground. Send a beacon for the family member who needs help."),
    (["flood", "landslide"], 1, 0, False, "बाढ़ और भूस्खलन दोनों की चेतावनी है; पहले ऊँची जगह जाएं। मदद चाहने वाले सदस्य के लिए बीकन भेजें।"),
]


def brief_records() -> list:
    records = []
    for n, row in enumerate(BRIEF_ROWS, start=1):
        hazards, help_count, unknown, night, text = row
        hindi = any(ord(c) > 127 for c in text)
        records.append({
            "id": f"brief_{n:04d}_{int(hindi)}",
            "task": "brief",
            "lang": "hi" if hindi else "en",
            "system": ALERT_SYSTEM,
            "user": brief_user(hazards, help_count, unknown, night, hindi),
            "assistant": text,
            "meta": {"hazards": hazards, "help": help_count, "unknown": unknown, "night": night, "hindi": hindi},
        })
    return records


# ---------------------------------------------------------------------------
# Dataset assembly
# ---------------------------------------------------------------------------


def main():
    all_records = []
    all_records.extend(alert_records())
    all_records.extend(distress_records())
    all_records.extend(rag_records())
    all_records.extend(brief_records())

    # Stratified split by task
    by_task = defaultdict(list)
    for r in all_records:
        by_task[r["task"]].append(r)

    train, eval_records = [], []
    for task, items in by_task.items():
        random.shuffle(items)
        n_eval = max(1, int(len(items) * 0.1))
        eval_records.extend(items[:n_eval])
        train.extend(items[n_eval:])

    random.shuffle(train)
    random.shuffle(eval_records)

    DATA.mkdir(parents=True, exist_ok=True)

    def write_jsonl(path, items):
        with path.open("w", encoding="utf-8") as f:
            for item in items:
                f.write(json.dumps(item, ensure_ascii=False) + "\n")

    write_jsonl(DATA / "rakshak_train.jsonl", train)
    write_jsonl(DATA / "rakshak_eval.jsonl", eval_records)
    write_jsonl(DATA / "alert_actions.jsonl", [r for r in all_records if r["task"] == "alert"])
    write_jsonl(DATA / "distress.jsonl", [r for r in all_records if r["task"] == "distress"])
    write_jsonl(DATA / "survival_qa.jsonl", [r for r in all_records if r["task"] == "survival"])
    write_jsonl(DATA / "situation_brief.jsonl", [r for r in all_records if r["task"] == "brief"])

    stats = {
        "total": len(all_records),
        "train": len(train),
        "eval": len(eval_records),
        "by_task": dict(Counter(r["task"] for r in all_records)),
        "by_lang": dict(Counter(r["lang"] for r in all_records)),
    }
    (DATA / "stats.json").write_text(json.dumps(stats, ensure_ascii=False, indent=2), encoding="utf-8")

    metadata = {
        "title": "Rakshak AI Disaster Survival Fine-Tune Dataset",
        "id": "abhishekguptaagp/rakshak-ai-disaster-finetune",
        "licenses": [{"name": "CC0-1.0"}],
        "keywords": [
            "disaster",
            "emergency",
            "flood",
            "landslide",
            "earthquake",
            "india",
            "hindi",
            "hinglish",
            "offline",
            "ndma",
            "first-aid",
            "gemma",
            "lora",
            "litertlm",
            "on-device",
        ],
        "description": (
            "Task-aligned supervised data for fine-tuning Gemma 4 E2B on Rakshak AI. "
            "Alert and brief examples are synthetic, written in IMD/CWC/GSI style; "
            "survival answers are grounded in NDMA/WHO/NDRF notes. Covers alert->action JSON, "
            "Hindi/English distress intent parsing, grounded survival RAG, and situation briefs. "
            "Prompts match lib/services/ai_engine.dart exactly."
        ),
        "resources": [
            {"path": "rakshak_train.jsonl", "description": "Mixed-task training split"},
            {"path": "rakshak_eval.jsonl", "description": "Stratified held-out evaluation"},
            {"path": "alert_actions.jsonl", "description": "Alert interpretation examples"},
            {"path": "distress.jsonl", "description": "Voice distress intent examples"},
            {"path": "survival_qa.jsonl", "description": "Grounded RAG examples"},
            {"path": "situation_brief.jsonl", "description": "Situation brief examples"},
            {"path": "stats.json", "description": "Dataset statistics"},
        ],
    }
    (DATA / "dataset-metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps(stats, indent=2))
    print(f"\nWrote to {DATA}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    random.seed(args.seed)
    main()






