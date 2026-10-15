# DCinSoVITS

[한국어](README_kr.md) | [English](README_en.md) | [日本語](README_jp.md)

동영상에서 음성만 추출해 화자별로 분리하고, 선택한 화자의 목소리로 **GPT-SoVITS (v2) 파인튜닝 가중치**를 만드는 macOS 네이티브 앱입니다.

제작: **HolicJin**

> ⚠️ **이용 고지** — 본 프로그램과 저장소에는 **어떠한 동영상, 유명인 음성, 생체 샘플 데이터도 포함되어 있지 않습니다.** 사용자가 불러온 영상과 본 프로그램으로 작성된 모든 데이터(분리 음성, 모델 가중치, 합성 음성 등)의 이용 책임은 전적으로 사용자 본인에게 있습니다. 타인의 목소리는 권리자의 동의 없이 사용하지 마십시오.

## 책임 있는 이용

이 프로젝트는 **범용 로컬 도구**이며, [GitHub Acceptable Use Policies](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies) 및 [GitHub Synthetic Media and AI Tools](https://docs.github.com/en/site-policy/acceptable-use-policies/github-synthetic-media-and-ai-tools)에서 금지하는 용도로 설계·홍보·권장되지 **않습니다**.

**권리와 동의가 있는 경우에만 사용하세요.** 본인이 소유하거나, 권리자 및 화자로부터 명시적 허가를 받은 오디오/영상만 학습·합성에 사용해야 합니다.

**금지 용도(예시, 완전하지 않음):**

- **아동 성착취물(CSAM)** 또는 미성년자가 포함된 성적 콘텐츠의 생성·조장
- **비동의 친밀 이미지(NCII)** 의 생성·조장
- **테러·폭력 극단주의** 콘텐츠의 생성·조장
- **사기, 스캠, 피싱, 괴롭힘** 등 범죄 행위
- 실제 사람·조직에 대한 **무단 사칭(impersonation)**
- 진위를 속일 목적의 **기만적 합성 미디어(딥페이크)**
- **사전 동의(또는 다른 명확한 법적 근거) 없이** 타인의 목소리를 복제·배포하는 행위

법령상 요구되거나 청취자가 오해할 수 있는 경우, AI 생성/복제 음성을 합성물로 표시하세요. 관련 법과 GitHub 약관 준수 책임은 전적으로 사용자에게 있으며, 유지관리자는 오용을 용인하지 않습니다.

## 사용 방법

1. **영상 불러오기** (버튼 또는 창에 드래그) — 오디오 트랙만 추출합니다. 영상 파일은 복사·보관하지 않습니다.
2. **분리** — 배경음 제거(Demucs) → 음성 인식·언어 자동 감지(Whisper) → 화자 구분(ECAPA). 끝나면 🟢
3. 화자 목록에서 ▶로 **미리듣기** 후 학습할 **화자 선택**
4. **변환** — 데이터셋 생성 → GPT-SoVITS 전처리 → SoVITS·GPT 파인튜닝. 끝나면 🟢
5. **재생** — 학습된 목소리로 **UI 언어**(한/영/일)의 고정 문장을 합성해 들려줍니다. 영상 언어와 달라도 교차언어로 합성됩니다. **샘플 저장…**으로 현재 언어의 샘플을 WAV 파일로 따로 저장할 수 있습니다.
6. **내보내기** — 폴더로 저장:

| 파일 | 내용 |
|---|---|
| `<이름>-e15.ckpt` | GPT 가중치 (GPT-SoVITS `GPT_weights_v2`에 넣어 사용) |
| `<이름>_e8.pth` | SoVITS 가중치 (`SoVITS_weights_v2`) |
| `ref.wav`, `ref.txt` | 추론용 참조 음성과 그 대사 |
| `sample_ko.wav` 등 | 재생해 본 언어별 샘플 합성 결과 |
| `dcinsovits.json` | 언어·학습 설정 등 메타데이터 |
| `DISCLAIMER.txt` | 이용 고지 |

상태등: ⚪ 대기 · 🟡 진행 중 · 🟢 완료 · 🔴 오류

### UI 언어

창 오른쪽 위 🌐 메뉴(첫 실행 고지 화면에도 있음)에서 **한국어 / English / 日本語**를 고를 수 있습니다.
재시작 없이 바로 바뀌며 설정은 저장됩니다. 첫 실행 시에는 macOS 언어 설정을 따릅니다.
엔진 진행·오류 메시지와 샘플 TTS 문장도 같은 언어를 따르고, 내보내기의 `DISCLAIMER.txt`는 3개 언어로 작성됩니다.

## 요구 사항

- Apple Silicon Mac, macOS 14 이상, 메모리 16GB
- 첫 실행 시 **엔진 설치** (인터넷 필요, 약 4GB, `~/Library/Application Support/DCinSoVITS`)
  - 앱 자체는 수 MB이며, 엔진·모델은 앱 밖에 설치됩니다. 폴더를 지우면 엔진만 제거됩니다.
- 지원 언어: 한국어 · 일본어 · 중국어 · 영어 · 광동어 (자동 감지)
- 학습 데이터는 화자당 **1분 이상**(권장 3~10분)이 좋습니다.

## 16GB 메모리 대응

- 각 단계는 별도 프로세스로 실행되어 끝나면 메모리를 모두 반환합니다.
- Demucs는 1분 단위로 처리, 학습은 batch 4 / fp32 / CPU (GPT-SoVITS 업스트림의 macOS 권장 방식).
- 기본 epoch: SoVITS 8, GPT 15 (고급 설정에서 변경).

## 빌드

```bash
scripts/build_app.sh
```

→ `dist/DCinSoVITS.app` (Xcode 없이 Command Line Tools만으로 빌드).  
이 저장소에는 소스만 있으며, 빌드 결과물(`.app`, `.build`)은 포함하지 않습니다.

개발 중 실행:

```bash
cd app && swift run
```

## 구조

```
app/      SwiftUI 앱 (UI, 오디오 추출, 엔진 프로세스 관리)
engine/   Python 엔진 dcin_engine (separate / convert / sample / export) + setup.sh
scripts/  .app 번들 빌드
```

엔진 CLI 단독 실행 (설치 후):

```bash
PYTHONPATH=engine ~/Library/Application\ Support/DCinSoVITS/venv/bin/python -m dcin_engine separate --job <작업폴더>
```

## 사용한 오픈소스

GPT-SoVITS (MIT), Demucs (MIT), Whisper / mlx-whisper (MIT), SpeechBrain (Apache-2.0)

## 라이선스

MIT — [LICENSE](LICENSE) 참고. [DISCLAIMER.txt](DISCLAIMER.txt)도 함께 확인하세요.
