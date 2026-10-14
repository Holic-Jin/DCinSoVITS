"""Runtime locations. Everything heavy lives outside the app bundle."""

import os
import sys
from pathlib import Path

ROOT = Path(os.environ.get("DCIN_ROOT", Path.home() / "Library/Application Support/DCinSoVITS"))
GSV_DIR = ROOT / "GPT-SoVITS"
CACHE = ROOT / "cache"
HF_HOME = CACHE / "hf"
PRETRAINED = GSV_DIR / "GPT_SoVITS" / "pretrained_models"
PYTHON = sys.executable

GSV_VERSION = "v2"
BERT_DIR = PRETRAINED / "chinese-roberta-wwm-ext-large"
HUBERT_DIR = PRETRAINED / "chinese-hubert-base"
PRETRAINED_S2G = PRETRAINED / "gsv-v2final-pretrained" / "s2G2333k.pth"
PRETRAINED_S2D = PRETRAINED / "gsv-v2final-pretrained" / "s2D2333k.pth"
PRETRAINED_S1 = PRETRAINED / "gsv-v2final-pretrained" / "s1bert25hz-5kh-longer-epoch=12-step=369668.ckpt"

WHISPER_REPO = "mlx-community/whisper-large-v3-turbo"
ECAPA_REPO = "speechbrain/spkrec-ecapa-voxceleb"

os.environ.setdefault("HF_HOME", str(HF_HOME))
os.environ.setdefault("TORCH_HOME", str(CACHE / "torch"))
os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
