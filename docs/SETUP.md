# Setup

## Prerequisites

- Flutter SDK
- Android SDK (API 26+)
- A Gemma 4 E2B model file (`.litertlm` format) pushed to the device

## Building from source

```bash
# Install dependencies
flutter pub get

# Build release APK
flutter build apk --release

# Build app bundle (for Play Store / side-loading)
flutter build appbundle --release
```

The APK is output at `build/app/outputs/flutter-apk/app-release.apk`.

## Deploying the model

The app loads the LLM model from the device at a known path. Push the model file after installing the app:

```bash
# Connect phone via USB with debugging enabled
adb push path/to/rakshak-ai.litertlm /sdcard/Download/
```

On first launch, the app detects the model file and initializes the inference engine. The app remains usable without the model — triage can still be performed manually through the START protocol engine.

## Fine-tuning the model

The fine-tuning pipeline is in `fine-tuning/notebook.ipynb`. It uses LoRA adapters trained on:

- **HiMed Hindi Medical Corpus** (411K entries) — Kaggle
- **LatentSig Medical Triage** (1K Hinglish samples) — HuggingFace
- **ASHA-Saathi Instructions** (4K India protocol samples) — HuggingFace
- **Synthetic India Disaster Scenarios** (2K generated samples)

### Running on Kaggle

1. Open `fine-tuning/notebook.ipynb` on Kaggle
2. Set Accelerator to **GPU T4 x2**
3. Enable Internet in notebook settings
4. Run All cells
5. Download the `rakshak-ai-lora.zip` from the Output tab

### Merging and exporting

The notebook merges the LoRA weights into the base model and exports a `.litertlm` file for device deployment. The merged model is quantized to 4-bit for efficient on-device inference.

## Testing on device

```bash
# Run unit tests
flutter test

# Build and install on connected device
flutter run --release
```

## Building for iOS

```bash
flutter build ios --release --no-codesign
```

Open `ios/Runner.xcworkspace` in Xcode to configure signing and deploy.

## Project structure

```
lib/
├── main.dart                      # App entry point, routing
├── theme/
│   └── app_theme.dart             # India-inspired dark theme
├── services/
│   ├── gemma_service.dart         # LLM inference wrapper
│   ├── gemma_triage_service.dart  # Triage prompt builder & parser
│   ├── triage_engine.dart         # START protocol decision tree
│   ├── gps_service.dart           # Offline location provider
│   ├── mesh_service.dart          # QR-based peer sync
│   └── patient_repository.dart    # SQLite persistence
└── ui/
    ├── triage_dashboard.dart      # Home screen
    ├── medical_triage_screen.dart # Triage form + AI analysis
    ├── sos_screen.dart            # Emergency beacon
    ├── offline_maps_screen.dart   # Cached map viewer
    └── widgets/
        └── wreckage_analyzer.dart # Camera-based damage scan
```
