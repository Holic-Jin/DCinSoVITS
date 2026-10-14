import Foundation
import Observation
import SwiftUI

/// UI 표시 언어. 앱 안에서 즉시 전환되며 UserDefaults에 저장된다.
enum UILang: String, CaseIterable, Identifiable {
    case ko, en, ja
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ko: "한국어"
        case .en: "English"
        case .ja: "日本語"
        }
    }

    static var systemDefault: UILang {
        let pref = Locale.preferredLanguages.first?.prefix(2) ?? "en"
        return UILang(rawValue: String(pref)) ?? .en
    }
}

/// 현재 언어 저장소. 뷰가 `tr(...)`을 호출하면 `lang`을 읽으므로 언어가 바뀌면 자동으로 다시 그려진다.
@Observable
final class Loc: @unchecked Sendable {
    static let shared = Loc()
    private static let key = "uiLanguage"

    var lang: UILang {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: Self.key) }
    }

    private init() {
        lang = UserDefaults.standard.string(forKey: Self.key).flatMap(UILang.init(rawValue:)) ?? .systemDefault
    }
}

/// 번역 문자열 조회. 인자가 있으면 String(format:) 규칙(%@, %ld)을 따른다.
func tr(_ key: TrKey, _ args: CVarArg...) -> String {
    let lang = Loc.shared.lang
    let row = TrKey.table[key] ?? [key.rawValue, key.rawValue, key.rawValue]
    let fmt = row[UILang.allCases.firstIndex(of: lang) ?? 0]
    return args.isEmpty ? fmt : String(format: fmt, arguments: args)
}

enum TrKey: String {
    case language, aboutApp
    case step1, openVideo, dropHint
    case step2, separate
    case step3, convert, selectedSpeaker, advanced, advancedNote
    case step4, play, stop
    case step5, exportButton
    case setupTitle, setupBody, install
    case speakersTitle, detectedLang, speakersHint
    case cancel, quit, accept, preview
    case speakerName, speakerStats, shortWarning, durMinSec, durSec
    case errUnsupportedFormat, errNoAudioTrack, errAudioRead, errFFmpeg
    case disclaimerTitle, disclaimerBody, footer, madeBy
    case openPanelMsg, extracting, extracted, exportTitle, exportMsg
    case playFailed, error, errNoResult, errEngineSource, errNotInstalled, errUnknown, cancelled, errEngineFailed
    case stIdle, stRunning, stDone, stFailed
    case sampleSentence, sampleSave, sampleExportTitle, sampleSaved

    // [ko, en, ja] — UILang.allCases 순서
    static let table: [TrKey: [String]] = [
        .language: ["언어", "Language", "言語"],
        .aboutApp: ["%@에 관하여", "About %@", "%@について"],

        .step1: ["영상 불러오기", "Load video", "動画の読み込み"],
        .openVideo: ["영상 불러오기…", "Open video…", "動画を開く…"],
        .dropHint: ["또는 영상 파일을 창에 끌어다 놓으세요", "or drop a video file onto this window", "または動画ファイルをウィンドウにドロップ"],

        .step2: ["음성 분리 (보컬 추출 · 화자 구분)", "Separate voices (vocal extraction · speaker split)", "音声分離（ボーカル抽出・話者分け）"],
        .separate: ["분리", "Separate", "分離"],

        .step3: ["GPT-SoVITS 파라메터로 변환 (파인튜닝)", "Convert to GPT-SoVITS parameters (fine-tuning)", "GPT-SoVITSパラメータに変換（ファインチューニング）"],
        .convert: ["변환", "Convert", "変換"],
        .selectedSpeaker: ["선택: 화자 %@", "Selected: speaker %@", "選択: 話者 %@"],
        .advanced: ["고급 설정", "Advanced", "詳細設定"],
        .advancedNote: ["16GB Mac 기준 기본값. 값이 클수록 품질↑ 시간↑ (CPU 학습)",
                        "Defaults tuned for a 16GB Mac. Higher = better quality, longer time (CPU training)",
                        "16GB Mac向けの既定値。大きいほど高品質・長時間（CPU学習）"],

        .step4: ["샘플 TTS 듣기", "Listen to sample TTS", "サンプルTTSを再生"],
        .play: ["재생", "Play", "再生"],
        .stop: ["정지", "Stop", "停止"],

        .step5: ["내보내기", "Export", "書き出し"],
        .exportButton: ["파라메터 데이터 저장…", "Save parameter data…", "パラメータデータを保存…"],

        .setupTitle: ["엔진 설치 필요", "Engine installation required", "エンジンのインストールが必要です"],
        .setupBody: ["음성 분리·학습 엔진(Python, GPT-SoVITS, 모델 약 4GB)을 앱 밖의 저장소에 한 번만 설치합니다.\n위치: ~/Library/Application Support/DCinSoVITS (삭제 시 앱만 남음)",
                     "The separation/training engine (Python, GPT-SoVITS, ~4GB of models) is installed once, outside the app.\nLocation: ~/Library/Application Support/DCinSoVITS (delete it to remove the engine)",
                     "音声分離・学習エンジン（Python、GPT-SoVITS、モデル約4GB）をアプリ外に一度だけインストールします。\n場所: ~/Library/Application Support/DCinSoVITS（削除するとエンジンのみ消えます）"],
        .install: ["엔진 설치", "Install engine", "エンジンをインストール"],

        .speakersTitle: ["분리된 화자", "Separated speakers", "分離された話者"],
        .detectedLang: ["· 감지 언어: %@", "· Detected language: %@", "· 検出言語: %@"],
        .speakersHint: ["▶로 들어보고 학습할 화자를 선택하세요", "Preview with ▶ and pick the speaker to train", "▶で試聴して学習する話者を選択"],

        .cancel: ["취소", "Cancel", "キャンセル"],
        .quit: ["종료", "Quit", "終了"],
        .accept: ["동의하고 시작", "Agree and start", "同意して開始"],
        .preview: ["미리듣기", "Preview", "試聴"],

        .speakerName: ["화자 %@", "Speaker %@", "話者 %@"],
        .speakerStats: ["발화 %ld개 · %@", "%ld utterances · %@", "発話 %ld件 · %@"],
        .shortWarning: ["1분 미만 — 품질 저하 가능", "Under 1 min — quality may suffer", "1分未満 — 品質が低下する可能性"],
        .durMinSec: ["%ld분 %ld초", "%ldm %lds", "%ld分%ld秒"],
        .durSec: ["%ld초", "%lds", "%ld秒"],

        .errUnsupportedFormat: ["이 영상 형식을 열 수 없습니다 (mp4/mov/m4v 권장, 또는 ffmpeg 설치).",
                                "Can't open this video format (use mp4/mov/m4v, or install ffmpeg).",
                                "この動画形式は開けません（mp4/mov/m4v推奨、またはffmpegをインストール）。"],
        .errNoAudioTrack: ["영상에 오디오 트랙이 없습니다.", "The video has no audio track.", "動画に音声トラックがありません。"],
        .errAudioRead: ["오디오 읽기 실패", "Failed to read audio", "音声の読み込みに失敗"],
        .errFFmpeg: ["ffmpeg 오디오 추출 실패", "ffmpeg audio extraction failed", "ffmpegによる音声抽出に失敗"],

        .disclaimerTitle: ["이용 고지", "Notice", "ご利用にあたって"],
        .disclaimerBody: ["""
            본 프로그램에는 어떠한 동영상도 포함되어 있지 않습니다.
            사용자가 불러온 영상과, 본 프로그램으로 작성된 모든 데이터(분리 음성, 모델 가중치, 합성 음성 등)의 \
            수집·이용·배포에 대한 책임은 전적으로 사용자 본인에게 있습니다.
            타인의 목소리는 권리자의 동의 없이 사용하지 마십시오.
            """, """
            This program does not contain any video.
            You are solely responsible for any video you load and for collecting, using and distributing \
            all data created with this program (separated audio, model weights, synthesized speech, etc.).
            Do not use another person's voice without their consent.
            """, """
            本プログラムには動画は一切含まれていません。
            読み込んだ動画、および本プログラムで作成したすべてのデータ（分離音声・モデルの重み・合成音声など）の\
            収集・利用・配布に関する責任は、すべて利用者ご本人にあります。
            他人の声を権利者の同意なく使用しないでください。
            """],
        .footer: ["본 프로그램은 동영상을 포함하지 않으며, 작성된 데이터의 이용 책임은 사용자 본인에게 있습니다.",
                  "This program contains no video. You are solely responsible for the data you create.",
                  "本プログラムは動画を含みません。作成したデータの利用責任は利用者にあります。"],
        .madeBy: ["Made by %@", "Made by %@", "Made by %@"],

        .openPanelMsg: ["음성을 추출할 동영상을 선택하세요", "Choose a video to extract the voice from", "音声を抽出する動画を選択してください"],
        .extracting: ["오디오 추출 중…", "Extracting audio…", "音声を抽出中…"],
        .extracted: ["오디오 추출 완료 — [분리]를 누르세요", "Audio extracted — press [Separate]", "音声抽出完了 —［分離］を押してください"],
        .exportTitle: ["파라메터 데이터 내보내기", "Export parameter data", "パラメータデータの書き出し"],
        .exportMsg: ["GPT-SoVITS 가중치·참조음성·메타데이터가 이 이름의 폴더로 저장됩니다.",
                     "GPT-SoVITS weights, reference audio and metadata are saved into a folder with this name.",
                     "GPT-SoVITSの重み・参照音声・メタデータがこの名前のフォルダに保存されます。"],
        .playFailed: ["재생 실패: %@", "Playback failed: %@", "再生に失敗: %@"],
        .error: ["오류", "Error", "エラー"],
        .errNoResult: ["엔진이 결과 없이 종료되었습니다.", "The engine exited without a result.", "エンジンが結果なしで終了しました。"],
        .errEngineSource: ["엔진 소스를 찾을 수 없습니다.", "Engine source not found.", "エンジンのソースが見つかりません。"],
        .errNotInstalled: ["엔진이 설치되지 않았습니다.", "The engine is not installed.", "エンジンがインストールされていません。"],
        .errUnknown: ["알 수 없는 오류", "Unknown error", "不明なエラー"],
        .cancelled: ["작업이 취소되었습니다.", "The task was cancelled.", "処理がキャンセルされました。"],
        .errEngineFailed: ["엔진 실행 실패", "Engine failed to run", "エンジンの実行に失敗"],

        // 샘플 TTS 문장 — engine/dcin_engine/samples.py 와 동일하게 유지
        .sampleSentence: ["안녕하세요. 오늘도 좋은 하루 보내세요. 이 목소리는 샘플로 합성된 음성입니다.",
                          "Hello! I hope you have a wonderful day. This is a synthesized sample voice.",
                          "こんにちは。今日もいい一日を過ごしてください。これはサンプルとして合成された音声です。"],

        .sampleSave: ["샘플 저장…", "Save sample…", "サンプルを保存…"],
        .sampleExportTitle: ["샘플 TTS 저장", "Save sample TTS", "サンプルTTSを保存"],
        .sampleSaved: ["샘플을 저장했습니다: %@", "Sample saved: %@", "サンプルを保存しました: %@"],

        .stIdle: ["대기", "Waiting", "待機"],
        .stRunning: ["진행 중", "Running", "処理中"],
        .stDone: ["완료", "Done", "完了"],
        .stFailed: ["오류", "Error", "エラー"],
    ]
}

/// 🌐 언어 선택 메뉴 (툴바·고지 화면 공용)
struct LanguagePicker: View {
    var body: some View {
        Picker(selection: Binding(get: { Loc.shared.lang }, set: { Loc.shared.lang = $0 })) {
            ForEach(UILang.allCases) { Text($0.displayName).tag($0) }
        } label: {
            Label(tr(.language), systemImage: "globe")
        }
        .pickerStyle(.menu)
        .fixedSize()
        .help(tr(.language))
    }
}
