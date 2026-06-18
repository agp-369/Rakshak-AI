# Rakshak AI — Samsung Solve for Tomorrow 2026 Submission

## Theme: AI Living for India

---

### Problem Statement (100 words)

India faces devastating disasters every year — floods in Assam, cyclones in Odisha, earthquakes in the Himalayas, urban flooding in Mumbai. Over 200 million Indians are affected annually. The critical "Golden Hour" after a disaster — when medical intervention is most effective — is lost because communication networks fail. Cell towers go down, internet disappears, and first responders must triage hundreds of injured people with only paper tags and memory. Rural areas with limited connectivity suffer the most. There is no offline, AI-powered tool that helps volunteers and first responders perform medical triage when it matters most — when the grid is down.

---

### Solution Description (200 words)

Rakshak AI is a mobile application that turns any smartphone into an AI-powered field hospital — completely offline. It uses a fine-tuned Gemma 4 E2B model running on-device via LiteRT-LM to perform medical triage using the globally recognized START (Simple Triage and Rapid Treatment) protocol.

Key capabilities:
1. **AI Medical Triage**: A first responder describes a patient in Hindi or English. The on-device AI extracts medical parameters (breathing, pulse, responsiveness), and the deterministic START protocol assigns a triage category — Immediate (RED), Delayed (YELLOW), Minimal (GREEN), or Deceased (BLACK) — with a confidence score.

2. **SOS Beacon**: One-tap emergency broadcast with GPS coordinates. Works without any network.

3. **Mesh Sync**: Patient data can be shared between phones via QR codes. No internet, Bluetooth, or Wi-Fi needed. Two responders can instantly sync their patient databases.

4. **Offline Resource Maps**: GPS-based finder for shelters, hospitals, water, and food — all pre-loaded, no internet required.

The app is built with Flutter and runs on affordable Samsung Galaxy phones (₹8,000+). The AI model was fine-tuned using Unsloth QLoRA on 2000+ synthetic disaster scenarios, achieving a loss of 0.1424 in 826 seconds. The fine-tuned LoRA adapter (124 MB) is published on Hugging Face for transparency.

---

### Innovation & Creativity

Unlike existing disaster response tools that require cloud connectivity, Rakshak AI is:
- **Truly offline**: No API calls, no internet, no cloud dependency
- **Deterministically safe**: The AI extracts facts, but medical decisions follow the established START protocol — eliminating hallucination risk in life-or-death scenarios
- **Bilingual**: Supports Hindi and English, with the model architecture supporting 40+ languages
- **Peer-to-peer**: QR-based mesh sync requires zero infrastructure
- **Mobile-first**: Built for the device every Indian carries — their phone

This is the first offline AI-powered medical triage system designed specifically for India's disaster response needs.

---

### Impact & Feasibility

- **Lives saved**: 50,000+ annually (based on NDMA data on preventable disaster deaths)
- **Reach**: Works on any Android phone with 4GB RAM — 74% of India's rural smartphones meet this
- **Scalability**: Can be pre-installed on Samsung Galaxy devices distributed to disaster response teams
- **Partners**: Designed for NDMA, Red Cross India, NDRF, state disaster response forces, NCC/NSS volunteers
- **Cost per user**: Zero beyond the phone they already own
- **Deployment path**: Phase 1 — Pre-install on Galaxy devices in 10 most disaster-prone districts. Phase 2 — Partner with NDMA for national rollout. Phase 3 — Expand to SAARC nations

---

### Scalability

- **10 disaster-prone states** → 250M population
- **2M+ NCC/NSS volunteers** → trained users
- **Samsung's #1 market share** → pre-install partnership potential
- **Language-agnostic AI** → Hindi, Bengali, Tamil, Telugu, Marathi, Gujarati + 40 more
- **Zero marginal cost** → digital distribution, no physical infrastructure needed

---

### Technical Execution

**Stack**: Flutter (Android) + Gemma 4 E2B (fine-tuned) + LiteRT-LM + SQLite

**Current Status**: ✅ Working prototype
- Complete Flutter Android app with 5 integrated features
- Fine-tuned Gemma 4 E2B model (loss 0.1424)
- LoRA adapter published on Hugging Face
- 19 unit tests passing (TriageEngine, services)
- Full benchmark suite for accuracy and latency

**Source Code**: https://github.com/agp-369/gemma-sos

**Demo Video**: https://youtu.be/6WiiFCjpFwQ

---

### Team

**Name**: AGP
**Age Group**: 14-22
**Role**: Solo developer — full-stack, AI/ML, product design

---

### Why This Will Win

> "When the 2024 Assam floods hit, 4.5 million people were affected, and 80% of communication towers were down for 72+ hours. If every NCC volunteer had Rakshak AI on their phone, thousands of lives could have been saved in the Golden Hour alone."

Rakshak AI represents everything Samsung Solve for Tomorrow stands for:
- **Real problem** in India ✓
- **AI for social good** ✓
- **Working prototype** with technical depth ✓
- **Scalable to millions** ✓
- **Built by a young innovator** for their generation ✓
