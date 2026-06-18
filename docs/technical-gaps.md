# Technical Gaps & Mitigations — Rakshak AI for Samsung

## 1. LoRA Fine-Tuned Model NOT Loadable in Flutter App

### Problem
The fine-tuned LoRA adapter (124 MB, 0.60% of 5.15B params) is trained on Kaggle but **cannot be loaded through `flutter_gemma` FFI**. The Flutter plugin only loads the full `.litertlm` model file — it has no API for LoRA adapter injection.

This means the app currently uses the **base Gemma 4 E2B model**, not the fine-tuned version.

### Solution A: Merge + Export (Recommended)
The existing notebook already has a merge step. The merged model (LoRA applied, 4-bit quantized, exported to `.litertlm`) **IS** loadable by flutter_gemma.

```python
# Already in notebook pipeline:
merged = PeftModel.from_pretrained(base_model, lora_path)
merged = merged.merge_and_unload()
# → export to gemma-4-E2B-it-merged.litertlm
```

**Action**: Re-run the notebook with India-specific dataset → produce merged `.litertlm` → push to device.

### Solution B: Python Inference via Chaquopy
For real-time LoRA switching, embed a Python interpreter in the APK using Chaquopy.

```python
# python/rakshak_inference.py
from transformers import AutoModelForCausalLM, PeftModel
model = AutoModelForCausalLM.from_pretrained("base_model")
model = PeftModel.from_pretrained(model, "lora_adapter")
response = model.generate(...)
```

**Drawback**: +50 MB APK size, slower cold start, more complex build pipeline.

### Solution C: Prompt Engineering Fallback (Current)
The base Gemma 4 E2B with well-crafted system instructions approximates fine-tuned behavior. The existing `gemma_triage_service.dart` already uses structured prompts.

**Verdict**: Go with **Solution A** for Samsung. Merge India-specific LoRA → export → deploy.

---

## 2. Vision Features Don't Work on CPU-Only Phones

### Problem
Gemma 4 E2B's multimodal (image) inference requires GPU/NPU acceleration. On the CPU backend (`preferredBackend: PreferredBackend.cpu`), `addQueryChunk` with image data throws a runtime error. The current code catches this and returns an error message.

### Current Behavior (gemma_service.dart:226-232)
```dart
return const GemmaResult(
  text: 'Vision analysis unavailable on this device. ...',
  confidence: ConfidenceLevel.insufficient,
  error: 'Image analysis compiled model failed on CPU backend',
);
```

### Budget Phone Reality
Samsung Galaxy M05 / A series (₹8K–₹15K) have:
- MediaTek Helio / Exynos chipsets
- No dedicated NPU, limited GPU
- 4 GB RAM

Vision will NEVER work on these devices.

### Solution: Tiered Feature Availability

| Tier | Devices | Features | RAM Needed |
|------|---------|----------|------------|
| **Full** | Galaxy S24/S25, Tab S9+ | Text + Vision + SOS + Maps | 8 GB+ |
| **Standard** | Galaxy A5x, M5x series | Text + SOS + Maps (no Vision) | 6 GB |
| **Lite** | Galaxy M05, A0x, A1x | Text-only triage + SOS text | 4 GB |

### Implementation: Device Capability Detection
```dart
class DeviceCapabilities {
  static bool get supportsVision {
    // Check for GPU/NPU via Android hardware info
    // Fallback: false for most Indian budget phones
    return false; // Default to safe
  }
  
  static bool get isLowRam {
    // Check ActivityManager.isLowRamDevice()
    return true; // Adjust inference params
  }
}
```

### Changes to Make
1. Add `DeviceCapabilities` utility class
2. Update `gemma_service.dart` to check capabilities before enabling vision
3. Disable camera UI button on low-end devices
4. Add "Lite Mode" toggle in settings
5. Reduce `maxTokens` from 1024 → 512 on low RAM devices
6. Disable `speculativeDecoding` on low RAM (saves ~200 MB)

---

## 3. App Performance on 4 GB RAM Phones

### Baseline
- Gemma 4 E2B model: ~2.59 GB on disk, ~2.0 GB in memory (4-bit quantized)
- Flutter+Android overhead: ~500 MB
- Total: ~2.5 GB out of 4 GB = tight but workable

### Risks
- OS + background services eat remaining RAM → OOM kills
- Model load time on slow eMMC storage: 20–40 seconds
- Inference latency on CPU: 5–15 seconds per query

### Mitigations

1. **Model Loading**:
   - Show splash with progress bar (already done)
   - Pre-warm model on app install via background service
   - Use `mmap` if supported by flutter_gemma

2. **Inference**:
   - Reduce `maxTokens` from 1024 → 512 for text-only
   - Disable `speculativeDecoding` (saves RAM, slightly slower)
   - Single-thread inference to avoid contention

3. **Memory Management**:
   - Unload model when app backgrounds
   - Reload on foreground (with cached warm-start)
   - SQLite patient DB uses negligible RAM

4. **Storage**:
   - Model stored on SD card / external storage
   - App uses ~50 MB internal + DB

---

## 4. Action Items for Samsung Submission

| # | Item | Priority | Owner | Deadline |
|---|------|----------|-------|----------|
| 1 | Create India-specific fine-tuning dataset | High | AGP | Jun 24 |
| 2 | Run Kaggle notebook → merged .litertlm | High | AGP | Jun 25 |
| 3 | Push merged model to phone, test triage | High | AGP | Jun 26 |
| 4 | Add DeviceCapabilities detector | Medium | AGP | Jun 24 |
| 5 | Disable vision on low-end, add Lite Mode | Medium | AGP | Jun 25 |
| 6 | Test on Samsung M05/A15 real device | Critical | AGP | Jun 28 |
| 7 | Record demo video (script ready) | High | AGP | Jun 30 |
| 8 | Submit Samsung application | Critical | AGP | Jul 3 |
