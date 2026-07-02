# Rakshak AI (रक्षक AI)

An offline-first AI disaster medical triage app for India. Built with Flutter and Gemma 4 E2B.

**Theme**: Samsung Solve for Tomorrow 2026 — AI Living for India

## Overview

Rakshak AI performs START protocol triage (RED/YELLOW/GREEN/BLACK) on disaster victims using Google's Gemma 4 E2B (5.15B params) running entirely on-device. No internet required.

The app is designed for budget Android phones (₹8,000-₹12,000) commonly used in rural India. It supports both Hindi and English input with regional language support in development.

## Features

- **Medical Triage** — Assess victims using START protocol with Hindi or English input. Uses structured prompt engineering with Gemma 4 + deterministic START algorithm as fallback.
- **Offline AI** — Gemma 4 E2B runs locally via flutter_gemma. No connectivity needed.
- **Emergency SOS** — One-tap alert with GPS location capture.
- **Patient Tracking** — QR-based mesh sync for patient data sharing between responders.
- **Offline Maps** — Manual bookmark system for marking shelter/hospital/water/food locations.
- **First Aid Protocols** — 17 emergency protocols (snakebite, burns, heart attack, drowning, drone strike, chemical exposure, etc.) with step-by-step guidance, Hindi support, and severity indicators.
- **I'M SAFE** — Family reunification system. Mark yourself safe with GPS location; family members search by name to find you.
- **Settings** — Model status, language toggle, cache management.

## Model Fine-Tuning (Kaggle T4x2)

Fine-tunes Gemma 4 E2B (5.15B) with LoRA on Indian medical datasets:

- **HiMed Hindi Medical Corpus** (Kaggle) — 411K Hindi medical entries
- **LatentSig Medical Triage** (HuggingFace) — 1K Hinglish triage samples
- **ASHA-Saathi Instructions** (HuggingFace) — 4K India ASHA protocol data
- **Synthetic India Disaster Scenarios** — 2K flood/cyclone/earthquake triage cases

Notebook: `fine-tuning/notebook.ipynb` | Kaggle: GPU T4 x2 (Dual T4, 16GB each)

Output: LoRA adapter → merged SafeTensors → `.litertlm` for flutter_gemma.

## Build

```bash
flutter build apk --release
```

Push the trained model to your phone:

```bash
adb push rakshak-ai-it.litertlm /sdcard/Download/
```

Open the app and load the model from Settings.

## Project Structure

```
lib/
├── main.dart
├── theme/
│   └── app_theme.dart
├── services/
│   ├── gemma_service.dart         # Gemma 4 inference + DeviceCapabilities
│   ├── gemma_triage_service.dart   # Prompt-engineered LLM triage
│   ├── triage_engine.dart          # START protocol decision tree
│   ├── gps_service.dart            # Offline-first GPS with caching
│   ├── mesh_service.dart           # QR-based P2P patient sync
│   ├── patient_repository.dart     # SQLite CRUD for patients
│   └── im_safe_service.dart        # Family reunification check-in
├── models/
│   └── triage_result.dart
├── data/
│   └── first_aid_protocols.dart    # 17 emergency protocols + step data
└── ui/
    ├── triage_dashboard.dart
    ├── medical_triage_screen.dart
    ├── first_aid_screen.dart        # Searchable protocol list
    ├── protocol_detail_screen.dart  # Step-by-step guide view
    ├── im_safe_screen.dart          # Family reunification UI
    ├── settings_screen.dart
    ├── sos_screen.dart
    ├── offline_maps_screen.dart
    └── widgets/
        └── wreckage_analyzer.dart
android/
├── app/src/main/kotlin/.../MainActivity.kt  # UPDATED: MethodChannel for GPU/RAM
ios/
test/
assets/
├── models/gemma-4-E2B-it.litertlm    # Base model (push via ADB, not bundled)
fine-tuning/                           # Primary fine-tuning notebook (Kaggle T4x2)
notebooks/                             # Secondary/legacy notebooks
python/                                # Python agent, scripts, benchmarks
├── agent/                            # Disaster response orchestrator (CLI)
├── scripts/benchmark.py              # Triage accuracy benchmark suite
docs/
```

## Build

```bash
# Build Android APK
flutter build apk --release

# Push model to phone (2.59 GB, not bundled in APK)
adb push assets/models/gemma-4-E2B-it.litertlm /sdcard/Download/

# Open app — model auto-detected on first launch
```

## Benchmarks

```bash
cd python
pip install -r requirements.txt
python scripts/benchmark.py
```

## Status

| Feature | Status |
|---------|--------|
| START Protocol Engine | ✅ 10/10 unit tests |
| Dark India-inspired Theme | ✅ Material 3 |
| Gemma 4 Inference | ✅ Base + prompt |
| SOS + GPS | ✅ Working |
| QR Mesh Sync | ✅ GZip compressed |
| Settings Screen | ✅ v1.0 added |
| Offline Maps | ✅ Bookmarks v1.0 |
| Device Capabilities | ✅ Real detection |
| Patient Edit/Delete | ✅ v1.0 added |
| Hindi/English Triage | ✅ Both |
| First Aid Protocols (17) | ✅ Searchable, Hindi, step-by-step, severity |
| I'M SAFE — Family Reunification | ✅ GPS check-in + name search |
| Emergency Contacts | ✅ 10 numbers (108/112/100/101...) with one-tap dial |
| Incident Reporting | ✅ 9 types + GPS + photo + resolve tracking |
| Data Export/Import | ✅ JSON export + import for hospital handoff |
| Voice Input (STT) | ✅ Hindi/English mic button on triage screen |
| Read Aloud (TTS) | ✅ Protocol Detail screen — reads step-by-step aloud |
| Protocol Detail Screen | ✅ Step guide + DO NOT + seek help |
| Fine-Tuning Notebook | ✅ Kaggle T4x2 ready (multi-GPU, val split, eval) |
| .litertlm Export | ✅ ai-edge-torch pipeline (graceful fallback) |
| Real Device Test | ⚠️ Pending (need ADB + model push) |

## Built For

Samsung Solve for Tomorrow 2026 — Theme: AI Living for India

## License

MIT
