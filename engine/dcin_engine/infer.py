"""재생 단계: 학습된 가중치로 UI 언어의 고정 문장을 합성해 sample_<언어>.wav 생성.

참조음성은 영상 언어(prompt_lang), 합성 문장은 UI 언어(text_lang)인 교차언어 합성이다.
"""

import contextlib
import json
import os
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

from . import paths
from .i18n import LANG, t
from .progress import progress
from .samples import SAMPLE_TEXT

STAGE = "sample"


def run(job: Path) -> dict:
    model = json.loads((job / "model.json").read_text(encoding="utf8"))
    text = SAMPLE_TEXT[LANG]
    out = job / f"sample_{LANG}.wav"

    progress(STAGE, 10, t("t_load"))
    job = job.resolve()
    os.chdir(paths.GSV_DIR)  # 업스트림 코드는 상대경로(GPT_SoVITS/...)를 사용
    for p in (str(paths.GSV_DIR / "GPT_SoVITS"), str(paths.GSV_DIR)):
        if p not in sys.path:
            sys.path.insert(0, p)
    os.environ["version"] = paths.GSV_VERSION
    # 업스트림의 print 출력이 JSON-lines(stdout)에 섞이지 않도록 stderr로 돌린다
    with contextlib.redirect_stdout(sys.stderr):
        sr, wav = _synthesize(model, job, LANG, text)
    sf.write(str(out), wav, sr)
    progress(STAGE, 100, t("t_done"))
    return {"path": str(out), "text": text, "lang": LANG, "seconds": round(len(wav) / sr, 2)}


def _synthesize(model: dict, job: Path, text_lang: str, text: str):
    from TTS_infer_pack.TTS import TTS, TTS_Config

    cfg = TTS_Config(
        {
            "custom": {
                "device": "cpu",
                "is_half": False,
                "version": paths.GSV_VERSION,
                "t2s_weights_path": model["gpt"],
                "vits_weights_path": model["sovits"],
                "bert_base_path": str(paths.BERT_DIR),
                "cnhuhbert_base_path": str(paths.HUBERT_DIR),
            }
        }
    )
    tts = TTS(cfg)
    progress(STAGE, 40, t("t_synth"))
    chunks, sr = [], 32000
    for sr, audio in tts.run(
        {
            "text": text,
            "text_lang": text_lang,
            "ref_audio_path": str(job / "ref.wav"),
            "prompt_text": model["ref_text"],
            "prompt_lang": model["language"],
            "top_k": 15,
            "top_p": 1.0,
            "temperature": 1.0,
            "text_split_method": "cut5",
            "batch_size": 1,
            "speed_factor": 1.0,
            "seed": 1234,
            "parallel_infer": False,
            "repetition_penalty": 1.35,
        }
    ):
        chunks.append(np.asarray(audio))
    return sr, (np.concatenate(chunks) if chunks else np.zeros(sr, dtype=np.int16))
