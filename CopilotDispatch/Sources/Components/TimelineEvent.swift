import SwiftUI

struct TimelineEvent: View {
    let color: Color
    let text: String
    let timestamp: String

    var body: some View {
        HStack(alignment: .top, spacing: GitHubSpacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(GitHubTypography.caption)
                    .foregroundStyle(GitHubColors.text)
                    .lineLimit(2)

                Text(timestamp)
                    .font(GitHubTypography.caption)
                    .foregroundStyle(GitHubColors.textSubtle)
            }

            Spacer()
        }
    }
}
