import SwiftUI

struct SpeakerRow: View {
    let speaker: Speaker
    let selected: Bool
    let playing: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(selected ? Color.accentColor : .secondary)
                .font(.title3)
            Button(action: onPlay) {
                Image(systemName: playing ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .help(playing ? tr(.stop) : tr(.preview))
            VStack(alignment: .leading, spacing: 2) {
                Text(tr(.speakerName, speaker.id.replacingOccurrences(of: "SPK", with: ""))).font(.headline)
                Text(tr(.speakerStats, speaker.count, Self.format(speaker.duration)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if speaker.duration < 60 {
                Label(tr(.shortWarning), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor.opacity(0.12) : .clear))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    static func format(_ sec: Double) -> String {
        let s = Int(sec.rounded())
        return s >= 60 ? tr(.durMinSec, s / 60, s % 60) : tr(.durSec, s)
    }
}
