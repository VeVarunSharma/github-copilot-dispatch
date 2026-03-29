import SwiftUI

struct TerminalText: View {
    let text: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text)
                    .font(GitHubTypography.terminal)
                    .foregroundStyle(GitHubColors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(GitHubSpacing.sm)
                    .id("terminal-bottom")
            }
            .background(GitHubColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onChange(of: text) {
                withAnimation {
                    proxy.scrollTo("terminal-bottom", anchor: .bottom)
                }
            }
        }
    }
}
