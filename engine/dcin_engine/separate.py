"""분리 단계: 보컬 추출(Demucs) → 음성인식(Whisper) → 화자 분리(ECAPA + 군집화)."""

import gc
import json
from pathlib import Path

import numpy as np
import soundfile as sf

from . import paths
from .i18n import t
from .progress import log, progress

STAGE = "separate"
SUPPORTED_LANGS = {"ko", "ja", "zh", "en", "yue"}
CHUNK_SEC = 60  # Demucs를 1분 단위로 돌려 16GB에서도 메모리를 일정하게 유지


def _pick_device():
    import torch

    return "mps" if torch.backends.mps.is_available() else "cpu"


def extract_vocals(src: Path, dst: Path) -> None:
    import torch
    from demucs.apply import apply_model
    from demucs.pretrained import get_model

    model = get_model("htdemucs")
    model.eval()
    sr = model.samplerate
    audio, file_sr = sf.read(str(src), dtype="float32", always_2d=True)
    if file_sr != sr:
        import librosa

        audio = librosa.resample(audio.T, orig_sr=file_sr, target_sr=sr).T
    if audio.shape[1] == 1:
        audio = np.repeat(audio, 2, axis=1)
    audio = audio[:, :2]
    vocal_idx = model.sources.index("vocals")

    device = _pick_device()
    chunk = CHUNK_SEC * sr
    total = audio.shape[0]
    out = np.zeros(total, dtype=np.float32)
    for start in range(0, total, chunk):
        seg = torch.from_numpy(audio[start : start + chunk].T.copy())
        ref = seg.mean(0)
        mean, std = ref.mean(), ref.std() + 1e-8
        x = ((seg - mean) / std)[None]
        with torch.no_grad():
            try:
                y = apply_model(model, x.to(device), device=device, split=True, overlap=0.25, progress=False)
            except Exception as e:  # MPS 미지원 연산이 있으면 CPU로 전환
                if device == "cpu":
                    raise
                log(t("s_mps_fallback", err=e.__class__.__name__))
                device = "cpu"
                model.to("cpu")
                y = apply_model(model, x, device="cpu", split=True, overlap=0.25, progress=False)
        vocals = (y[0, vocal_idx].cpu() * std + mean).mean(0).numpy()
        out[start : start + len(vocals)] = vocals
        progress(STAGE, 5 + 35 * min(1.0, (start + chunk) / total), t("s_vocals"))
    del model
    gc.collect()
    sf.write(str(dst), out, sr, subtype="PCM_16")


def transcribe(vocals: Path) -> dict:
    import mlx_whisper

    progress(STAGE, 42, t("s_asr"))
    result = mlx_whisper.transcribe(
        str(vocals),
        path_or_hf_repo=paths.WHISPER_REPO,
        word_timestamps=True,
        condition_on_previous_text=False,
        verbose=None,
    )
    segs = []
    for s in result["segments"]:
        text = s["text"].strip()
        if not text or s.get("no_speech_prob", 0) > 0.6 or s.get("avg_logprob", 0) < -1.2:
            continue
        words = [
            {"start": float(w["start"]), "end": float(w["end"]), "word": w["word"]} for w in s.get("words", [])
        ]
        segs.append({"start": float(s["start"]), "end": float(s["end"]), "text": text, "words": words})
    return {"language": result.get("language", "en"), "segments": segs}


def _split_long(segments: list, max_len: float = 10.0) -> list:
    """Whisper 세그먼트를 단어 경계에서 잘라 10초 이하로 만든다 (화자 혼합·학습 길이 대비)."""
    out = []
    for s in segments:
        if s["end"] - s["start"] <= max_len or not s["words"]:
            out.append({k: s[k] for k in ("start", "end", "text")})
            continue
        cur, cur_start = [], s["words"][0]["start"]
        for w in s["words"]:
            if cur and w["end"] - cur_start > max_len:
                out.append({"start": cur_start, "end": cur[-1]["end"], "text": "".join(x["word"] for x in cur).strip()})
                cur, cur_start = [], w["start"]
            cur.append(w)
        if cur:
            out.append({"start": cur_start, "end": cur[-1]["end"], "text": "".join(x["word"] for x in cur).strip()})
    return [s for s in out if s["text"] and s["end"] - s["start"] >= 0.5]


def diarize(vocals: Path, segments: list) -> list:
    """세그먼트별 ECAPA 임베딩 → 코사인 거리 기반 군집화. 화자 수는 자동."""
    import torch
    from sklearn.cluster import AgglomerativeClustering
    from speechbrain.inference.speaker import EncoderClassifier

    progress(STAGE, 75, t("s_diarize"))
    enc = EncoderClassifier.from_hparams(
        source=paths.ECAPA_REPO, savedir=str(paths.CACHE / "ecapa"), run_opts={"device": "cpu"}
    )
    audio, sr = sf.read(str(vocals), dtype="float32")
    import librosa

    audio16 = librosa.resample(audio, orig_sr=sr, target_sr=16000)
    embs = []
    for i, s in enumerate(segments):
        clip = audio16[int(s["start"] * 16000) : int(s["end"] * 16000)]
        if len(clip) < 8000:
            clip = np.pad(clip, (0, 8000 - len(clip)))
        with torch.no_grad():
            e = enc.encode_batch(torch.from_numpy(clip)[None]).squeeze().numpy()
        embs.append(e / (np.linalg.norm(e) + 1e-8))
        if i % 10 == 0:
            progress(STAGE, 75 + 20 * i / max(1, len(segments)), t("s_diarize"))
    X = np.stack(embs)
    if len(X) == 1:
        labels = np.zeros(1, dtype=int)
    else:
        labels = AgglomerativeClustering(
            n_clusters=None, metric="cosine", linkage="average", distance_threshold=0.62
        ).fit_predict(X)
    labels = _merge_tiny_clusters(X, labels, segments)
    return labels.tolist()


def _merge_tiny_clusters(X, labels, segments, min_share: float = 0.03):
    dur = {}
    for l, s in zip(labels, segments):
        dur[l] = dur.get(l, 0) + s["end"] - s["start"]
    total = sum(dur.values())
    big = [l for l, d in dur.items() if d >= total * min_share]
    if not big:
        return labels
    cents = {l: X[labels == l].mean(0) for l in big}
    out = labels.copy()
    for i, l in enumerate(labels):
        if l not in big:
            out[i] = max(big, key=lambda b: float(X[i] @ cents[b]))
    return out


def write_previews(vocals: Path, segments: list, labels: list, job: Path) -> list:
    audio, sr = sf.read(str(vocals), dtype="float32")
    groups = {}
    for s, l in zip(segments, labels):
        groups.setdefault(l, []).append(s)
    ordered = sorted(groups.values(), key=lambda g: -sum(s["end"] - s["start"] for s in g))
    (job / "preview").mkdir(exist_ok=True)
    speakers = []
    gap = np.zeros(int(0.3 * sr), dtype=np.float32)
    for n, segs in enumerate(ordered, 1):
        sid = f"SPK{n}"
        parts, length = [], 0.0
        for s in sorted(segs, key=lambda s: -(s["end"] - s["start"])):
            if length >= 15:
                break
            parts += [audio[int(s["start"] * sr) : int(s["end"] * sr)], gap]
            length += s["end"] - s["start"]
        clip = np.concatenate(parts) if parts else np.zeros(sr, dtype=np.float32)
        clip = clip / max(1e-4, np.abs(clip).max()) * 0.9
        sf.write(str(job / "preview" / f"{sid}.wav"), clip, sr, subtype="PCM_16")
        speakers.append(
            {
                "id": sid,
                "duration": round(sum(s["end"] - s["start"] for s in segs), 2),
                "count": len(segs),
                "preview": f"preview/{sid}.wav",
                "segments": sorted(segs, key=lambda s: s["start"]),
            }
        )
    return speakers


def run(job: Path) -> dict:
    src = job / "source.wav"
    if not src.exists():
        raise FileNotFoundError(t("e_no_source"))
    vocals = job / "vocals.wav"
    progress(STAGE, 2, t("s_prepare"))
    extract_vocals(src, vocals)

    asr = transcribe(vocals)
    lang = asr["language"] if asr["language"] in SUPPORTED_LANGS else None
    if lang is None:
        raise RuntimeError(t("e_lang", lang=asr["language"]))
    segments = _split_long(asr["segments"])
    if not segments:
        raise RuntimeError(t("e_no_speech"))
    gc.collect()

    labels = diarize(vocals, segments)
    speakers = write_previews(vocals, segments, labels, job)
    result = {"language": lang, "speakers": speakers}
    (job / "speakers.json").write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf8")
    progress(STAGE, 100, t("s_found", n=len(speakers)))
    return {"language": lang, "speakers": [{k: s[k] for k in ("id", "duration", "count", "preview")} for s in speakers]}
