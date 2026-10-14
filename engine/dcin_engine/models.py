"""Download every model the pipeline needs (called once by setup.sh)."""

import sys

from . import paths
from .i18n import t
from .progress import log, progress

GSV_REPO = "lj1995/GPT-SoVITS"
GSV_PATTERNS = [
    "chinese-hubert-base/*",
    "chinese-roberta-wwm-ext-large/*",
    "gsv-v2final-pretrained/*",
]
LID_URL = "https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.bin"


def fetch_all() -> None:
    from huggingface_hub import snapshot_download

    progress("setup", 62, t("m_gsv"))
    snapshot_download(GSV_REPO, allow_patterns=GSV_PATTERNS, local_dir=str(paths.PRETRAINED))

    # GPT-SoVITS 텍스트 언어 분할기(fast_langdetect)가 쓰는 모델. 폴더가 없으면 일본어 등 합성이 실패한다.
    lid = paths.PRETRAINED / "fast_langdetect" / "lid.176.bin"
    if not lid.exists():
        import urllib.request

        lid.parent.mkdir(parents=True, exist_ok=True)
        tmp = lid.with_suffix(".part")
        urllib.request.urlretrieve(LID_URL, tmp)
        tmp.rename(lid)

    progress("setup", 75, t("m_whisper"))
    snapshot_download(paths.WHISPER_REPO)

    progress("setup", 85, t("m_ecapa"))
    snapshot_download(paths.ECAPA_REPO)

    progress("setup", 90, t("m_demucs"))
    from demucs.pretrained import get_model

    get_model("htdemucs")

    progress("setup", 95, t("m_nltk"))
    import nltk

    target = f"{sys.prefix}/nltk_data"
    for pkg in ("averaged_perceptron_tagger", "averaged_perceptron_tagger_eng", "cmudict"):
        if not nltk.download(pkg, download_dir=target, quiet=True):
            log(t("m_nltk_fail", pkg=pkg))
