# DCinSoVITS

[한국어](README_kr.md) | [English](README_en.md) | [日本語](README_jp.md)

A native macOS app that extracts audio from a video, splits it by speaker, and builds **GPT-SoVITS (v2) fine-tuned weights** from the speaker you choose.

Made by **HolicJin**

> ⚠️ **Disclaimer** — This program includes **no video, no preloaded celebrity voices, and no biometric sample data**. You are solely responsible for any video you load and for all data created with this program (separated audio, model weights, synthesized speech, and so on). Do not use another person’s voice without the rights holder’s consent.

## Responsible use

This project is a **general-purpose local tool**. It is **not** designed, encouraged, or intended for uses prohibited by [GitHub Acceptable Use Policies](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies) or [GitHub Synthetic Media and AI Tools](https://docs.github.com/en/site-policy/acceptable-use-policies/github-synthetic-media-and-ai-tools).

**Allowed only with rights and consent.** Train and synthesize only from audio/video you own, or for which you have explicit permission from the rights holder and the speaker.

**Prohibited uses include** (non-exhaustive):

- Creating or facilitating **CSAM** or any sexual content involving minors
- Creating or facilitating **non-consensual intimate imagery (NCII)**
- Creating or facilitating **terrorist or violent extremist** content
- **Fraud, scams, phishing, harassment**, or other criminal activity
- **Unauthorized impersonation** of a real person or organization
- **Deceptive synthetic media** presented as authentic in order to mislead others
- Cloning or distributing another person’s voice **without informed consent** (or other clear lawful basis)

Where required by law or where a listener could reasonably be misled, label AI-generated / cloned audio as synthetic. You are solely responsible for complying with local law and with GitHub’s terms. The maintainers do not condone misuse.

## How to use

1. **Load a video** (button or drag onto the window) — only the audio track is extracted. The video file is not copied or stored.
2. **Separate** — remove background (Demucs) → speech recognition and language detection (Whisper) → speaker split (ECAPA). Done: 🟢
3. **Preview** with ▶ in the speaker list, then **select the speaker** to train.
4. **Convert** — build the dataset → GPT-SoVITS preprocess → SoVITS and GPT fine-tune. Done: 🟢
5. **Play** — synthesizes a fixed sample sentence in the **UI language** (Korean / English / Japanese). Cross-lingual synthesis works even if the video language differs. **Save sample…** writes the current language’s sample as a WAV.
6. **Export** — save to a folder:

| File | Contents |
|---|---|
| `<name>-e15.ckpt` | GPT weights (put in GPT-SoVITS `GPT_weights_v2`) |
| `<name>_e8.pth` | SoVITS weights (`SoVITS_weights_v2`) |
| `ref.wav`, `ref.txt` | Reference audio and transcript for inference |
| `sample_ko.wav`, etc. | Sample synthesis for each language you played |
| `dcinsovits.json` | Metadata such as language and training settings |
| `DISCLAIMER.txt` | Disclaimer |

Status lights: ⚪ idle · 🟡 in progress · 🟢 done · 🔴 error

### UI language

Use the 🌐 menu at the top right of the window (also on the first-run disclaimer) to choose **한국어 / English / 日本語**.
It switches immediately, without restart, and the choice is saved. On first launch it follows the macOS language.
Engine progress and error messages and the sample TTS sentence follow the same language. Exported `DISCLAIMER.txt` is written in all three languages.

## Requirements

- Apple Silicon Mac, macOS 14 or later, 16 GB memory
- **Engine install** on first launch (internet required, about 4 GB, `~/Library/Application Support/DCinSoVITS`)
  - The app itself is a few MB; the engine and models are installed outside the app. Deleting that folder removes only the engine.
- Supported languages: Korean, Japanese, Chinese, English, Cantonese (auto-detected)
- Training data should be **at least 1 minute** per speaker (3–10 minutes recommended).

## 16 GB memory

- Each stage runs in a separate process and releases all memory when it finishes.
- Demucs processes 1-minute chunks; training uses batch 4 / fp32 / CPU (GPT-SoVITS upstream’s recommended macOS setup).
- Default epochs: SoVITS 8, GPT 15 (change in advanced settings).

## Build

```bash
scripts/build_app.sh
```

→ `dist/DCinSoVITS.app` (Command Line Tools only; Xcode is not required).  
This repository contains source only. Build products (`.app`, `.build`) are not included.

Run during development:

```bash
cd app && swift run
```

## Layout

```
app/      SwiftUI app (UI, audio extract, engine process)
engine/   Python engine dcin_engine (separate / convert / sample / export) + setup.sh
scripts/  .app bundle build
```

Engine CLI after install:

```bash
PYTHONPATH=engine ~/Library/Application\ Support/DCinSoVITS/venv/bin/python -m dcin_engine separate --job <job-folder>
```

## Open source used

GPT-SoVITS (MIT), Demucs (MIT), Whisper / mlx-whisper (MIT), SpeechBrain (Apache-2.0)

## License

MIT — see [LICENSE](LICENSE). Also see [DISCLAIMER.txt](DISCLAIMER.txt).
