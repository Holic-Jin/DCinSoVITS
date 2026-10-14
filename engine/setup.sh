#!/bin/bash
# DCinSoVITS engine installer — by HolicJin
# Installs the Python runtime, GPT-SoVITS and pretrained models into
#   ~/Library/Application Support/DCinSoVITS
# Prints JSON lines ({"type":"progress"|"log"|"done"|"error", ...}) for the app.
set -uo pipefail

ENGINE_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${DCIN_ROOT:-$HOME/Library/Application Support/DCinSoVITS}"
GSV_COMMIT="1b47ca07ef43a284e0b8bd7f29d3e1e3ff76082a"
PY_VERSION="3.11"
VENV="$ROOT/venv"
GSV_DIR="$ROOT/GPT-SoVITS"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export UV_CACHE_DIR="$ROOT/cache/uv"
export HF_HOME="$ROOT/cache/hf"

# L "한국어" "English" "日本語" → DCIN_LANG(ko/en/ja)에 맞는 문구
L() { case "${DCIN_LANG:-ko}" in en) echo "$2" ;; ja) echo "$3" ;; *) echo "$1" ;; esac; }
json_str() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1], ensure_ascii=False))' "$1" 2>/dev/null || printf '"%s"' "$1"; }
progress() { echo "{\"type\":\"progress\",\"stage\":\"setup\",\"pct\":$1,\"msg\":$(json_str "$2")}"; }
log() { echo "{\"type\":\"log\",\"msg\":$(json_str "$1")}"; }
fail() { echo "{\"type\":\"error\",\"msg\":$(json_str "$1")}"; exit 1; }
run() { # run command, forward output as log lines
  "$@" 2>&1 | while IFS= read -r line; do log "$line"; done
  return "${PIPESTATUS[0]}"
}

mkdir -p "$ROOT/cache" "$ROOT/jobs" || fail "$(L "폴더를 만들 수 없습니다" "Cannot create folder" "フォルダを作成できません"): $ROOT"

# 1. uv
progress 2 "$(L "uv 확인" "Checking uv" "uv を確認")"
if ! command -v uv >/dev/null 2>&1; then
  progress 3 "$(L "uv 설치 (astral.sh)" "Installing uv (astral.sh)" "uv をインストール (astral.sh)")"
  run sh -c "curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh" || fail "$(L "uv 설치 실패" "uv installation failed" "uv のインストールに失敗")"
  command -v uv >/dev/null 2>&1 || fail "$(L "uv를 찾을 수 없습니다" "uv not found" "uv が見つかりません")"
fi

# 2. Python venv
progress 5 "$(L "Python $PY_VERSION 환경 생성" "Creating Python $PY_VERSION environment" "Python $PY_VERSION 環境を作成")"
if [ ! -x "$VENV/bin/python" ]; then
  run uv venv --python "$PY_VERSION" "$VENV" || fail "$(L "Python 환경 생성 실패" "Failed to create Python environment" "Python 環境の作成に失敗")"
fi
PY="$VENV/bin/python"

# 3. GPT-SoVITS source (pinned commit)
progress 10 "$(L "GPT-SoVITS 소스 다운로드" "Downloading GPT-SoVITS source" "GPT-SoVITS ソースをダウンロード")"
if [ ! -f "$GSV_DIR/.commit" ] || [ "$(cat "$GSV_DIR/.commit")" != "$GSV_COMMIT" ]; then
  TMPZ="$ROOT/cache/gsv.zip"
  run curl -fL --retry 3 -o "$TMPZ" "https://github.com/RVC-Boss/GPT-SoVITS/archive/$GSV_COMMIT.zip" || fail "$(L "GPT-SoVITS 다운로드 실패" "GPT-SoVITS download failed" "GPT-SoVITS のダウンロードに失敗")"
  rm -rf "$GSV_DIR" "$ROOT/cache/GPT-SoVITS-$GSV_COMMIT"
  run unzip -q -o "$TMPZ" -d "$ROOT/cache" || fail "$(L "압축 해제 실패" "Extraction failed" "展開に失敗")"
  mv "$ROOT/cache/GPT-SoVITS-$GSV_COMMIT" "$GSV_DIR" || fail "$(L "GPT-SoVITS 설치 실패" "GPT-SoVITS installation failed" "GPT-SoVITS のインストールに失敗")"
  echo "$GSV_COMMIT" > "$GSV_DIR/.commit"
  rm -f "$TMPZ"
fi

# 4. Python packages (WebUI-only packages are skipped to save space)
progress 20 "$(L "Python 패키지 설치 (수 분 소요)" "Installing Python packages (takes a few minutes)" "Python パッケージをインストール（数分かかります）")"
REQ="$ROOT/cache/requirements.txt"
grep -v -E '^(--no-binary|funasr|modelscope|fastapi|faster-whisper|ctranslate2|onnxruntime-gpu)' \
  "$GSV_DIR/requirements.txt" > "$REQ"
run uv pip install --python "$PY" -r "$REQ" -r "$ENGINE_DIR/requirements-engine.txt" || fail "$(L "패키지 설치 실패" "Package installation failed" "パッケージのインストールに失敗")"

# 5. Pretrained models + NLTK data
progress 60 "$(L "사전학습 모델 다운로드 (~3GB)" "Downloading models (~3GB)" "モデルをダウンロード（約3GB）")"
PYTHONPATH="$ENGINE_DIR" "$PY" -m dcin_engine fetch-models || fail "$(L "모델 다운로드 실패" "Model download failed" "モデルのダウンロードに失敗")"

# 설치 캐시 정리 (디스크 절약)
rm -rf "$UV_CACHE_DIR"

echo "$GSV_COMMIT" > "$ROOT/.ready"
progress 100 "$(L "설치 완료" "Installation complete" "インストール完了")"
echo '{"type":"done","stage":"setup"}'
