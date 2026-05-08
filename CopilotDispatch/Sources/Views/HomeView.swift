import SwiftUI

struct HomeView: View {
    var onSignOut: () -> Void

    @State private var activeCount: Int = 0
    @State private var recentSessions: [SessionSummaryModel] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GitHubSpacing.md) {
                    // Header with branding
                    HStack {
                        GitHubIcon.logo(size: 22)
                        Text("Copilot Dispatch")
                            .font(GitHubTypography.headline)
                            .foregroundStyle(GitHubColors.text)
                    }
                    .padding(.bottom, GitHubSpacing.xs)

                    // Active agents indicator
                    if activeCount > 0 {
                        HStack(spacing: GitHubSpacing.sm) {
                            Circle()
                                .fill(GitHubColors.green)
                                .frame(width: 8, height: 8)
                            Text("\(activeCount) agent\(activeCount == 1 ? "" : "s") running")
                                .font(GitHubTypography.caption)
                                .foregroundStyle(GitHubColors.green)
                        }
                        .padding(.vertical, GitHubSpacing.xs)
                        .padding(.horizontal, GitHubSpacing.sm)
                        .background(GitHubColors.green.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Quick actions
                    NavigationLink(destination: NewSessionView()) {
                        Label("New Session", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, GitHubSpacing.sm)
                            .background(GitHubColors.btnPrimary)
                            .foregroundStyle(GitHubColors.btnPrimaryText)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: SessionListView()) {
                        Label("Sessions", systemImage: "terminal")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, GitHubSpacing.sm)
                            .background(GitHubColors.btnSecondary)
                            .foregroundStyle(GitHubColors.btnSecondaryText)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: PRListView()) {
                        Label("Pull Requests", systemImage: "arrow.triangle.pull")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, GitHubSpacing.sm)
                            .background(GitHubColors.btnSecondary)
                            .foregroundStyle(GitHubColors.btnSecondaryText)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: SettingsView(onSignOut: onSignOut)) {
                        Label("Settings", systemImage: "gearshape")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, GitHubSpacing.sm)
                            .background(GitHubColors.btnSecondary)
                            .foregroundStyle(GitHubColors.btnSecondaryText)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Recent activity section
                    if !recentSessions.isEmpty {
                        VStack(alignment: .leading, spacing: GitHubSpacing.sm) {
                            Text("Recent")
                                .font(GitHubTypography.caption)
                                .foregroundStyle(GitHubColors.textMuted)

                            ForEach(recentSessions) { session in
                                HStack {
                                    StatusBadge(status: session.sessionStatus, showLabel: false)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(session.prompt)
                                            .font(GitHubTypography.caption)
                                            .foregroundStyle(GitHubColors.text)
                                            .lineLimit(1)
                                        Text(session.repo)
                                            .font(GitHubTypography.caption)
                                            .foregroundStyle(GitHubColors.textSubtle)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, GitHubSpacing.sm)
            }
            .background(GitHubColors.background)
        }
    }
}

