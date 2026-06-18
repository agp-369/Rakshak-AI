# Rakshak AI — Complete Project Roadmap for Samsung Solve for Tomorrow 2026

## Status Overview

| Phase | Status | Deadline |
|-------|--------|----------|
| Strategy & Planning | ✅ DONE | Jun 15–18 |
| UI/UX Redesign (India Theme) | ✅ DONE | Jun 18 |
| Story Narrative | ✅ DONE | Jun 18 |
| Fine-Tuning Notebook (v2 synthetic) | ✅ PUSHED | Jun 18 |
| Fine-Tuning Notebook (v3 real datasets) | ✅ PUSHED | Jun 18 |
| Technical Gap Fixes | ✅ DOCUMENTED | Jun 18–22 |
| Kaggle Fine-Tune Run | ⏳ Jun 22–25 | Jun 25 |
| App Build & Test | ⏳ Jun 25–28 | Jun 28 |
| Demo Video | ⏳ Jun 28–30 | Jun 30 |
| Samsung Submission | ⏳ Jun 30–Jul 3 | **Jul 3** |

---

## 1. What's Been Done (18 Jun)

### Strategy
- Created `samsung/` folder with all Samsung deliverables separate from Kaggle codebase
- `samsung/docs/SAMSUNG_BATTLE_PLAN.md` — 5-hat competitive strategy
- `samsung/docs/SAMSUNG_SUBMISSION.md` — ready application writeup
- `samsung/docs/INDIAN_STORY.md` — Priya's emotional arc for judges
- `samsung/fine-tuning/FINE_TUNING_PLAN.md` — India dataset & training plan
- `samsung/demo/DEMO_VIDEO_SCRIPT.md` — 2:30 min video script
- `samsung/redesign/TECHNICAL_GAPS.md` — LoRA, vision, budget phone fixes

### Code (Flutter App — Rakshak AI)
- **Theme**: `lib/theme/app_theme.dart` — India-inspired saffron/teal/navy palette
- **Splash**: `lib/main.dart` — radar animation, gradient text, tricolor bar, GPU status
- **Dashboard**: `lib/ui/triage_dashboard.dart` — glassmorphism cards, animated glow, offline badge
- **Triage**: `lib/ui/medical_triage_screen.dart` — clean medical UI, Hindi chips, patient summary
- **SOS**: `lib/ui/sos_screen.dart` — dramatic pulse, green READY badge
- **Maps**: `lib/ui/offline_maps_screen.dart` — cleaned up India theme
- **Vision**: `lib/ui/widgets/wreckage_analyzer.dart` — STRUCTURE SCAN, GPU notice
- **Service**: `lib/services/gemma_service.dart` — `DeviceCapabilities` class, CPU fallback, low-RAM tuning
- All old Japanese references (Kintsugi, Tengu, Kitsune, Sovereign) removed
- All imports use `package:rakshak_ai/...`

### Kaggle
- **v2 notebook** (`rakshak-ai-india-finetune-v2`, synthetic only):
  - URL: https://www.kaggle.com/code/abhishekguptaagp/rakshak-ai-india-finetune-v2
  - Accelerator: GPU T4 x2 (set manually)
  - Dataset: 2000 synthetic India disaster triage scenarios (natural language)
  - Fixed torch import bug, T4 x2 multi-GPU support, zipfile
  - Old v1 deleted (409 conflict on re-push)

- **v3 notebook** (`rakshak-ai-v3-real-data`, real + synthetic hybrid) — **RECOMMENDED**:
  - URL: https://www.kaggle.com/code/abhishekguptaagp/rakshak-ai-v3-real-data
  - Accelerator: GPU T4 x2 (set manually)
  - **Real datasets used**:
    - **HiMed Hindi Medical Dataset** (Kaggle, 411K entries, 155 MB) — Hindi medical vocabulary
    - **LatentSig Medical Triage** (HuggingFace, 1,000 samples) — Hinglish triage classification
    - **ASHA-Saathi Instructions** (HuggingFace, 4K+ samples) — India ASHA worker protocols
    - **Synthetic India Disaster Triage** (2,000 samples) — floods, cyclones, earthquakes, heatwaves, riots
  - Output: LoRA adapter + merged 16-bit model + GGUF Q4_K_M

---

## 2. Your Action Steps (Next 15 Days)

### Step 1: Run Kaggle Fine-Tuning (Jun 22–25, ~2 hrs)
1. Go to **https://www.kaggle.com/code/abhishekguptaagp/rakshak-ai-v3-real-data** (recommended)
   - Alternative: https://www.kaggle.com/code/abhishekguptaagp/rakshak-ai-india-finetune-v2 (synthetic only, faster)
2. Click **Settings** → **Accelerator** → Select **GPU T4 x2**
3. Click "Run All" (≈35 min training with T4 x2, ~70 min with T4 x1)
4. After completion:
   - Download `rakshak-ai-lora.zip` (LoRA adapter, ~124 MB)
   - Download `rakshak-ai-merged.zip` (merged 16-bit model, ~5 GB)
   - Download `rakshak-ai.gguf` (Q4_K_M quantized, ~1.5 GB)
5. Convert merged model to `.litertlm` format (use conversion script)
6. Push `.litertlm` to phone: `adb push rakshak-ai-it.litertlm /sdcard/Download/`

### Step 2: Test Flutter Build (Jun 25–26, ~30 min)
```bash
# Build APK
flutter build apk --release

# Push model to device
adb push rakshak-ai-it.litertlm /sdcard/Download/

# Install
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Step 3: Verify on Real Device (Jun 26–28)
Test on Samsung Galaxy phone (ideally budget model like M05/A15):
- [ ] Model loads without OOM
- [ ] Hindi triage works correctly
- [ ] English triage works correctly
- [ ] SOS beacon shows GPS coordinates
- [ ] QR mesh sync works
- [ ] App doesn't crash after 10+ triages
- [ ] Battery drain is reasonable (<15% per hour)

### Step 4: Record Demo Video (Jun 28–30, ~3 hrs)
Follow script in `samsung/demo/DEMO_VIDEO_SCRIPT.md`
- Hindi voiceover + English subtitles
- Screen recording of real app use
- Show budget Samsung phone
- Duration: ≤2:30
- Export: MP4, 1920×1080, H.264, <50 MB
- Upload to Google Drive

### Step 5: Submit Application (Jun 30–Jul 3)
**Submission URL**: https://www.samsungindiamarketing.com/SolveForTomorrow/Default.aspx

What you'll need:
- [ ] Personal details (name, age, address, phone, email)
- [ ] Parent/guardian consent (if under 18)
- [ ] Team info (solo — just you)
- [ ] Theme: **AI Living for India**
- [ ] Project name: **Rakshak AI**
- [ ] Problem statement (100 words) → use `samsung/docs/SAMSUNG_SUBMISSION.md`
- [ ] Solution description (200 words) → already written
- [ ] Innovation & Creativity → already written
- [ ] Impact & Feasibility → already written
- [ ] Scalability → already written
- [ ] Technical execution → already written
- [ ] Link to demo video (Google Drive URL)
- [ ] Link to GitHub repo (https://github.com/agp-369/gemma-sos)

---

## 3. Kaggle Results Risk

**The Gemma 4 Good Hackathon closed May 18, 2026. Results expected June–July 2026.**

This conflicts with the Samsung submission (due Jul 3). If you win Kaggle (prize >₹5L/~$6k), the Samsung rules say you cannot use the **identical proposal** that won elsewhere.

### Mitigation
- **The Samsung version is already differentiated**: India theme, Hindi support, Indian story, budget phone focus, different branding ("Rakshak AI" vs "Gemma-SOS")
- Kaggle prize is $50k (top 1%) — odds are low, but possible
- If you win Kaggle, you can:
  1. Still submit to Samsung (they allow it if the proposal is materially different)
  2. Samsung's rule is about the *identical proposal* — Rakshak AI is NOT identical to Gemma-SOS
  3. Worst case: Samsung disqualifies for Kaggle overlap → focus on expanding the app for real deployment

**Verdict**: Low risk. Proceed with Samsung submission.

---

## 4. Key Files Reference

| File | Purpose |
|------|---------|
| `samsung/docs/SAMSUNG_SUBMISSION.md` | Copy-paste for application form |
| `samsung/demo/DEMO_VIDEO_SCRIPT.md` | Script for 2:30 min video |
| `samsung/docs/INDIAN_STORY.md` | Priya's story for judges |
| `samsung/redesign/TECHNICAL_GAPS.md` | LoRA, vision, RAM fixes |
| `samsung/fine-tuning/FINE_TUNING_PLAN.md` | Full training guide |
| `lib/theme/app_theme.dart` | India color system |
| `lib/services/gemma_service.dart` | Device capabilities, fallback |

---

## 5. Submission Portal Details

| Field | Value |
|-------|-------|
| **URL** | https://www.samsungindiamarketing.com/SolveForTomorrow/Default.aspx |
| **Deadline** | July 3, 2026 (11:59 PM IST) |
| **Theme** | AI Living for India |
| **Prize** | Up to ₹2Cr grant + incubation at IIT Delhi |
| **Stages** | Application → Top 100 → Top 40 (Bootcamp at Samsung+IITD) → Top 20 → Grand Finale (Oct 2026) |
| **Judging** | Samsung + FITT IIT Delhi (40% Innovation, 30% Impact, 20% Scalability, 10% Technical) |
| **Contact** | solvefortomorrow@samsung.com |
| **T&C** | https://images.samsung.com/is/content/samsung/assets/in/solvefortomorrow/2026/tnc.pdf |
