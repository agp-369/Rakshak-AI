# Rakshak AI v2 — Field-First Architecture & Implementation

**Project:** Rakshak AI (रक्षक) — Field-First Offline Disaster Response Companion  
**Target:** Budget Android Devices (2–4 GB RAM, CPU-only, MediaTek/UNISOC chips)  
**Track:** Build for Bharat / Bharat Digital Fellowship 2027 (Disaster Management AI Track)  

---

## 1. Executive Summary & Real-World Field Philosophy

In a catastrophic flood, landslide, or cyclone, standard cloud AI (ChatGPT, Gemini Cloud) fails immediately because cell towers lose power, fiber backhauls wash away, and thousands of simultaneous emergency calls overwhelm the remaining spectrum.

Information is not the primary bottleneck in a disaster—first-aid guides and phone numbers exist on paper. The real breakdowns are:
1. **Losing track of people and teams** when towers die.
2. **Panic-induced communication failure**: reading raw GPS numbers (`30.3255, 78.0413`) over static-heavy walkie-talkies or voice calls causes severe confusion, mishearing, and rescue delays. Rescuers need: *"~800m NE of Clock Tower, Paltan Bazaar, Dehradun, Uttarakhand"*.
3. **Hardware mismatch**: Running heavy 8B+ multimodal models crashes entry-level ₹8,000 Android phones (which have 2–4 GB RAM and weak CPU-only UNISOC/MediaTek SoCs).
4. **Manual typing friction**: Stranded citizens in panic cannot manually type 10 phone numbers; they need 1-tap contact selection with standard Android permissions.

Rakshak AI v2 addresses these field realities with an **Offline-First, Tri-Phase Architecture (Before, During, After)**.

---

## 2. Core Implemented Pillars

### Pillar A: Tiered On-Device AI Models (Small to Big) with 1-Tap Load/Unload
- **Tiny Tier (`gemma-3-270m-it-q8.litertlm`, ~304 MB)**:
  - Designed for sub-₹10,000 phones with 2–3 GB RAM.
  - Dedicated to entity extraction from code-mixed panic speech and red-flag escalation screening.
- **Small Tier (`gemma-3-1b-it-int4.litertlm`, ~584 MB)**:
  - Recommended for standard 3–4 GB RAM budget phones.
  - Provides full survival Q&A over NDMA/WHO knowledge base, alert action translations, and voice entity extraction.
- **Full Tier (`gemma-4-E2B-it.litertlm`, ~2.56 GB)**:
  - For high-memory devices (6 GB+ RAM) or disaster relief hub computers/laptops.
  - Supports detailed situational reporting and multimodal vision (sign reading).
- **Storage Scanner & Download Folder Detection**:
  - Automatically scans `/sdcard/Download/`, `/storage/emulated/0/Download/`, and app storage for `.litertlm`, `.bin`, `.task`, and `.tflite` model files.
  - 1-tap **"Import from Downloads"** copies or links the file into app storage with zero terminal or adb commands required.
- **Direct In-App Online Downloader**:
  - Built-in chunked streaming HTTP downloader with real-time byte count, percentage progress, pause/cancel, and custom URL/mirror support for local emergency team servers.
- **1-Tap Load / Unload Button**:
  - Top banner provides instant memory control.
  - When **Unloaded**: 0 MB RAM overhead. The app runs instant deterministic safety rules.
  - When **Loaded**: Shows exact active tier and memory usage.

### Pillar B: Exact Location in Landmark, Direction, Village & State Format
- **The Problem**: Raw GPS numbers (`30.32550, 78.04120`) are slow to communicate, prone to transcription errors, and meaningless to local volunteers navigating flooded roads.
- **The Solution (`LocationDescriptorService`)**:
  - **Offline Gazetteer**: Deep database of disaster-vulnerable regions (Uttarakhand, Himachal, Assam, Kerala/Wayanad, Odisha, J&K, Maharashtra, and pan-India capitals).
  - **16-Point Azimuth Bearing & Distance**: Computes exact compass direction (N, NNE, NE, ENE, E, etc.) and distance (`~1.2 km North-East of Clock Tower / घंटाघर के ~1.2 किमी उत्तर-पूर्व`).
  - **Village / Locality**: Identifies neighborhood/village name (`Paltan Bazaar / Rajpur Road`, `Chooralmala Village`, etc.).
  - **District & State**: Cleanly formatted bilingual district and state names (`Dehradun, Uttarakhand / देहरादून, उत्तराखंड`).
  - **Radio Distress Broadcast Generator (MAYDAY Script)**:
    - Generates ready-to-read walkie-talkie phrases in Hindi and English.
    - 1-tap **"Copy Script"** and 1-tap **"Read Aloud (TTS)"** via phone speaker so rescuers or nearby volunteers hear the exact distress message.

### Pillar C: Family Contacts Import with Checkable Selection
- **The Problem**: Manually entering 10-digit mobile numbers during drills or under stress is slow and error-prone.
- **The Solution (`ContactPickerScreen` & `ContactsService`)**:
  - Native Android platform channel using `ContactsContract` queries without bloated external plugins.
  - Requests standard `android.permission.READ_CONTACTS`.
  - Checkable selection page with:
    - Search bar (by name or phone number).
    - Select All / Clear Selection.
    - Badges for contacts already on the Family Board.
    - Bottom action bar: **"Import Selected (N Contacts)"**.
  - 1-tap import directly integrates into the offline Family Board and persists in local storage.

### Pillar D: 1-Tap Clickable Emergency Numbers with Pre-filled Dialer
- **The Problem**: In emergencies, copying or memorizing numbers like `112`, `108`, `101`, `1078` costs critical seconds.
- **The Solution (`EmergencyContactsScreen`)**:
  - Android package visibility `<queries>` configured with `android.intent.action.DIAL` and scheme `tel`.
  - Every card and call button triggers `launchUrl(Uri(scheme: 'tel', path: phone), mode: LaunchMode.externalApplication)`.
  - Automatically opens the phone's native dialer with the emergency number **pre-entered**. The user only needs to press Call.
  - Fallback to system clipboard with visual alert if telephony is unavailable.

---

## 3. Product Roadmap: Before, During, and After

| Phase | Core Goal | Primary Feature | AI Role (Small & Safe) |
|---|---|---|---|
| **Before (Preparedness)** | Pre-install map packs, vulnerable roster, drills | Offline map packs (MBTiles) installed over training Wi-Fi; checkable family import; model tier sizing. | Voice-to-form extraction during volunteer intake. |
| **During (Impact & Rescue)** | 0ms triage, team navigation, verifiable distress | Navigable offline map, go-to bearing arrow, breadcrumb backtrack; radio-ready landmark descriptions; 1-tap emergency dialer. | Deterministic rules decide priority; model can **escalate only**, never downgrade. |
| **After (Relief & Survey)** | Avoid double-counting, geotagged damage survey | Geotagged damage survey photo queue with offline GPS + landmark; missing person log. | Photo pre-sorting and duplicate record detection on hub device. |

---

## 4. Verification & Testing Evidence

- **Static Analysis**: `dart analyze` passes with **0 errors, 0 warnings, 0 lints**.
- **Test Suite**: Automated test suite passes **36/36 unit and integration tests** (`test/widget_test.dart` and `test/v2_features_test.dart`).
- **Android Compatibility**: Minimum SDK 24+, target SDK 34+, tested with permission handling and intent queries for Android 11 through 15+.
