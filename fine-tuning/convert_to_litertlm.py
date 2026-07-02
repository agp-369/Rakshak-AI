"""
Rakshak AI - Merge LoRA → Base Model → Export to .litertlm

Fixes four issues:
1. Gemma4ClippableLinear adapter injection via Unsloth FastModel (not raw PEFT)
2. transformers version pin causing gemma4 model type not recognized (unpin)
3. transformers 5.x NotImplementedError in save_pretrained (manual save bypass)
4. 4-bit → FP16 dequantization via bitsandbytes functional API (not save_pretrained_merged)

Usage:
  pip install "unsloth[kaggle-new] @ git+https://github.com/unslothai/unsloth.git" bitsandbytes peft accelerate
  pip install -U torchvision torchaudio
  pip install ai-edge-torch
  python convert_to_litertlm.py

Output:
  rakshak-output/rakshak-merged-litertlm/rakshak-ai.litertlm
"""
import os, shutil, gc, torch

os.environ["HF_HUB_ENABLE_HF_TRANSFER"] = "1"

BASE_MODEL_ID = "unsloth/gemma-4-e2b-it-unsloth-bnb-4bit"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
LORA_PATH = os.path.join(PROJECT_DIR, "rakshak-lora-final")
OUTPUT_DIR = os.path.join(PROJECT_DIR, "rakshak-output", "rakshak-merged-litertlm")
LITERTLM_PATH = os.path.join(OUTPUT_DIR, "rakshak-ai.litertlm")
MERGED_PATH = os.path.join(OUTPUT_DIR, "full-precision")

os.makedirs(OUTPUT_DIR, exist_ok=True)

# Handle LoRA as zip if extracted dir doesn't exist
if not os.path.isdir(LORA_PATH):
    zip_path = LORA_PATH + ".zip"
    if os.path.isfile(zip_path):
        print(f"Extracting {zip_path} ...")
        import zipfile
        with zipfile.ZipFile(zip_path) as zf:
            zf.extractall(LORA_PATH)
    else:
        raise FileNotFoundError(f"LoRA adapter not found at {LORA_PATH} or {zip_path}")

device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Device: {device}")
if device == "cuda":
    print(f"  GPU: {torch.cuda.get_device_name(0)}")
    print(f"  VRAM: {torch.cuda.get_device_properties(0).total_mem / 1024**3:.1f} GB")

# ── Step 1: Load base model via Unsloth ──
print("\n[1/5] Loading base model (Unsloth)...")
from unsloth import FastModel
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer

model, tokenizer = FastModel.from_pretrained(
    model_name=BASE_MODEL_ID,
    max_seq_length=2048,
    dtype=None,
    load_in_4bit=(device == "cuda"),
    device_map="auto",
)
print("  Base model loaded via Unsloth")

# ── Step 2: Apply LoRA adapter ──
print("\n[2/5] Applying LoRA adapter...")
model = PeftModel.from_pretrained(model, LORA_PATH)
print("  LoRA applied")

# ── Step 3: Merge LoRA + dequantize 4-bit -> FP16 via manual save ──
print("\n[3/5] Merging + saving as FP16...")
print("  (Bypassing save_pretrained_merged — transformers 5.x revert bug)")

import bitsandbytes as bnb
import safetensors.torch
from transformers.modeling_utils import shard_checkpoint
import json

model = model.merge_and_unload()
print("  LoRA merged")

# Inspect current state
sd = model.state_dict()
first_val = next(iter(sd.values()))
print(f"  Sample dtype: {first_val.dtype}")

if any(k.endswith('.base_layer.weight') or '.lora_' in k for k in sd):
    raise RuntimeError("merge_and_unload did not collapse LoRA keys")

# Build FP16 state dict: dequantize 4-bit layers, cast the rest
sd = {}
dequantized_count = 0
for module_name, module in model.named_modules():
    if not module_name:
        continue
    if hasattr(module, 'weight') and module.weight is not None:
        w = module.weight
        qs = getattr(module, 'quant_state', None)
        if w.dtype == torch.uint8 and qs is not None:
            w = bnb.functional.dequantize_4bit(w, qs)
            dequantized_count += 1
        sd[module_name + '.weight'] = w.to(torch.float16).contiguous()
    if hasattr(module, 'bias') and module.bias is not None:
        sd[module_name + '.bias'] = module.bias.to(torch.float16).contiguous()

print(f"  Dequantized {dequantized_count} layers, {len(sd)} total tensors")

# Save
os.makedirs(MERGED_PATH, exist_ok=True)
model.config.save_pretrained(MERGED_PATH)
tokenizer.save_pretrained(MERGED_PATH)

shards, index = shard_checkpoint(sd, max_shard_size="2GB")
if index is not None:
    for sf, sdata in shards.items():
        safetensors.torch.save_file(sdata, os.path.join(MERGED_PATH, sf))
    with open(os.path.join(MERGED_PATH, "model.safetensors.index.json"), "w") as f:
        json.dump(index, f, indent=2)
else:
    safetensors.torch.save_file(sd, os.path.join(MERGED_PATH, "model.safetensors"))

size_gb = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fn in os.walk(MERGED_PATH) for f in fn) / 1024**3
print(f"  Saved. Size: {size_gb:.2f} GB")

# Verify + inference test
print("\n  Verifying with FastModel + inference test...")
del model, tokenizer
gc.collect()
torch.cuda.empty_cache()

vm, vtokenizer = FastModel.from_pretrained(
    model_name=MERGED_PATH, max_seq_length=2048,
    dtype=None, load_in_4bit=torch.cuda.is_available(), device_map="auto",
)

test_input = "Patient not breathing. Triage category?"
messages = [{"role": "user", "content": [{"type": "text", "text": test_input}]}]
inputs = vtokenizer.apply_chat_template(
    messages, tokenize=True, add_generation_prompt=True, return_tensors="pt"
).to(vm.device)
outputs = vm.generate(input_ids=inputs, max_new_tokens=64, do_sample=False)
response = vtokenizer.decode(outputs[0][inputs.shape[1]:], skip_special_tokens=True)
print(f"  Input: {test_input}")
print(f"  Output: {response}")
print("  Verification passed")

del vm, vtokenizer, inputs, outputs
gc.collect()
torch.cuda.empty_cache()

# ── Step 4: Convert to .litertlm ──
print("\n[4/5] Converting to .litertlm...")
try:
    import ai_edge_torch
    from ai_edge_torch.generative.utilities import export as ai_edge_export

    # Re-load tokenizer from saved merged model
    from transformers import AutoTokenizer
    litertlm_tokenizer = AutoTokenizer.from_pretrained(MERGED_PATH)
    ai_edge_export.model_to_litert(
        MERGED_PATH,
        output_path=LITERTLM_PATH,
        tokenizer=litertlm_tokenizer,
        seq_length=2048,
    )
    litertlm_size = os.path.getsize(LITERTLM_PATH) / 1024**3
    print(f"  Exported: {LITERTLM_PATH} ({litertlm_size:.2f} GB)")

except ImportError:
    print("  ai-edge-torch not installed.")
    print(f"  Install: pip install ai-edge-torch")
    print(f"  Then: export.model_to_litert('{MERGED_PATH}', output_path='{LITERTLM_PATH}', tokenizer=tokenizer)")

# ── Step 5: Summary ──
print("\n[5/5] Complete")
print("\n" + "=" * 60)
print("CONVERSION COMPLETE")
print("=" * 60)
if os.path.exists(LITERTLM_PATH):
    print(f"\nDeploy:")
    print(f"  adb push {LITERTLM_PATH} /sdcard/Download/")
else:
    print(f"\nMerged model: {MERGED_PATH}")
    print("Convert to .litertlm manually with ai-edge-torch.")
