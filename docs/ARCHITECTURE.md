# Architecture

## Overview

Rakshak AI is an offline-first Android application for disaster medical triage. It runs the Gemma 4 E2B LLM on-device to analyze patient descriptions in Hindi or English and assign triage categories per the START protocol. The app requires no internet connectivity during use.

## Layers

```
┌─────────────────────────────┐
│         UI Layer            │
│  TriageDashboard            │
│  MedicalTriageScreen        │
│  SosScreen                  │
│  WreckageAnalyzer           │
│  OfflineMapsScreen          │
└──────────────────┬──────────┘
                   │
┌──────────────────▼──────────┐
│       Service Layer         │
│  GemmaInferenceService      │
│  GemmaTriageService         │
│  TriageEngine               │
│  GpsService                 │
│  MeshService                │
│  PatientRepository          │
└──────────────────┬──────────┘
                   │
┌──────────────────▼──────────┐
│      Data / Storage         │
│  SQLite (sqflite)           │
│  Gemma 4 model (.litertlm)  │
│  SharedPreferences          │
└─────────────────────────────┘
```

## UI Layer

All screens are under `lib/ui/`. Navigation is managed via `Navigator 2.0` with named routes defined in `main.dart`.

- **TriageDashboard** — Home screen with hero card, tool grid, system status dialog
- **MedicalTriageScreen** — Triage assessment form with quick-tap buttons, LLM analysis, patient list, QR sync
- **SosScreen** — Emergency beacon with GPS capture and mesh-transmit
- **WreckageAnalyzer** — Camera-based structural damage analysis (GPU only)
- **OfflineMapsScreen** — Cached map viewer

## Service Layer

All services are singletons.

### GemmaInferenceService

Wraps `FlutterGemma` for on-device LLM inference. Handles model loading from device storage, text generation with configurable parameters, and response confidence evaluation. Detects device capabilities (GPU vs CPU, RAM) to adjust token limits and backend selection.

### GemmaTriageService

Builds a structured prompt combining patient description with triage instructions, sends it to the LLM, parses the JSON response, and validates it through the START engine. Falls back to regex-based parsing if the LLM output is malformed.

### TriageEngine

Implements the START (Simple Triage and Rapid Treatment) decision tree:

```
Can walk?                 → GREEN
Not breathing?            → BLACK
Respiratory rate >30/<10? → RED
No radial pulse?          → RED
Capillary refill >2s?     → RED
Unresponsive?             → RED
Otherwise                 → YELLOW
```

### GpsService

Offline-first location provider using `geolocator`. Caches last known coordinates. Provides Haversine distance calculation between two points.

### MeshService

Peer-to-peer data sync over QR codes. Serializes all patient records to JSON, compresses with GZip, encodes as Base64, and renders as QR. Receiving side decodes, decompresses, and merges by patient ID.

### PatientRepository

SQLite CRUD wrapper for patient assessments. Each record stores triage category, vital signs, location, and timestamp.

## ML Pipeline

```
User input (text / camera)
       │
       ▼
GemmaTriageService.buildPrompt()
       │
       ▼
GemmaInferenceService.generate()
  ┌────┴────┐
  │  CPU    │  GPU (if available)
  └────┬────┘
       ▼
GemmaTriageService.parseResponse()
       │
       ▼
TriageEngine.assess()
       │
       ▼
PatientRepository.save()
```

## Data Flow

1. User enters patient vitals or natural language description on MedicalTriageScreen
2. GemmaTriageService sends the description to the LLM
3. LLM returns structured triage data (JSON)
4. TriageEngine validates and assigns START category
5. PatientRepository persists the assessment to SQLite
6. TriageDashboard reflects the updated patient count and category breakdown
7. MeshService can export all records as QR for nearby devices

## Offline Mesh Sync Flow

```
Device A                          Device B
   │                                 │
   ├─ Serialize patients ──► QR ─────┤
   │                                 ├─ Decode & merge
   │                                 └─ Confirm receipt
   │◄──── QR ── Serialize patients ──┤
   │                                    │
```

## Device Capability Detection

On startup, the app probes:
- GPU availability → enables vision features, higher token count
- RAM < 4 GB → reduces max tokens, forces CPU backend
- Model file presence → shows loading state if missing
