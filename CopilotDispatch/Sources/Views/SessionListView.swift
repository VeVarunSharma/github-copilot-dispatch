import SwiftUI

struct SessionListView: View {
    @State private var viewModel = SessionsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .tint(GitHubColors.purple)
            } else if viewModel.sessions.isEmpty {
                VStack(spacing: GitHubSpacing.md) {
                    Image(systemName: "terminal")
                        .font(.system(size: 30))
                        .foregroundStyle(GitHubColors.textMuted)
                    Text("No sessions yet")
                        .font(GitHubTypography.body)
                        .foregroundStyle(GitHubColors.textMuted)
                }
            } else {
                List {
                    ForEach(viewModel.sessions) { session in
                        NavigationLink(destination: SessionDetailView(sessionId: session.id)) {
                            HStack(spacing: GitHubSpacing.sm) {
                                StatusBadge(status: session.sessionStatus, showLabel: false)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.prompt)
                                        .font(GitHubTypography.caption)
                                        .foregroundStyle(GitHubColors.text)
                                        .lineLimit(1)

                                    HStack(spacing: GitHubSpacing.xs) {
                                        Text(session.repo)
                                            .font(GitHubTypography.caption)
                                            .foregroundStyle(GitHubColors.textSubtle)

                                        Spacer()

                                        Text(session.sessionStatus.label)
                                            .font(GitHubTypography.caption)
                                            .foregroundStyle(session.sessionStatus.color)
                                    }
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if session.sessionStatus == .working || session.sessionStatus == .pending {
                                Button(role: .destructive) {
                                    Task { await viewModel.cancelSession(id: session.id) }
                                } label: {
                                    Label("Cancel", systemImage: "stop.circle")
                                }
                            }
                        }
                        .listRowBackground(GitHubColors.surface)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(GitHubColors.background)
        .navigationTitle("Sessions")
        .onAppear { viewModel.startPolling() }
        .onDisappear { viewModel.stopPolling() }
    }
}

