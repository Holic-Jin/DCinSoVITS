"""내보내기: GPT-SoVITS에서 바로 쓸 수 있는 가중치 + 참조음성 + 메타데이터 + 고지문."""

import datetime as dt
import json
import re
import shutil
from pathlib import Path

from . import APP_NAME, CREATOR, VERSION, paths
from .samples import SAMPLE_TEXT

DISCLAIMER = f"""[{APP_NAME} 이용 고지 / Disclaimer]

본 데이터는 {APP_NAME}(제작: {CREATOR})로 생성되었습니다.
{APP_NAME} 프로그램에는 어떠한 동영상도 포함되어 있지 않으며,
사용자가 불러온 영상 및 본 프로그램으로 작성된 모든 데이터(음성, 모델 가중치 등)의
수집·이용·배포에 대한 책임은 전적으로 사용자 본인에게 있습니다.
타인의 목소리는 권리자의 동의 없이 사용하지 마십시오.

This data was generated with {APP_NAME} (by {CREATOR}).
The program contains no video. The user is solely responsible for any
video they load and for all data created with this program.
Do not use another person's voice without their consent.

本データは {APP_NAME}（制作: {CREATOR}）で生成されました。
本プログラムには動画は一切含まれていません。読み込んだ動画、および本プログラムで
作成したすべてのデータの利用責任は、すべて利用者ご本人にあります。
他人の声を権利者の同意なく使用しないでください。
"""


def run(job: Path, out: Path, name: str) -> dict:
    model = json.loads((job / "model.json").read_text(encoding="utf8"))
    name = re.sub(r"[^\w\-]+", "_", name).strip("_") or "voice"
    out.mkdir(parents=True, exist_ok=True)
    gpt = out / f"{name}-e{model['gpt_epochs']}.ckpt"
    sovits = out / f"{name}_e{model['sovits_epochs']}.pth"
    shutil.copy(model["gpt"], gpt)
    shutil.copy(model["sovits"], sovits)
    shutil.copy(job / "ref.wav", out / "ref.wav")
    (out / "ref.txt").write_text(model["ref_text"], encoding="utf8")
    samples = sorted(job.glob("sample_*.wav"))  # 재생해 본 UI 언어별 샘플 (sample_ko.wav 등)
    for wav in samples:
        shutil.copy(wav, out / wav.name)
    meta = {
        "tool": APP_NAME,
        "tool_version": VERSION,
        "creator": CREATOR,
        "created_at": dt.datetime.now().isoformat(timespec="seconds"),
        "gpt_sovits_version": paths.GSV_VERSION,
        "gpt_weights": gpt.name,
        "sovits_weights": sovits.name,
        "ref_audio": "ref.wav",
        "ref_text": model["ref_text"],
        "language": model["language"],
        "samples": {w.stem.removeprefix("sample_"): {"file": w.name, "text": SAMPLE_TEXT[w.stem.removeprefix("sample_")]} for w in samples},
        "train": {
            "clips": model["clips"],
            "seconds": model["seconds"],
            "sovits_epochs": model["sovits_epochs"],
            "gpt_epochs": model["gpt_epochs"],
            "batch_size": model["batch"],
        },
        "disclaimer": {
            "ko": "생성된 데이터의 이용 책임은 사용자 본인에게 있습니다.",
            "en": "The user is solely responsible for generated data.",
            "ja": "生成されたデータの利用責任は利用者本人にあります。",
        },
    }
    (out / "dcinsovits.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf8")
    (out / "DISCLAIMER.txt").write_text(DISCLAIMER, encoding="utf8")
    return {"path": str(out), "files": sorted(p.name for p in out.iterdir())}
