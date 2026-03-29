import SwiftUI

struct AuthView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: GitHubSpacing.md) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 30))
                    .foregroundStyle(GitHubColors.purple)

                Text("Sign in to GitHub")
                    .font(GitHubTypography.headline)
                    .foregroundStyle(GitHubColors.text)

                if viewModel.isLoading {
                    ProgressView()
                        .tint(GitHubColors.purple)
                    Text("Requesting code...")
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.textMuted)
                } else if !viewModel.userCode.isEmpty {
                    Text("Enter this code at")
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.textMuted)

                    Text("github.com/login/device")
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.blue)

                    Text(viewModel.userCode)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(GitHubColors.text)
                        .padding(.vertical, GitHubSpacing.sm)
                        .padding(.horizontal, GitHubSpacing.lg)
                        .background(GitHubColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if viewModel.isPolling {
                        HStack(spacing: GitHubSpacing.xs) {
                            ProgressView()
                                .tint(GitHubColors.yellow)
                                .scaleEffect(0.7)
                            Text("Waiting for auth...")
                                .font(GitHubTypography.caption)
                                .foregroundStyle(GitHubColors.yellow)
                        }
                    }
                } else if let error = viewModel.error {
                    Text(error)
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.red)
                        .multilineTextAlignment(.center)

                    CopilotButton("Try Again", icon: "arrow.clockwise") {
                        Task { await viewModel.startDeviceCodeFlow() }
                    }
                }
            }
            .padding(GitHubSpacing.sm)
        }
        .background(GitHubColors.background)
        .task {
            await viewModel.startDeviceCodeFlow()
        }
        .onDisappear {
            viewModel.cancel()
        }
    }
}
