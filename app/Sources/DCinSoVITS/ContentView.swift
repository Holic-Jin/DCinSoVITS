import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !model.engineReady { setupCard }
                    stepCard(1, tr(.step1), model.loadStatus) {
                        HStack {
                            Button(tr(.openVideo), systemImage: "film", action: model.openVideo)
                                .disabled(model.busy || !model.engineReady)
                            if let name = model.videoName {
                                Text(name).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                            } else {
                                Text(tr(.dropHint)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    stepCard(2, tr(.step2), model.separateStatus) {
                        Button(tr(.separate), systemImage: "waveform.badge.magnifyingglass", action: model.separate)
                            .disabled(model.busy || model.loadStatus != .done)
                    }
                    if !model.speakers.isEmpty { speakerCard }
                    stepCard(3, tr(.step3), model.convertStatus) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button(tr(.convert), systemImage: "cpu", action: model.convert)
                                    .disabled(model.busy || model.selectedSpeaker == nil || model.separateStatus != .done)
                                if let s = model.selectedSpeaker {
                                    Text(tr(.selectedSpeaker, s.replacingOccurrences(of: "SPK", with: ""))).foregroundStyle(.secondary)
                                }
                            }
                            DisclosureGroup(tr(.advanced)) {
                                HStack(spacing: 20) {
                                    Stepper("SoVITS epoch: \(model.sovitsEpochs)", value: $model.sovitsEpochs, in: 1...25)
                                    Stepper("GPT epoch: \(model.gptEpochs)", value: $model.gptEpochs, in: 1...50)
                                }
                                .disabled(model.busy)
                                Text(tr(.advancedNote))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .font(.callout)
                        }
                    }
                    stepCard(4, tr(.step4), model.sampleLight) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Button(model.playingID == "sample" ? tr(.stop) : tr(.play),
                                       systemImage: model.playingID == "sample" ? "stop.fill" : "play.fill") {
                                    model.playingID == "sample" ? model.stopPlayback() : model.playSample()
                                }
                                .disabled(model.busy || model.convertStatus != .done)
                                Button(tr(.sampleSave), systemImage: "square.and.arrow.down", action: model.exportSample)
                                    .disabled(model.busy || model.sampleLight != .done)
                            }
                            Text("“\(tr(.sampleSentence))”").font(.callout).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    stepCard(5, tr(.step5), model.exportStatus) {
                        Button(tr(.exportButton), systemImage: "square.and.arrow.up", action: model.export)
                            .disabled(model.busy || model.convertStatus != .done)
                    }
                }
                .padding(20)
            }
            statusBar
            footer
        }
        .frame(minWidth: 620, minHeight: 640)
        .toolbar { ToolbarItem(placement: .primaryAction) { LanguagePicker() } }
        .onDrop(of: [.fileURL], isTargeted: $model.dropTargeted) { providers in
            guard model.engineReady, !model.busy, let p = providers.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in model.loadVideo(url) } }
            }
            return true
        }
        .overlay { if model.dropTargeted { RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 3).padding(4) } }
    }

    // MARK: - parts

    private var setupCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    StatusLight(status: model.setupStatus)
                    Text(tr(.setupTitle)).font(.headline)
                }
                Text(tr(.setupBody))
                    .font(.callout).foregroundStyle(.secondary)
                Button(tr(.install), systemImage: "arrow.down.circle", action: model.installEngine)
                    .disabled(model.busy)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
    }

    private var speakerCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tr(.speakersTitle)).font(.headline)
                    if let l = model.language { Text(tr(.detectedLang, AppModel.languageNames[l] ?? l)).foregroundStyle(.secondary) }
                    Spacer()
                    Text(tr(.speakersHint)).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
                ForEach(model.speakers) { s in
                    SpeakerRow(speaker: s,
                               selected: model.selectedSpeaker == s.id,
                               playing: model.playingID == s.id,
                               onSelect: { if !model.busy { model.selectedSpeaker = s.id } },
                               onPlay: { model.togglePreview(s) })
                }
            }
            .padding(6)
        }
    }

    private func stepCard<C: View>(_ n: Int, _ title: String, _ status: StepStatus, @ViewBuilder content: () -> C) -> some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                StatusLight(status: status).padding(.top, 3)
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(n). \(title)").font(.headline)
                    content()
                }
                Spacer(minLength: 0)
            }
            .padding(6)
        }
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.busy {
                HStack {
                    ProgressView(value: model.progress, total: 100)
                    Text("\(Int(model.progress))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                    Button(tr(.cancel), action: model.cancel)
                }
            }
            if let err = model.errorMessage {
                Label(err, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red).font(.callout).lineLimit(4).textSelection(.enabled)
            } else if !model.message.isEmpty {
                Text(model.message).font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, model.busy || model.errorMessage != nil || !model.message.isEmpty ? 10 : 0)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
            Text(Disclaimer.footer)
            Spacer()
            Text(tr(.madeBy, AppInfo.creator))
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct DisclaimerView: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack { Spacer(); LanguagePicker() }
            Image(systemName: "exclamationmark.shield").font(.system(size: 44)).foregroundStyle(.orange)
            Text("\(AppInfo.name) \(Disclaimer.title)").font(.title2.bold())
            Text(Disclaimer.body)
                .font(.body)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
            HStack {
                Button(tr(.quit)) { NSApp.terminate(nil) }
                Spacer()
                Button(tr(.accept), action: onAccept).keyboardShortcut(.defaultAction)
            }
            Text(tr(.madeBy, AppInfo.creator)).font(.caption).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 520)
    }
}
