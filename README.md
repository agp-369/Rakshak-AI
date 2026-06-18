# Rakshak AI

An offline-first AI disaster medical triage app for India. Built with Flutter and Gemma 4.

## Overview

Rakshak AI performs START protocol triage (RED/YELLOW/GREEN/BLACK) on disaster victims using a fine-tuned Gemma 4 2.6B model that runs entirely on-device. No internet required.

The app is designed for budget Android phones commonly used in rural India. It supports both Hindi and English input.

## Features

- **Medical Triage** — Assess victims using START protocol with Hindi or English input
- **Offline AI** — Fine-tuned Gemma 4 model runs locally via flutter_gemma
- **Emergency SOS** — One-tap alert with GPS location
- **Patient Tracking** — QR-based patient data sync between responders
- **Offline Maps** — Cached evacuation routes and relief camp locations

## Model Fine-Tuning

The Gemma 4 model is fine-tuned on a combination of real and synthetic datasets:

- **HiMed Hindi Medical Corpus** (Kaggle) — Hindi medical text for vocabulary
- **LatentSig Medical Triage** (HuggingFace) — Hinglish triage classification samples
- **ASHA-Saathi Instructions** (HuggingFace) — India ASHA worker protocol data
- **Synthetic India Disaster Scenarios** — 2,000 generated flood/cyclone/earthquake triage cases

The fine-tuning notebook is available at `fine-tuning/notebook.ipynb`.

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
│   ├── gemma_service.dart
│   ├── triage_engine.dart
│   ├── gps_service.dart
│   └── mesh_service.dart
├── models/
│   └── triage_result.dart
└── ui/
    ├── triage_dashboard.dart
    ├── medical_triage_screen.dart
    ├── sos_screen.dart
    ├── offline_maps_screen.dart
    └── widgets/
        └── wreckage_analyzer.dart
android/
ios/
test/
assets/
fine-tuning/
docs/
```

## Built For

Samsung Solve for Tomorrow 2026 — Theme: AI Living for India

## License

MIT
