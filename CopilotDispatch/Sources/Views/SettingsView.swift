import SwiftUI

struct SettingsView: View {
    @State private var user: GitHubUser?
    @State private var isLoading = true
    @State private var showSignOutConfirmation = false

    var onSignOut: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: GitHubSpacing.md) {
                if isLoading {
                    ProgressView()
                        .tint(GitHubColors.green)
                } else if let user {
                    GitHubIcon.logo(size: 40)

                    Text(user.login)
                        .font(GitHubTypography.headline)
                        .foregroundStyle(GitHubColors.text)

                    if let name = user.name {
                        Text(name)
                            .font(GitHubTypography.caption)
                            .foregroundStyle(GitHubColors.textMuted)
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(GitHubColors.textMuted)

                    Text("Unable to load profile")
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.textMuted)
                }

                Divider()
                    .background(GitHubColors.border)

                Button(action: {
                    showSignOutConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .font(GitHubTypography.body)
                    .foregroundStyle(GitHubColors.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, GitHubSpacing.sm)
                    .background(GitHubColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    "Sign out of GitHub?",
                    isPresented: $showSignOutConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Sign Out", role: .destructive) {
                        onSignOut()
                    }
                }

                Text("Copilot Dispatch v0.1.0")
                    .font(GitHubTypography.caption)
                    .foregroundStyle(GitHubColors.textSubtle)
            }
            .padding(GitHubSpacing.sm)
        }
        .background(GitHubColors.background)
        .navigationTitle("Settings")
        .task {
            await loadUser()
        }
    }

    private func loadUser() async {
        isLoading = true
        do {
            user = try await APIClient.shared.getUser()
        } catch {
            user = nil
        }
        isLoading = false
    }
}
