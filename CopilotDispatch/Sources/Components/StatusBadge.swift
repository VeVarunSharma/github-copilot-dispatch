import SwiftUI

extension SessionStatus {
    var color: Color {
        switch self {
        case .pending: return GitHubColors.yellow
        case .working: return GitHubColors.green
        case .completed: return GitHubColors.green
        case .failed: return GitHubColors.red
        case .stalled: return GitHubColors.textMuted
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .working: return "circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .stalled: return "stop.circle"
        }
    }
}

struct StatusBadge: View {
    let status: SessionStatus
    var showLabel: Bool = true

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: GitHubSpacing.xs) {
            Image(systemName: status.icon)
                .foregroundStyle(status.color)
                .font(.caption)
                .opacity(status == .working && isPulsing ? 0.6 : 1.0)
                .animation(
                    status == .working
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: isPulsing
                )

            if showLabel {
                Text(status.label)
                    .font(GitHubTypography.caption)
                    .foregroundStyle(status.color)
            }
        }
        .onAppear {
            if status == .working {
                isPulsing = true
            }
        }
    }
}
