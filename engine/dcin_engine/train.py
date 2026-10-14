"""변환 단계: 선택 화자 데이터셋 생성 → GPT-SoVITS v2 전처리 → SoVITS/GPT 파인튜닝.

업스트림 스크립트(prepare_datasets/*, s2_train.py, s1_train.py)를 WebUI와 같은 방식(환경변수 + 설정파일)으로
서브프로세스 실행한다. 단계마다 프로세스가 끝나므로 메모리가 매번 반환된다.
"""

import json
import os
import re
import shutil
import subprocess
import threading
import time
from pathlib import Path

import numpy as np
import soundfile as sf

from . import paths
from .i18n import t
from .progress import log, progress

STAGE = "convert"
TARGET_SR = 32000
EXP = "dcin"

# (시작%, 끝%) — 진행률 표시용 구간
SPAN = {"dataset": (0, 5), "1a": (5, 12), "1b": (12, 20), "1c": (20, 25), "s2": (25, 65), "s1": (65, 99)}


def _band(key: str, frac: float) -> float:
    a, b = SPAN[key]
    return a + (b - a) * max(0.0, min(1.0, frac))


# ---------------------------------------------------------------- dataset
def build_dataset(job: Path, speaker_id: str) -> dict:
    meta = json.loads((job / "speakers.json").read_text(encoding="utf8"))
    lang = meta["language"]
    spk = next((s for s in meta["speakers"] if s["id"] == speaker_id), None)
    if spk is None:
        raise ValueError(t("e_speaker", id=speaker_id))

    import librosa

    audio, sr = sf.read(str(job / "vocals.wav"), dtype="float32")
    audio = librosa.resample(audio, orig_sr=sr, target_sr=TARGET_SR)
    ds = job / "dataset"
    shutil.rmtree(ds, ignore_errors=True)
    (ds / "wavs").mkdir(parents=True)

    lines, clips = [], []
    for i, s in enumerate(spk["segments"]):
        dur = s["end"] - s["start"]
        if dur < 1.0 or dur > 12.0:
            continue
        a = int(max(0, s["start"] - 0.05) * TARGET_SR)
        b = int((s["end"] + 0.15) * TARGET_SR)
        clip = audio[a:b]
        peak = float(np.abs(clip).max())
        if peak < 0.02:
            continue
        clip = clip / peak * 0.9
        name = f"{speaker_id}_{i:04d}.wav"
        sf.write(str(ds / "wavs" / name), clip, TARGET_SR, subtype="PCM_16")
        text = s["text"].replace("|", " ").replace("\n", " ").strip()
        lines.append(f"{name}|{speaker_id}|{lang}|{text}")
        clips.append({"name": name, "dur": dur, "text": text, "rms": float(np.sqrt(np.mean(clip**2)))})
    if len(lines) < 4:
        raise RuntimeError(t("e_too_few"))
    (ds / "train.list").write_text("\n".join(lines) + "\n", encoding="utf8")

    ref = _pick_reference(clips)
    shutil.copy(ds / "wavs" / ref["name"], job / "ref.wav")
    (job / "ref.txt").write_text(ref["text"], encoding="utf8")
    total = sum(c["dur"] for c in clips)
    log(t("c_dataset_info", n=len(lines), sec=total, lang=lang))
    return {"language": lang, "clips": len(lines), "seconds": round(total, 1), "speaker": speaker_id}


def _pick_reference(clips: list) -> dict:
    """GPT-SoVITS 참조음성 조건(3~10초)을 만족하면서 음량이 중간값에 가까운(=잡음·외침이 적은) 클립."""
    ok = [c for c in clips if 3.0 <= c["dur"] <= 10.0] or clips
    med = float(np.median([c["rms"] for c in ok]))
    return min(ok, key=lambda c: abs(c["rms"] - med) + 0.02 * abs(c["dur"] - 6.0))


# ---------------------------------------------------------------- upstream runner
def _env(extra: dict) -> dict:
    env = dict(os.environ)
    env.update({k: str(v) for k, v in extra.items()})
    env["PYTHONPATH"] = os.pathsep.join([str(paths.GSV_DIR), str(paths.GSV_DIR / "GPT_SoVITS")])
    env["version"] = paths.GSV_VERSION
    env["is_half"] = "False"
    env["PYTHONUNBUFFERED"] = "1"
    return env


ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
_LOG = None  # 업스트림 출력 전체를 job/train.log에 남겨 문제 분석에 사용

EPOCH_RE = {
    "s2": re.compile(r"====> Epoch:\s*(\d+)"),  # s2: epoch 종료 시 1부터
    "s1": re.compile(r"DCIN_EPOCH (\d+)"),  # s1: s1_wrapper 콜백이 epoch 종료 시 1부터 출력
}


def _report_epoch(line: str, key: str, total_epochs: int) -> None:
    m = EPOCH_RE[key].search(line)
    if not m:
        return
    ep = min(int(m.group(1)), total_epochs)
    msg = t("c_epoch_done", name="SoVITS" if key == "s2" else "GPT", ep=ep, total=total_epochs)
    frac = ep / total_epochs
    if msg != _last_msg[0]:
        _last_msg[0] = msg
        progress(STAGE, _band(key, frac), msg)


_last_msg = [""]


def _run(script: str, extra_env: dict, key: str, total_epochs: int = 0, args: list = (), watch: Path = None) -> None:
    """업스트림 스크립트 실행. stdout(\r 진행바 포함)과 watch 로그파일에서 epoch 진행률을 읽는다."""
    proc = subprocess.Popen(
        [paths.PYTHON, "-s", script, *args],
        cwd=str(paths.GSV_DIR),
        env=_env(extra_env),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    tail = []

    def pump():
        buf = b""
        while True:
            chunk = proc.stdout.read1(4096)
            if not chunk:
                break
            buf += chunk
            parts = re.split(rb"[\r\n]", buf)
            buf = parts.pop()
            for raw in parts:
                line = ANSI_RE.sub("", raw.decode("utf8", "replace")).strip()
                if not line:
                    continue
                tail.append(line)
                if _LOG:
                    _LOG.write(line + "\n")
                    _LOG.flush()
                del tail[:-30]
                if total_epochs:
                    _report_epoch(line, key, total_epochs)
                if "Error" in line or "Traceback" in line:
                    log(line[:400])

    th = threading.Thread(target=pump, daemon=True)
    th.start()
    pos = 0
    while proc.poll() is None:
        time.sleep(1)
        if watch is not None and watch.exists() and total_epochs:
            with open(watch, "r", encoding="utf8", errors="replace") as f:
                f.seek(pos)
                for line in f.read().splitlines():
                    _report_epoch(line, key, total_epochs)
                pos = f.tell()
    th.join(timeout=5)
    if proc.returncode != 0:
        raise RuntimeError(t("e_script", name=Path(script).name, tail="\n".join(tail[-12:])))


# ---------------------------------------------------------------- stages
def preprocess(job: Path) -> Path:
    ds = job / "dataset"
    opt = job / "gsv" / EXP
    shutil.rmtree(opt, ignore_errors=True)
    opt.mkdir(parents=True)
    base = {
        "inp_text": ds / "train.list",
        "inp_wav_dir": ds / "wavs",
        "exp_name": EXP,
        "opt_dir": opt,
        "i_part": 0,
        "all_parts": 1,
        "_CUDA_VISIBLE_DEVICES": "0",
    }
    progress(STAGE, _band("1a", 0), t("c_text"))
    _run("GPT_SoVITS/prepare_datasets/1-get-text.py", {**base, "bert_pretrained_dir": paths.BERT_DIR}, "1a")
    (opt / "2-name2text-0.txt").rename(opt / "2-name2text.txt")

    progress(STAGE, _band("1b", 0), t("c_hubert"))
    _run("GPT_SoVITS/prepare_datasets/2-get-hubert-wav32k.py", {**base, "cnhubert_base_dir": paths.HUBERT_DIR}, "1b")

    progress(STAGE, _band("1c", 0), t("c_semantic"))
    _run(
        "GPT_SoVITS/prepare_datasets/3-get-semantic.py",
        {**base, "pretrained_s2G": paths.PRETRAINED_S2G, "s2config_path": "GPT_SoVITS/configs/s2.json"},
        "1c",
    )
    part = (opt / "6-name2semantic-0.tsv").read_text(encoding="utf8").strip("\n")
    (opt / "6-name2semantic.tsv").write_text("item_name\tsemantic_audio\n" + part + "\n", encoding="utf8")
    (opt / "6-name2semantic-0.tsv").unlink()
    if len(part.splitlines()) < 2:
        raise RuntimeError(t("e_empty"))
    return opt


def train_sovits(job: Path, opt: Path, epochs: int, batch: int) -> Path:
    cfg = json.loads((paths.GSV_DIR / "GPT_SoVITS/configs/s2.json").read_text())
    wdir = job / "weights"
    wdir.mkdir(exist_ok=True)
    (opt / f"logs_s2_{paths.GSV_VERSION}").mkdir(exist_ok=True)
    tc = cfg["train"]
    tc.update(
        fp16_run=False,
        batch_size=batch,
        epochs=epochs,
        text_low_lr_rate=0.4,
        pretrained_s2G=str(paths.PRETRAINED_S2G),
        pretrained_s2D=str(paths.PRETRAINED_S2D),
        if_save_latest=True,
        if_save_every_weights=True,
        save_every_epoch=epochs,
        gpu_numbers="0",
        grad_ckpt=False,
        lora_rank=32,
    )
    cfg["model"]["version"] = paths.GSV_VERSION
    cfg["data"]["exp_dir"] = cfg["s2_ckpt_dir"] = str(opt)
    cfg["save_weight_dir"] = str(wdir)
    cfg["name"] = EXP
    cfg["version"] = paths.GSV_VERSION
    conf = job / "gsv" / "tmp_s2.json"
    conf.write_text(json.dumps(cfg))
    progress(STAGE, _band("s2", 0), t("c_epoch", name="SoVITS", ep=0, total=epochs))
    _run("GPT_SoVITS/s2_train.py", {"_CUDA_VISIBLE_DEVICES": "0"}, "s2", epochs, ["--config", str(conf)], watch=opt / "train.log")
    found = sorted(wdir.glob(f"{EXP}_e{epochs}_s*.pth"))
    if not found:
        raise RuntimeError(t("e_no_sovits"))
    return found[-1]


def train_gpt(job: Path, opt: Path, epochs: int, batch: int) -> Path:
    import yaml

    cfg = yaml.safe_load((paths.GSV_DIR / "GPT_SoVITS/configs/s1longer-v2.yaml").read_text())
    wdir = job / "weights"
    tc = cfg["train"]
    tc.update(
        precision="32",
        batch_size=batch,
        epochs=epochs,
        save_every_n_epoch=epochs,
        if_save_every_weights=True,
        if_save_latest=True,
        if_dpo=False,
        half_weights_save_dir=str(wdir),
        exp_name=EXP,
    )
    cfg["pretrained_s1"] = str(paths.PRETRAINED_S1)
    cfg["train_semantic_path"] = str(opt / "6-name2semantic.tsv")
    cfg["train_phoneme_path"] = str(opt / "2-name2text.txt")
    cfg["output_dir"] = str(opt / f"logs_s1_{paths.GSV_VERSION}")
    cfg["data"]["num_workers"] = 2  # 업스트림 DataLoader가 prefetch_factor를 쓰므로 0 불가
    conf = job / "gsv" / "tmp_s1.yaml"
    conf.write_text(yaml.dump(cfg, default_flow_style=False))
    progress(STAGE, _band("s1", 0), t("c_epoch", name="GPT", ep=0, total=epochs))
    wrapper = str(Path(__file__).with_name("s1_wrapper.py"))
    _run(wrapper, {"_CUDA_VISIBLE_DEVICES": "0", "hz": "25hz"}, "s1", epochs, ["--config_file", str(conf)])
    out = wdir / f"{EXP}-e{epochs}.ckpt"
    if not out.exists():
        raise RuntimeError(t("e_no_gpt"))
    return out


def run(job: Path, speaker: str, sovits_epochs: int, gpt_epochs: int, batch: int) -> dict:
    global _LOG
    _LOG = open(job / "train.log", "w", encoding="utf8")
    progress(STAGE, 1, t("c_dataset"))
    info = build_dataset(job, speaker)
    shutil.rmtree(job / "weights", ignore_errors=True)
    opt = preprocess(job)
    sovits = train_sovits(job, opt, sovits_epochs, batch)
    gpt = train_gpt(job, opt, gpt_epochs, batch)
    shutil.rmtree(job / "gsv", ignore_errors=True)  # 중간 산출물(수백 MB) 정리
    result = {
        **info,
        "sovits": str(sovits),
        "gpt": str(gpt),
        "ref_text": (job / "ref.txt").read_text(encoding="utf8"),
        "sovits_epochs": sovits_epochs,
        "gpt_epochs": gpt_epochs,
        "batch": batch,
    }
    (job / "model.json").write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf8")
    for old in job.glob("sample_*.wav"):  # 이전 모델로 만든 샘플 삭제
        old.unlink()
    progress(STAGE, 100, t("c_done"))
    return result
