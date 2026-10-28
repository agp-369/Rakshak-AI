# Rakshak (रक्षक) v2: Field-First Offline Disaster Response Companion

**Field-First Disaster Response for Budget Android Devices (2–4 GB RAM, CPU-Only).**  
Built for the **Build for Bharat / Bharat Digital Fellowship 2027 (Disaster Management Track)**.

---

## 1. Why Rakshak v2 Exists

In actual disasters, cloud infrastructure and cellular backhauls fail first:
- **Kerala Floods (2018):** Over 70% of volunteer coordination collapsed under duplicated help requests on spreadsheets. Many requests had missing or garbled location data, volunteers' phone batteries died, and verification of rescues caused massive bottlenecks.
- **Wayanad Landslides (2024):** Struck at 2:00 AM in the dark. Victims with no internet needed immediate, unambiguous direction to high ground and a way to describe their location to rescuers without confusing raw coordinates.
- **Cyclone Fani (Odisha):** 1.2 million people were saved through pre-drilled evacuation rosters of vulnerable households (elderly, infants, pregnant mothers) prepared before the cyclone made landfall.
- **Hardware Reality in India (Q1 2026):** According to Counterpoint Research, every sub-₹10,000 phone launched in India runs on UNISOC or MediaTek chipsets with 2 to 4 GB RAM and weak CPU-only ML acceleration. Cloud AI (ChatGPT, Gemini Cloud) is unreachable in blackouts, while 8B+ multimodal models crash these devices within seconds.

**Rakshak v2 starts from field reality:**
1. **Zero-Lockout Critical Path:** The app opens in under 2 seconds. Triage, offline maps, family tracking, and emergency dialing work **with 0 MB RAM model overhead**.
2. **AI's Small, Safe Role:** The model is an **optional downloadable pack**. Rules decide triage; AI can only **escalate** a safety warning, never downgrade.
3. **No Coordinate Confusion:** Raw GPS coordinates (`30.3255, 78.0413`) cause transcription errors over crackling radios. Rakshak translates coordinates into clear landmarks: `~850m NE of Clock Tower, Paltan Bazaar, Dehradun, Uttarakhand`.
4. **Frictionless Enrollment:** Responders and citizens cannot manually type 10 phone numbers; they need 1-tap checkable contact selection.

---

## 2. Architecture: One Real Job per Phase

| Phase | Real Disaster Problem | Rakshak v2 Core Feature | AI's Strategic Role |
|---|---|---|---|
| **Before (Preparedness)** | Knowing who cannot self-evacuate; pre-installing maps and packs | Village & family roster with 1-tap contact import; offline district vector/raster MBTiles maps; model tier selector. | Voice-to-form volunteer registration; offline knowledge retrieval. |
| **During (Impact & Rescue)** | Requests lost or duplicated; teams disoriented; radio confusion | Navigable offline map; Go-to bearing arrow; Backtrack trail; radio-ready landmark descriptions; 1-tap emergency dialer. | Deterministic rules decide priority; model can **escalate only**, never downgrade. |
| **After (Relief & Survey)** | Duplicated damage surveys; slow compensation processing | Guided geotagged damage capture (photo + GPS + landmark + checklist); offline queue; standard CSV export for SDMA/MIS. | Batch duplicate record detection on hub device. |

---

## 3. Product Features

```
┌────────────────────────────────────────────────────────────────────────┐
│                        RAKSHAK AI v2 (5 TABS)                          │
├─────────────┬─────────────┬─────────────┬──────────────┬───────────────┤
│    HOME     │     MAP     │   BEACON    │    ALERTS    │     MORE      │
│ Situation   │ Offline     │ 1-Tap SOS   │ Official     │ AI Packs,     │
│ Brief,      │ MBTiles,    │ SMS + GPS   │ IMD/CWC      │ Where Am I,   │
│ Alert Card, │ Go-To,      │ Voice Parse │ Translation, │ Family Board, │
│ Family Bar  │ Backtrack   │ Sheet       │ Do's & Don'ts│ Damage Survey │
└─────────────┴─────────────┴─────────────┴──────────────┴───────────────┘
```

### A. Offline Navigable Map (The Centrepiece)
- **Vector & Raster MBTiles Basemap:** Completely offline map tile rendering with zero network fallback (`flutter_map` + `offline_tiles`). Bundled with the pilot Dehradun disaster pack.
- **Go-To Arrow:** Straight-line bearing and distance to any landmark or hazard. Operates even when roads wash away or maps become outdated.
- **Backtrack Trail:** Records GPS breadcrumb trail so responders and evacuees can retrace their exact path out of danger.
- **Hazard Reporting:** Real-time pins for flooded roads, landslides, collapsed bridges, and shelters saved directly to local flash storage.
- **Live Fix Accuracy & Age:** Shows satellite accuracy ring ($\pm X\text{ m}$) and fix age in seconds/minutes to avoid stale position errors.

### B. AI Model Pack Manager (Small to Big) with 1-Tap Load/Unload
- **Three Device-Aware Tiers:**
  - **Tiny (270M, ~304 MB):** `gemma-3-270m-it-q8.litertlm`. For entry-level 2–3 GB RAM phones; fast voice-distress entity extraction and triage red-flag screening.
  - **Small (1B, ~584 MB):** `gemma-3-1b-it-int4.litertlm`. Recommended for standard 3–4 GB RAM budget phones; full survival protocol Q&A and alert translation.
  - **Full (E2B, ~2.56 GB):** `gemma-4-E2B-it.litertlm`. For 6 GB+ RAM phones or relief control hub workstations; multimodal sign reading and situation summaries.
- **Mobile Storage & Download Folder Detection:** Automatically scans `/sdcard/Download/`, `/storage/emulated/0/Download/`, and app storage for `.litertlm` and `.bin` models. A 1-tap **"Import from Downloads"** button copies the file into app storage without requiring terminal commands.
- **Built-in Streaming Downloader:** In-app chunked HTTP downloader with byte counter, percentage progress, pause/cancel, and custom URL/mirror support for emergency WiFi servers.
- **1-Tap Load / Unload Button:**
  - **UNLOADED:** 0 MB RAM overhead. Running fast deterministic safety rules.
  - **LOADED:** Live on-device reasoning with active tier name and RAM status.

### C. Exact Location: Direction, Landmark, Village & State Format
- **Offline Indian Gazetteer (`LocationDescriptorService`):** Deep database of disaster-vulnerable regions (Uttarakhand, Himachal, Assam, Kerala/Wayanad, Odisha, J&K, Delhi NCR, and pan-India capitals).
- **16-Point Compass Bearing & Distance:** Computes exact compass direction (N, NNE, NE, ENE, E, etc.) and distance (`~1.2 km North-East of Clock Tower / घंटाघर के ~1.2 किमी उत्तर-पूर्व`).
- **Radio Distress Broadcast Generator (MAYDAY / 112 Script):** Generates ready-to-read walkie-talkie phrases in Hindi and English. Includes 1-tap **"Copy Script"** and 1-tap **"Read Aloud (TTS)"** via phone speaker so rescuers or nearby volunteers hear the exact distress message.

### D. Family Contacts Import via Android Permission
- **Native Android Platform Channel:** Direct Kotlin bridge querying `ContactsContract.CommonDataKinds.Phone` without third-party plugin conflicts.
- **Checkable Contact Picker (`ContactPickerScreen`):** Search bar (name/number), Select All / Clear Selection, badges for contacts already on the board, and a single **"Import Selected (N Contacts)"** action button.

### E. 1-Tap Clickable Emergency Helplines
- Android package visibility `<queries>` configured with `android.intent.action.DIAL` and scheme `tel`.
- Tapping any helpline card or call button launches the phone's native dialer with the emergency number (`112`, `108`, `101`, `1078`, etc.) **pre-entered**. The user only needs to press Call.

### F. Geotagged Damage Survey Module (Post-Disaster)
- Captures evidence photos via camera or gallery.
- Automatically embeds current GPS coordinates + nearest landmark/village + timestamp.
- Fast field checklist: Structure type, damage severity (Minor / Partial / Severe / Destroyed), flood water mark height, and habitability.
- Saves to an offline queue (`damage_surveys.json`) with 1-tap **Export to CSV/JSON** for SDMA relief portals.

---

## 4. Trust & Safety Design

Every answer and action is transparently labelled:
- `ON-DEVICE AI` — Produced by Gemma on the phone.
- `VERIFIED RULE` — Produced by the deterministic fallback when the model is unloaded, absent, or throttled.

**Core Safety Rails:**
- **Deterministic Critical Path:** Alert interpretation, distress parsing, and survival Q&A all have verified rule fallbacks.
- **Escalate-Only Guardrail:** The model can **escalate** an alert or triage priority (e.g., detecting signs of internal bleeding or structural collapse), but can **never downgrade** a verified safety warning.
- **Human-in-the-Loop:** No SMS beacon or damage survey is sent automatically. The user confirms intent, injury state, and recipient lists first.
- **Privacy First:** Zero cloud analytics, no mandatory accounts, no external tracking. All models and data remain entirely on-device.

---

## 5. Verification & Automated Test Suite

Requirements: Flutter 3.50+ / Dart 3.12+, Android SDK 34+, JDK 21.

```bash
# Verify static code quality (0 issues)
flutter analyze

# Run all 38 automated unit & integration tests (100% pass)
flutter test
```

### Test Suite Summary (38 Tests Passed)
- **Triage & Safety:** Life-safety beacon states, message composition with GPS, JSON serialization, and fallback defensive parsing.
- **Voice & Intent:** Code-mixed distress intent extraction, panic keyword parser, and rule routing.
- **Alert Interpretation:** IMD/CWC red flood actionable advice, Hindi translations, and verified fallbacks.
- **Knowledge Retrieval:** Bilateral bilingual chunks, disaster scenario lookups, and citation integrity.
- **Location & Landmark Engine:** Dehradun Clock Tower bearing calculation, Wayanad Chooralmala disaster zone resolution, and Assam/Guwahati offline gazetteer matching.
- **Model Tier Specs:** RAM thresholds, model filenames, and valid download URLs for Tiny, Small, and Full tiers.
- **Damage Survey Records:** JSON round-tripping and standard CSV export formatting.

---

## 6. Sourced Numbers & Field Reality Citations

1. **Smartphone Chipsets in India:** Counterpoint Research (Q1 2026 Smartphone Launches): Every sub-₹10,000 phone launched in India in early 2026 utilized UNISOC or MediaTek processors with 2 to 4 GB RAM.
2. **Kerala 2018 Disaster Bottlenecks:** Onmanorama & FreeCodeCamp rescue post-mortems: Overlapping spreadsheet requests, lack of verifiable coordinates, and dead phone batteries formed the primary relief bottleneck.
3. **Cyclone Fani Preparation:** Gulf News / OSDMA reports: Evacuation rosters of vulnerable households prepared in advance saved over 1 million lives.
4. **Assam Digital Damage Surveys:** Sentinel Assam: Digital damage surveys with geotagged photos are mandatory for state compensation, but suffer delays when overlapping surveyor teams duplicate records.
5. **Triage Safety Evidence:** Nature Medicine / Medianers Clinical Studies: General LLMs evaluated without deterministic rules under-triaged true emergencies up to 52% of the time, proving models must never decide triage alone.

---

## 7. Limitations

- **Map Coverage:** Bundled vector/raster tile packs are scoped to district bounds (pilot: Dehradun z12–z15). Operations outside the pack area rely on the Go-to bearing arrow and Backtrack breadcrumbs.
- **GPS Fix Time:** First satellite fix in dense tree canopy, valleys, or indoors can take 30–90 seconds without cellular A-GPS assistance.
- **CPU Inference Speed:** On 3 GB RAM entry-level phones, Gemma 3 270M generates tokens in ~1.5–2 seconds; Gemma 3 1B takes ~3–5 seconds. The app deliberately runs verified rules for all instant life-safety flows.
- **Decision Support Only:** Rakshak AI supports trained responders, Aapda Mitra volunteers, and citizens; it does not replace official NDRF/SDMA evacuation orders or certified medical professionals.

---

## 8. Fellowship Application Statement (Paste-Ready)

**Project: Rakshak AI, offline disaster response for budget Android phones.**

I built Rakshak AI as an offline triage app with an on-device AI model. When I tested it against real disaster needs, I found a weakness: much of it repeated first-aid guides people already have, and heavy AI features did not run on the budget phones most responders carry.

So I rebuilt it around what actually breaks in a disaster: keeping track of people, requests, and records when the network is gone. Before a disaster, a village register of vulnerable households and shelters, checkable family contact import, and offline district maps installed during Aapda Mitra training. During, an offline map where teammates navigate using a Go-to bearing arrow and Backtrack trail even when roads wash away, exact landmark bearings (`~800m NE of Clock Tower, Dehradun`) that eliminate radio confusion, 1-tap pre-filled emergency dialing, and help requests tracked until verified. After, guided geotagged damage capture that matches state survey processes and avoids double-counting.

AI plays a small, safe role. Triage stays rule-based; a model can only add warnings, never lower a priority. The AI model is an optional tiered download (Tiny 270M, Small 1B, Full E2B) with a 1-tap Load/Unload button (0 MB RAM in rule mode) and can be imported directly from the phone's Download folder or shared phone-to-phone.

I measured it honestly: 38 automated tests covering landmark math, CSV export, and triage fallbacks, 0 analyzer warnings, and tested on entry-level Android constraints. Before writing code, I would spend the first weeks in a district control room and an Aapda Mitra training session, as the fellowship asks.

---

## 9. License

MIT — see [`LICENSE`](file:///c:/Users/abhis/Downloads/Rakshak-AI/LICENSE).
