# Rakshak AI (रक्षक AI)

**Offline-first AI disaster medical triage for India** — powered by Gemma 4 E2B running entirely on-device.

Samsung Solve for Tomorrow 2026 · Theme: AI Living for India

---

## Problem

Every year, **200M+ Indians** are affected by floods, cyclones, and earthquakes. In the critical "Golden Hour" after a disaster:

- Phone networks are down — **no internet, no signal**
- Ambulances and doctors cannot reach affected areas
- First responders must triage victims using paper tags and intuition
- Families get separated with no way to reunite
- **Most disaster deaths occur because help could not be prioritized fast enough**

Existing solutions require internet, expensive hardware, or trained medical professionals — none of which are available when disaster strikes rural India.

## Solution

Rakshak AI turns any **₹8,000 Samsung Galaxy phone** into a fully offline AI-powered disaster response command center. By combining Google's **Gemma 4 E2B** (5.15B params) with medical-grade START protocol triage, the app enables anyone — an NCC volunteer, a panchayat worker, a teacher — to perform professional-level mass casualty triage without any training, internet, or network.

**AI Living for India** — Reusing 650M+ existing Android phones, built for India's disaster-prone regions, running India's most capable open AI model entirely on-device.

## Features

| Feature | Description |
|---------|-------------|
| **Medical Triage** | Describe victim in Hindi/English → AI extracts parameters → START protocol assigns RED/YELLOW/GREEN/BLACK. Deterministic engine fallback ensures 100% medical accuracy. |
| **On-Device AI** | Gemma 4 E2B via flutter_gemma. **Zero data leaves the phone.** All inference local. |
| **17 First Aid Protocols** | Snakebite, burns, heart attack, drowning, earthquake, flood, heatstroke, chemical exposure, drone strike — step-by-step with Hindi support, severity indicators, and read-aloud TTS. |
| **Emergency SOS** | One-tap alert broadcasts GPS location via phone flash + stored coordinates. |
| **QR Mesh Sync** | Multiple responders? Generate a QR code with patient data — second phone scans it. Team coordination without any network. |
| **I'M SAFE** | Family reunification: mark yourself safe with GPS location. Family members search by name to find you. |
| **Incident Reporting** | 9 incident types (fire, flood, collapse, gas leak, etc.) with GPS, photo, resolution tracking. |
| **Voice Input/Output** | Hindi + English speech-to-text for triage. Read-aloud TTS for first aid steps. |
| **Offline Maps** | Bookmark shelters, hospitals, water sources, food distribution points. |
| **Patient Management** | SQLite with JSON export for hospital handoff. |
| **Emergency Contacts** | One-tap dial to 108 (ambulance), 100 (police), 101 (fire), 112 (emergency), and more. |

## Technical Architecture

```
┌──────────────────────────────────────────┐
│              Flutter UI Layer             │
│  TriageDashboard  MedicalTriageScreen    │
│  FirstAidScreen   SosScreen             │
│  ImSafeScreen     IncidentReport        │
│  OfflineMaps      Settings              │
└──────────────────┬───────────────────────┘
                   │
┌──────────────────▼───────────────────────┐
│             Service Layer                │
│  GemmaTriageService  ── Prompt LLM      │
│  TriageEngine        ── START protocol  │
│  PatientRepository   ── SQLite          │
│  MeshService         ── QR code P2P     │
│  GpsService          ── Offline GPS     │
│  VoiceService        ── STT/TTS         │
└──────────────────┬───────────────────────┘
                   │
┌──────────────────▼───────────────────────┐
│          Inference Layer                 │
│  GemmaService  (flutter_gemma)           │
│  └── .litertlm model (4-bit quantized)  │
│  └── DeviceCapability detection         │
│  └── CPU/GPU auto-selection              │
└──────────────────────────────────────────┘
```

## Model Fine-Tuning Pipeline

| Step | Tool | Output |
|------|------|--------|
| 1. Dataset | HiMed (411K), MGH Triage, ASHA-Saathi, Synthetic India scenarios | JSONL |
| 2. Training | Unsloth + LoRA on Kaggle T4 x2 (16GB each) | LoRA adapter |
| 3. Merge | 4-bit → FP16 dequantization + weight merge | SafeTensors (7.7 GB) |
| 4. Export | ai-edge-torch → `.litertlm` | On-device model (~2.6 GB) |

Notebook: `fine-tuning/notebook.ipynb` · Conversion: `fine-tuning/convert_to_litertlm.ipynb`

## Quick Start

```bash
# Build Android APK
flutter build apk --release

# Push model to phone
adb push rakshak-ai.litertlm /sdcard/Download/

# Open app — model auto-detected
```

## Project Structure

```
lib/
├── main.dart
├── theme/
├── services/     # Gemma inference, triage, GPS, mesh, patient, voice
├── models/       # Data models
├── data/         # 17 first aid protocols
└── ui/           # 15+ screens and widgets
fine-tuning/      # Kaggle notebook + .litertlm conversion
notebooks/        # Training notebooks
python/           # Python agent, benchmarks, tools
docs/             # Architecture, API, setup
data/manuals/     # Disaster response protocol markdown
```

## Benchmarks

```bash
cd python
pip install -r requirements.txt
python scripts/benchmark.py
```

## Built For

**Samsung Solve for Tomorrow 2026** — Theme: AI Living for India

Every phone can be a lifeline. When the network fails, AI saves.

## License

MIT
