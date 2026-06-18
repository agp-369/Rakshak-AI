# Rakshak AI

Offline-first AI-powered disaster medical triage for India.

Built for **Samsung Solve for Tomorrow 2026** (Theme: AI Living for India). Fine-tunes **Gemma 4 2.6B IT** on Indian medical datasets to perform **START protocol triage** in Hindi and English. Runs entirely on-device on budget Samsung phones with no internet.

## Features

- **Medical Triage** — START protocol assessment (RED/YELLOW/GREEN/BLACK) with Hindi + English input
- **Offline AI** — Fine-tuned Gemma 4 model runs on-device via flutter_gemma
- **Emergency SOS** — One-tap alert with GPS location broadcast
- **Offline Maps** — Evacuation routes and relief camp locations
- **QR Mesh** — Patient data sync between devices without internet
- **Wreckage Scanner** — Structure damage assessment (GPU-dependent)

## Quick Start

### 1. Fine-Tune the Model

Run the Kaggle notebook (requires GPU T4 x2):

- **Kaggle**: https://www.kaggle.com/code/abhishekguptaagp/rakshak-ai-indian-medical-triage-fine-tuning
- **Dataset**: HiMed (Hindi Medical), LatentSig Medical Triage, ASHA-Saathi, synthetic disaster scenarios
- **Output**: LoRA adapter → merged 16-bit model → `.litertlm`

### 2. Load Model on Phone

```bash
adb push rakshak-ai-it.litertlm /sdcard/Download/
```

Open Rakshak AI → Settings → Load Model.

### 3. Build APK

```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Project Structure

```
lib/
├── main.dart                     # App entry, radar splash, GPU status
├── theme/app_theme.dart          # India-inspired saffron/teal/navy palette
├── services/
│   ├── gemma_service.dart        # Model loading, inference, DeviceCapabilities
│   ├── triage_engine.dart        # START protocol decision engine
│   ├── gps_service.dart          # Location tracking
│   └── offline_maps_service.dart # Map data caching
├── models/
│   └── triage_result.dart        # Triage data models
├── ui/
│   ├── triage_dashboard.dart     # Main dashboard with glassmorphism cards
│   ├── medical_triage_screen.dart # Triage assessment form
│   ├── sos_screen.dart           # Emergency alert with pulse animation
│   ├── offline_maps_screen.dart  # Offline evacuation maps
│   ├── settings_screen.dart      # Model loading, language, GPU config
│   └── widgets/
│       └── wreckage_analyzer.dart # Structure damage scanner
test/
├── widget_test.dart              # Unit tests for services
android/                          # Android platform
ios/                              # iOS platform
assets/models/                    # Model files (push via ADB)
docs/                             # Samsung competition docs
├── strategy.md                   # Competition strategy
├── submission.md                 # Application writeup
├── story.md                      # User narrative
├── technical-gaps.md             # Known limitations
fine-tuning/                      # Kaggle notebook & plan
demo/                             # Video script
```

## Datasets

| Dataset | Source | Samples | Purpose |
|---------|--------|---------|---------|
| HiMed Hindi Medical | Kaggle | 411K | Hindi medical vocabulary |
| LatentSig Medical Triage | HuggingFace | 1,000 | Hinglish triage classification |
| ASHA-Saathi Instructions | HuggingFace | 4K+ | India ASHA worker protocols |
| Synthetic India Disaster | Generated | 2,000 | Flood/cyclone/earthquake triage |

## Links

- **Submission**: https://www.samsungindiamarketing.com/SolveForTomorrow/Default.aspx
- **Kaggle**: https://www.kaggle.com/code/abhishekguptaagp/rakshak-ai-indian-medical-triage-fine-tuning
- **Deadline**: July 3, 2026

## License

MIT
