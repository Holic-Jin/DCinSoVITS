import SwiftUI

/// 회색=대기, 노랑(깜빡임)=진행 중, 초록=완료, 빨강=오류
struct StatusLight: View {
    let status: StepStatus

    var color: Color {
        switch status {
        case .idle: .gray.opacity(0.35)
        case .running: .yellow
        case .done: .green
        case .failed: .red
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .shadow(color: status == .idle ? .clear : color.opacity(0.8), radius: status == .done ? 5 : 3)
            .phaseAnimator(status == .running ? [1.0, 0.3] : [1.0]) { v, op in v.opacity(op) } animation: { _ in
                .easeInOut(duration: 0.6)
            }
            .accessibilityLabel(Text(label))
    }

    private var label: String {
        switch status {
        case .idle: tr(.stIdle)
        case .running: tr(.stRunning)
        case .done: tr(.stDone)
        case .failed: tr(.stFailed)
        }
    }
}
