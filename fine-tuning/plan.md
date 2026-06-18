# Rakshak AI – Fine-Tuning Plan (Samsung Solve for Tomorrow 2026)

## Why Fine-Tune for India?

The base Gemma 4 E2B model is a general-purpose LLM. It doesn't intrinsically understand:
- **India-specific disaster patterns** (floods, cyclones, earthquakes, heatwaves, landslides)
- **Indian medical triage protocols** (as practiced by NDRF, civil defence, ASHA workers)
- **Hindi + regional language medical terminology** beyond simple keyword matching
- **Local context** (cholera outbreaks after floods, snakebite in rural areas, building collapse in dense urban slums)

Fine-tuning bridges this gap with <0.6% parameter overhead (LoRA).

---

## Dataset Strategy

### Sources (to create/collect)

| Source | Description | Size Target |
|--------|-------------|-------------|
| **Indian disaster news + NDRF reports** | Real scenarios from NDMA, NDRF, state disaster authorities | 500 scenarios |
| **Hindi medical triage corpus** | START protocol descriptions translated to Hindi + 5 regional languages (Marathi, Bengali, Tamil, Telugu, Gujarati) | 1,000 examples |
| **Synthetic Indian scenarios (Gemma-generated)** | Use Gemma 4 to generate plausible disaster scenarios set in Indian geographies | 2,000 examples |
| **ASHA/ANM protocol docs** | Indian frontline health worker assessment guidelines (public domain) | 300 examples |
| **Kaggle Indian health datasets** | Public health datasets relevant to emergency response | 500 examples |

### Format (JSONL)

```jsonl
{"instruction": "भारत में बाढ़ आपदा के दौरान रोगी का आकलन करें। रोगी पानी में फंसा हुआ है, सांस लेने में तकलीफ है, और निचले अंग में चोट है।", 
 "output": "{\"is_walking\": false, \"is_breathing\": true, \"respiratory_rate\": 32, \"has_radial_pulse\": true, \"capillary_refill_seconds\": 3, \"responds_to_voice\": true, \"responds_to_pain\": true, \"visible_injuries\": \"leg fracture, water inhalation\"}"}
```

---

## Training Setup

### Base
- **Model**: `google/gemma-4-E2B-it` (5.15B params, 4-bit quantized)
- **Method**: QLoRA (quantized LoRA)
- **Adapter rank**: `r=16`, `alpha=32`, `dropout=0.1`

### Hyperparameters
```python
lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    lora_dropout=0.1,
    bias="none",
    task_type="CAUSAL_LM",
)

training_args = TrainingArguments(
    per_device_train_batch_size=1,
    gradient_accumulation_steps=4,
    num_train_epochs=3,
    learning_rate=2e-4,
    fp16=True,
    logging_steps=10,
    save_strategy="epoch",
    output_dir="rakshak-ai-lora",
)
```

### Estimated Cost
- Kaggle GPU T4 x2: 0 credits (free for notebook usage)
- Training time: ~45 minutes (similar to previous run)
- Peak memory: ~12 GB

---

## Merging & Export Pipeline

After fine-tuning on Kaggle:

```python
# 1. Merge LoRA into base
merged = PeftModel.from_pretrained(base_model, lora_path)
merged = merged.merge_and_unload()

# 2. 4-bit quantization for mobile
from optimum.exporters import QuantizationConfig
quant_config = QuantizationConfig(bits=4, group_size=128)

# 3. Export to .litertlm format
# (follow existing notebook pipeline)
```

### Expected Artifacts
- `rakshak-ai-lora/` — LoRA adapter (~124 MB)
- `rakshak-ai-merged-4bit/` — merged 4-bit model (~2.59 GB)
- `rakshak-ai-it.litertlm` — final mobile-optimized model

---

## When to Fine-Tune

**Phase 1 (Now — June 22)**: Complete UI redesign, app stability, story narrative.
**Phase 2 (June 22–25)**: Create Indian dataset, run fine-tune on Kaggle.
**Phase 3 (June 25–28)**: Integrate merged model, test on-device, iterate.
**Phase 4 (June 28–July 3)**: Demo video, final submission polish.

> ⚠️ **Critical**: Kaggle competition results expected June–July 2026. If we win Kaggle (>₹5L prize), the Samsung submission may be invalidated. Fine-tuning on Kaggle GPUs is fine since Kaggle provides free compute for notebooks regardless of competition status.

---

## Related Files

| File | Purpose |
|------|---------|
| `fine-tuning/notebook.ipynb` | Fine-tuning notebook (Kaggle) |
| `fine-tuning/output/lora/` | LoRA adapter output |
| `fine-tuning/output/merged/` | Merged model output |
| `samsung/fine-tuning/india_scenarios.jsonl` | India-specific dataset (to be created) |
