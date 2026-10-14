# DCinSoVITS

[한국어](README.md) | [English](README_en.md) | [日本語](README_jp.md)

動画から音声だけを取り出し、話者ごとに分け、選んだ話者の声で **GPT-SoVITS (v2) のファインチューニング重み** を作る macOS ネイティブアプリです。

制作: **HolicJin**

> ⚠️ **ご利用上の注意** — 本プログラムには動画は一切含まれていません。読み込んだ動画と、本プログラムで作成したすべてのデータ（分離音声、モデルの重み、合成音声など）の利用責任は、すべて利用者ご本人にあります。他人の声を権利者の同意なく使用しないでください。

## 使い方

1. **動画を読み込む**（ボタン、またはウィンドウへドラッグ）— 音声トラックだけを抽出します。動画ファイルはコピー・保管しません。
2. **分離** — 背景音除去（Demucs）→ 音声認識・言語自動検出（Whisper）→ 話者分離（ECAPA）。完了すると 🟢
3. 話者一覧で ▶ で **試聴** し、学習する **話者を選択**
4. **変換** — データセット作成 → GPT-SoVITS 前処理 → SoVITS・GPT ファインチューニング。完了すると 🟢
5. **再生** — 学習した声で **UI 言語**（韓/英/日）の固定文を合成して再生します。動画の言語と違ってもクロスリンガルで合成されます。**サンプルを保存…** で、現在の言語のサンプルを WAV として別保存できます。
6. **書き出し** — フォルダへ保存:

| ファイル | 内容 |
|---|---|
| `<名前>-e15.ckpt` | GPT 重み（GPT-SoVITS の `GPT_weights_v2` に入れて使用） |
| `<名前>_e8.pth` | SoVITS 重み（`SoVITS_weights_v2`） |
| `ref.wav`, `ref.txt` | 推論用の参照音声とそのセリフ |
| `sample_ko.wav` など | 再生した言語ごとのサンプル合成結果 |
| `dcinsovits.json` | 言語・学習設定などのメタデータ |
| `DISCLAIMER.txt` | ご利用上の注意 |

状態ランプ: ⚪ 待機 · 🟡 処理中 · 🟢 完了 · 🔴 エラー

### UI 言語

ウィンドウ右上の 🌐 メニュー（初回起動の注意画面にもあります）で **한국어 / English / 日本語** を選べます。
再起動なしですぐ切り替わり、設定は保存されます。初回起動時は macOS の言語設定に従います。
エンジンの進行・エラーメッセージとサンプル TTS 文も同じ言語になり、書き出しの `DISCLAIMER.txt` は 3 言語で書かれます。

## 動作環境

- Apple Silicon Mac、macOS 14 以降、メモリ 16GB
- 初回起動時に **エンジンのインストール**（インターネット必須、約 4GB、`~/Library/Application Support/DCinSoVITS`）
  - アプリ本体は数 MB で、エンジンとモデルはアプリの外に入ります。そのフォルダを消すとエンジンだけが削除されます。
- 対応言語: 韓国語 · 日本語 · 中国語 · 英語 · 広東語（自動検出）
- 学習データは話者あたり **1 分以上**（推奨 3〜10 分）あるとよいです。

## 16GB メモリ向けの工夫

- 各工程は別プロセスで動き、終わるとメモリをすべて返します。
- Demucs は 1 分単位で処理。学習は batch 4 / fp32 / CPU（GPT-SoVITS 上流の macOS 推奨）。
- デフォルトの epoch: SoVITS 8、GPT 15（詳細設定で変更可）。

## ビルド

```bash
scripts/build_app.sh
```

→ `dist/DCinSoVITS.app`（Xcode なし、Command Line Tools のみでビルド）。  
このリポジトリはソースのみで、ビルド成果物（`.app`、`.build`）は含みません。

開発中の実行:

```bash
cd app && swift run
```

## 構成

```
app/      SwiftUI アプリ（UI、音声抽出、エンジンプロセス管理）
engine/   Python エンジン dcin_engine（separate / convert / sample / export）+ setup.sh
scripts/  .app バンドルのビルド
```

エンジン CLI の単独実行（インストール後）:

```bash
PYTHONPATH=engine ~/Library/Application\ Support/DCinSoVITS/venv/bin/python -m dcin_engine separate --job <作業フォルダ>
```

## 使用しているオープンソース

GPT-SoVITS (MIT), Demucs (MIT), Whisper / mlx-whisper (MIT), SpeechBrain (Apache-2.0)
