import SwiftUI

struct CopilotButton: View {
    let title: String
    let icon: String?
    var style: CopilotButtonStyle = .primary
    let action: () -> Void

    enum CopilotButtonStyle {
        case primary
        case secondary
        case danger

        var backgroundColor: Color {
            switch self {
            case .primary: return GitHubColors.btnPrimary
            case .secondary: return GitHubColors.btnSecondary
            case .danger: return GitHubColors.red
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return GitHubColors.text
            case .danger: return .white
            }
        }
    }

    init(_ title: String, icon: String? = nil, style: CopilotButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: GitHubSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(GitHubTypography.body)
            .foregroundStyle(style.foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, GitHubSpacing.sm)
            .background(style.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
