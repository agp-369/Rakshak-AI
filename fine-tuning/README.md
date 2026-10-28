# Rakshak AI — Kaggle Fine-Tune (Gemma 4 E2B)

This package fine-tunes `unsloth/gemma-4-E2B-it` (4-bit QLoRA) on task data that matches the exact prompts/schemas used by the app (`lib/services/ai_engine.dart`).

## Deliverables
- `rakshak_kaggle_finetune.ipynb` — Kaggle-ready notebook (T4 x2)
- `data/` — JSONL datasets (train/eval + per-task)
- `build_dataset.py` — regenerate datasets from app sources
- `convert_to_litertlm.py` — merge LoRA and export `.litertlm` for `flutter_gemma`
- `kernel-metadata.json` — Kaggle kernel config

## Dataset contents (v1)
- **358 total** examples: 323 train / 35 eval (10% stratified by task, seed 42)
- alert→action: 160 (80 English, 80 Hindi)
- distress→intent: 102 (51 English, 51 Hindi)
- grounded survival Q&A: 80 (40 English, 40 Hindi)
- situation brief: 16 (8 English, 8 Hindi)
- Languages: 179 English / 179 Hindi
- Alert and brief examples are synthetic, written in official-warning style; survival answers are grounded in the supplied NDMA/WHO/NDRF notes.

## 1) Upload dataset to Kaggle
1. Zip `fine-tuning/data/` as `rakshak-ai-disaster-finetune.zip` (or upload the folder).
2. Create a Kaggle dataset (e.g. `abhishekguptaagp/rakshak-ai-disaster-finetune`) using `data/dataset-metadata.json`.
3. In the notebook, add that dataset as input: `/kaggle/input/rakshak-ai-disaster-finetune/`.

## 2) Run the notebook on Kaggle
1. Create a new Kaggle Notebook from `rakshak_kaggle_finetune.ipynb` (or upload it).
2. Enable GPU (T4 x2 recommended).
3. Add secrets: `HF_TOKEN` (Gemma 4 is gated on HuggingFace; Unsloth may also need access).
4. Add the dataset above as input.
5. Run all cells.

The notebook does:
- Installs Unsloth + dependencies compatible with Gemma 4
- Loads base model `unsloth/gemma-4-E2B-it` in 4-bit
- Formats chat samples to match the app's system prompts
- Trains with LoRA (r=16, alpha=32) for alert/distress/survival/brief
- Saves `rakshak-lora-final/` and zips it as output
- Evaluates JSON validity/intent accuracy on held-out set

## 3) Export to .litertlm for the app
After downloading `rakshak-lora-final.zip` from Kaggle:

```bash
# in repo root
unzip rakshak-lora-final.zip -d rakshak-lora-final/
python fine-tuning/convert_to_litertlm.py
```

Push to device:
```bash
adb push rakshak-output/rakshak-merged-litertlm/gemma-4-E2B-it.litertlm /sdcard/Download/
```

The app looks for `gemma-4-E2B-it.litertlm` in app storage or `/sdcard/Download/` (see `AiEngine._installFromDevice`).

## Training config (matches app needs)
- Tasks: alert→action JSON, distress→intent JSON, grounded survival Q&A, situation brief
- Languages: English + Hindi (Devanagari) with code-mixed distress samples
- Grounding: only supplied NDMA/WHO/NDRF chunks for survival (negative examples included)
- Constraints: JSON-only for alert/distress; actions <= 3, donts <= 2; citations come from app
- Size target: small LoRA (r=16) to keep merge/export fast

## Notes
- Gemma 4 E2B needs recent `transformers`/`unsloth`. The notebook uses the Unsloth Kaggle T4 recipe (`transformers==5.5.0`, `unsloth_zoo>=2026.4.6`).
- If imports still resolve to old packages after the install cell, restart the Kaggle session and re-run from the HF login cell.
- If LiteRT export fails, use the merged FP16 in `rakshak-output/rakshak-merged-litertlm/full-precision/` and convert with `litert-torch` as documented.
- Do not commit `.litertlm`, `.safetensors`, or large outputs (already in `.gitignore`).
