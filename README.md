# Rakshak (रक्षक)

**AI-first, offline disaster survival companion for India.** Gemma runs on the phone. When the network dies, the intelligence does not.

Built for the **Bharat Digital Fellowship 2026**.

---

## Why

In a disaster, the cloud is the first thing to fail:

- Nepal, August 2026: an avalanche ran ~100 km at ~188 km/h. SMS traffic peaked at 679,295 messages/minute — far too late for the 1,455 people killed.
- Kedarnath, 2013: a 72-hour IMD warning existed. It never reached the pilgrims.
- Wayanad, 2024: a landslide at 2 AM. People needed one clear instruction in the dark.
- ~25,000 villages have no mobile coverage; 204 million Indians still use feature phones.

Cloud AI (ChatGPT, Gemini) is unreachable exactly when people need it. A 2.6 GB open model that runs on a ₹8,000 Android phone is not.

## What it does

| Capability | What the AI adds |
|---|---|
| **Alert → action** | Turns arbitrary IMD/CWC/GSI warning text into `DO NOW` steps, `NEVER DO` warnings and a spoken summary — in Hindi or English. |
| **Ask Rakshak** | Survival Q&A over a bundled, sourced knowledge base (NDMA, WHO, GSI, Wayanad after-action). Answers cite their sources and work with no internet. |
| **Panic voice → SMS** | Understands code-mixed distress ("paani aa raha hai, bacche phanse hain") into intent + injured / trapped / people / landmark, then shows a confirmation sheet. Nothing is sent automatically. |
| **Warning-board reader** | Reads an official warning sign or notice-board photo and explains it in plain Hindi/English. Scoped to signs — not structural inspection or diagnosis. |
| **Situation brief** | Combines active alerts, family status and time of day into one short, spoken brief on the home screen. |

The rest of the app is deliberately boring and works without AI or signal: one-tap SMS beacons (SAFE / NEED HELP / EVACUATE) with GPS, a family status board, first-10-minutes guides, "Where am I?" coordinates, and emergency numbers.

## Trust design

Every answer is labelled:

- `ON-DEVICE AI` — produced by Gemma on the phone.
- `VERIFIED RULE` — produced by the deterministic fallback when the model is absent, loading, or times out.

Other safety rails:

- The model is **never** the only path. Alert interpretation, distress parsing and survival answers all have verified rule fallbacks.
- A beacon is **never** sent from voice recognition alone. The user confirms the parsed intent, injury, trapped state and people count first.
- Vision is limited to reading signs and notices. The app does not claim to assess injuries, structures or trapped people from photos.
- If retrieval finds nothing, the app says so and shows emergency numbers instead of inventing advice.
- No account, no cloud, no analytics, no tracking. The model and all data stay on the device.

## Model

- **Gemma 4 E2B** (multimodal, LiteRT-LM), 4-bit, file name `gemma-4-E2B-it.litertlm`, ~2.6 GB.
- Not committed to this repository and not bundled in the APK.
- Sideload it once:

```bash
adb push gemma-4-E2B-it.litertlm /sdcard/Download/
```

On first launch the app copies it into app storage and installs it with `flutter_gemma`. If the file is missing, the app starts in **rule mode** and stays fully usable.

Planned: a single LoRA adapter for code-mixed intent, alert→action and symptom→protocol tasks; a low-RAM tier (Gemma 3 270M/1B) for entry-level phones.

## Architecture

```
Flutter UI (Hindi / English, TTS)
        │
        ▼
AiEngine (singleton)
  ├── alert interpretation ──► actions / donts / severity
  ├── distress parsing     ──► intent + entities → confirm sheet
  ├── survival RAG         ──► KnowledgeRetriever → cited answer
  ├── sign reading         ──► scoped vision prompt
  └── situation brief      ──► alerts + family + time
        │
        ├── flutter_gemma ──► Gemma 4 E2B (.litertlm, on-device)
        └── verified rule fallbacks (always available)
```

| Layer | Files |
|---|---|
| AI engine | `lib/services/ai_engine.dart` |
| Knowledge base + retrieval | `lib/data/disaster_knowledge.dart` |
| Alert parsing / IMD fetch | `lib/services/alert_service.dart` |
| Voice intent fallback | `lib/services/voice_intent.dart` |
| Beacons / family board | `lib/services/beacon_service.dart`, `lib/services/family_board_service.dart` |
| SMS + device capabilities | `android/app/src/main/kotlin/com/example/rakshak_ai/MainActivity.kt` |
| UI | `lib/ui/` |

## Build

Requirements: Flutter 3.50+ / Dart 3.12+, Android SDK 36, JDK 21.

```bash
flutter pub get
flutter analyze          # 0 issues
flutter test             # 30 tests

# Universal release APK (~215 MB with the Gemma native libraries)
flutter build apk --release --no-tree-shake-icons

# Smaller per-ABI APKs — use arm64 for almost all current phones
flutter build apk --release --no-tree-shake-icons --split-per-abi
```

`--no-tree-shake-icons` is required because emergency contacts build `IconData` dynamically.

Reproducibility notes:

- `background_downloader` is pinned to `9.5.8`. `9.5.9` fails Kotlin compilation; `9.6.x` requires Dart ≥3.13.
- `android/gradle.properties` sets `kotlin.incremental=false`. Incremental compilation drops classes from `background_downloader`'s chunked-download sources and produces bogus `Unresolved reference` errors.
- `android/settings.gradle.kts` pins `kotlin.plugin.serialization` to the app's Kotlin version (2.2.20), because the plugin requests an older 2.1.0.

## Repository layout

```
lib/
├── data/       disaster knowledge chunks, survival scenarios
├── services/   AI engine, alerts, beacons, family board, GPS, voice, localization
├── theme/      dark saffron/navy theme
├── ui/         home, beacon, alerts, survival, family, more, settings
└── widgets/    AI badge, voice input
android/        Flutter Android host (SMS, device capability channel)
test/           widget + unit tests (knowledge base, AI fallbacks, UI)
data/manuals/   source manuals used to build the knowledge base
fine-tuning/    LiteRT-LM conversion notebooks and scripts
notebooks/      LoRA fine-tuning experiments
assets/models/  placeholder only — model weights are never committed
```

## Status and limits

- Verified on a release APK: launch, tab navigation, SMS beacon, survival guide, and a cited Hindi `VERIFIED RULE` answer from Ask Rakshak with no model present.
- On-device generation with the model loaded still needs a physical arm64 device (the 2.6 GB model is not in this repo or the build).
- The universal APK is large because it carries Gemma native libraries for three ABIs. Use `--split-per-abi` for distribution.
- 32-bit x86 emulators are not supported by current Flutter release builds; use an arm64 phone or an x86_64/arm64 emulator.
- The visible-injury vision task is defined but intentionally not exposed in the UI.
- This app is decision support. It does not replace official warnings, doctors or emergency responders.

## License

MIT — see `LICENSE`.
