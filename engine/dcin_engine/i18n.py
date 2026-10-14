"""엔진 메시지 다국어(ko/en/ja). 앱이 넘겨준 DCIN_LANG 환경변수를 따른다."""

import os

LANG = os.environ.get("DCIN_LANG", "ko")
if LANG not in ("ko", "en", "ja"):
    LANG = "ko"

# key: (ko, en, ja) — str.format 자리표시자 사용
MESSAGES = {
    # setup / models
    "m_gsv": ("GPT-SoVITS v2 사전학습 모델", "GPT-SoVITS v2 pretrained models", "GPT-SoVITS v2 事前学習モデル"),
    "m_whisper": ("Whisper 음성인식 모델", "Whisper speech recognition model", "Whisper 音声認識モデル"),
    "m_ecapa": ("화자 임베딩 모델 (ECAPA)", "Speaker embedding model (ECAPA)", "話者埋め込みモデル (ECAPA)"),
    "m_demucs": ("음성 분리 모델 (Demucs)", "Vocal separation model (Demucs)", "音声分離モデル (Demucs)"),
    "m_nltk": ("영어 발음 사전 (NLTK)", "English pronunciation data (NLTK)", "英語発音辞書 (NLTK)"),
    "m_nltk_fail": ("NLTK {pkg} 다운로드 실패 (영어 학습 시 필요)", "NLTK {pkg} download failed (needed for English)",
                    "NLTK {pkg} のダウンロードに失敗（英語の学習に必要）"),
    # separate
    "s_prepare": ("보컬 분리 준비", "Preparing vocal separation", "ボーカル分離の準備"),
    "s_vocals": ("보컬 분리 중", "Separating vocals", "ボーカル分離中"),
    "s_mps_fallback": ("MPS 실패 → CPU 사용 ({err})", "MPS failed → using CPU ({err})", "MPS失敗 → CPUを使用 ({err})"),
    "s_asr": ("음성 인식 중 (언어 자동 감지)", "Transcribing (auto language detection)", "音声認識中（言語自動検出）"),
    "s_diarize": ("화자 구분 중", "Identifying speakers", "話者を識別中"),
    "s_found": ("화자 {n}명 검출", "{n} speaker(s) found", "話者 {n} 人を検出"),
    "e_no_source": ("source.wav가 없습니다. 영상을 먼저 불러오세요.", "source.wav is missing. Load a video first.",
                    "source.wav がありません。先に動画を読み込んでください。"),
    "e_lang": ("지원하지 않는 언어입니다: {lang} (지원: 한/일/중/영/광동어)",
               "Unsupported language: {lang} (supported: ko/ja/zh/en/yue)",
               "未対応の言語です: {lang}（対応: 韓/日/中/英/広東語）"),
    "e_no_speech": ("영상에서 음성을 찾지 못했습니다.", "No speech was found in the video.", "動画から音声が見つかりませんでした。"),
    # convert
    "c_dataset": ("데이터셋 생성", "Building dataset", "データセット作成"),
    "c_dataset_info": ("데이터셋: {n}개 클립, {sec:.0f}초, 언어={lang}", "Dataset: {n} clips, {sec:.0f}s, language={lang}",
                       "データセット: {n} クリップ, {sec:.0f} 秒, 言語={lang}"),
    "c_text": ("텍스트 → 음소 변환", "Text → phonemes", "テキスト → 音素変換"),
    "c_hubert": ("음성 특징(HuBERT) 추출", "Extracting speech features (HuBERT)", "音声特徴量 (HuBERT) 抽出"),
    "c_semantic": ("시맨틱 토큰 추출", "Extracting semantic tokens", "セマンティックトークン抽出"),
    "c_epoch": ("{name} 학습 {ep}/{total} epoch", "{name} training {ep}/{total} epochs", "{name} 学習 {ep}/{total} epoch"),
    "c_epoch_done": ("{name} 학습 {ep}/{total} epoch 완료", "{name} training {ep}/{total} epochs done",
                     "{name} 学習 {ep}/{total} epoch 完了"),
    "c_done": ("변환 완료", "Conversion complete", "変換完了"),
    "e_speaker": ("화자를 찾을 수 없습니다: {id}", "Speaker not found: {id}", "話者が見つかりません: {id}"),
    "e_too_few": ("학습 가능한 발화가 너무 적습니다 (최소 4개, 권장 1분 이상).",
                  "Too few usable utterances (min. 4; 1+ minute recommended).",
                  "学習に使える発話が少なすぎます（最低4件、1分以上推奨）。"),
    "e_script": ("{name} 실패:\n{tail}", "{name} failed:\n{tail}", "{name} 失敗:\n{tail}"),
    "e_empty": ("전처리 결과가 비어 있습니다 (음성/텍스트 확인 필요).", "Preprocessing produced no data (check audio/text).",
                "前処理の結果が空です（音声/テキストを確認してください）。"),
    "e_no_sovits": ("SoVITS 가중치가 생성되지 않았습니다.", "SoVITS weights were not created.", "SoVITS の重みが生成されませんでした。"),
    "e_no_gpt": ("GPT 가중치가 생성되지 않았습니다.", "GPT weights were not created.", "GPT の重みが生成されませんでした。"),
    # sample
    "t_load": ("모델 불러오는 중", "Loading model", "モデルを読み込み中"),
    "t_synth": ("음성 합성 중", "Synthesizing", "音声合成中"),
    "t_done": ("합성 완료", "Synthesis complete", "合成完了"),
}

_IDX = {"ko": 0, "en": 1, "ja": 2}[LANG]


def t(key: str, **kw) -> str:
    text = MESSAGES[key][_IDX]
    return text.format(**kw) if kw else text
