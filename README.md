# Rakshak AI

Offline-first AI-powered disaster medical triage app for **Samsung Solve for Tomorrow 2026** (Theme: AI Living for India).

Fine-tunes **Gemma 4 2.6B (IT)** on Indian medical datasets to perform **START protocol triage** in Hindi and English. Runs entirely on-device on budget Samsung phones with no internet connectivity.

---

## Project Structure

```
samsung/
├── docs/
│   ├── strategy.md        # Competition strategy & positioning
│   ├── submission.md      # Application writeup (copy-paste ready)
│   ├── story.md           # User narrative (Priya, NCC cadet)
│   └── technical-gaps.md  # Known limitations & mitigations
├── fine-tuning/
│   ├── plan.md            # Dataset composition & training pipeline
│   ├── notebook.ipynb     # Kaggle fine-tuning notebook (real + synthetic data)
│   └── kernel-metadata.json
├── demo/
│   └── script.md          # 2:30 min demo video script
├── ROADMAP.md             # 15-day action plan
├── .gitignore
└── README.md
```

## Datasets Used

| Dataset | Source | Samples | Purpose |
|---------|--------|---------|---------|
| HiMed Hindi Medical | Kaggle | 411K | Hindi medical vocabulary |
| LatentSig Medical Triage | HuggingFace | 1,000 | Hinglish triage classification |
| ASHA-Saathi Instructions | HuggingFace | 4K+ | India ASHA worker protocols |
| Synthetic India Disaster | Generated | 2,000 | Flood/cyclone/earthquake triage |

## Quick Start

1. Run the Kaggle notebook at `/fine-tuning/notebook.ipynb` on GPU T4 x2
2. Download the LoRA adapter (`rakshak-ai-lora.zip`)
3. Load into the Rakshak AI Flutter app on a Samsung phone
4. Use offline for disaster medical triage in Hindi/English

## Links

- **Submission Portal**: https://www.samsungindiamarketing.com/SolveForTomorrow/Default.aspx
- **Kaggle Notebook**: https://www.kaggle.com/code/abhishekguptaagp/rakshak-ai-indian-medical-triage-fine-tuning
- **Deadline**: July 3, 2026
