import SwiftUI

struct PRListView: View {
    @State private var viewModel = PRListViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: GitHubSpacing.sm) {
                // Repo picker
                NavigationLink {
                    PRRepoPickerView(
                        repositories: viewModel.repositories,
                        selectedRepo: Binding(
                            get: { viewModel.selectedRepo },
                            set: { if let r = $0 { viewModel.selectRepo(r) } }
                        )
                    )
                } label: {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(GitHubColors.blue)
                        Text(viewModel.selectedRepo?.fullName ?? "Select repo")
                            .font(GitHubTypography.caption)
                            .foregroundStyle(
                                viewModel.selectedRepo != nil
                                    ? GitHubColors.text
                                    : GitHubColors.textMuted
                            )
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(GitHubColors.textSubtle)
                    }
                    .padding(GitHubSpacing.sm)
                    .background(GitHubColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                // Content
                if viewModel.isLoadingPRs && viewModel.pullRequests.isEmpty {
                    ProgressView()
                        .tint(GitHubColors.green)
                        .padding(.top, GitHubSpacing.lg)
                } else if viewModel.pullRequests.isEmpty {
                    VStack(spacing: GitHubSpacing.sm) {
                        Image(systemName: "arrow.triangle.pull")
                            .font(.system(size: 24))
                            .foregroundStyle(GitHubColors.textMuted)
                        Text("No open PRs")
                            .font(GitHubTypography.caption)
                            .foregroundStyle(GitHubColors.textMuted)
                    }
                    .padding(.top, GitHubSpacing.lg)
                } else {
                    ForEach(viewModel.pullRequests) { pr in
                        NavigationLink(destination: PRDetailView(
                            owner: viewModel.selectedRepo.map {
                                String($0.fullName.split(separator: "/").first ?? "")
                            } ?? "",
                            repo: viewModel.selectedRepo.map {
                                String($0.fullName.split(separator: "/").last ?? "")
                            } ?? "",
                            prNumber: pr.number
                        )) {
                            PRRowView(pr: pr)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let error = viewModel.error {
                    Text(error)
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.red)
                }
            }
            .padding(.horizontal, GitHubSpacing.sm)
        }
        .background(GitHubColors.background)
        .navigationTitle("Pull Requests")
        .task {
            await viewModel.loadRepositories()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}

// MARK: - PR Row

struct PRRowView: View {
    let pr: PullRequestModel

    var stateColor: Color {
        if pr.draft { return GitHubColors.yellow }
        switch pr.state {
        case "merged": return GitHubColors.purple
        case "closed": return GitHubColors.red
        default: return GitHubColors.green
        }
    }

    var ciIcon: String {
        switch pr.ciStatus {
        case "success": return "checkmark.circle.fill"
        case "failure": return "xmark.circle.fill"
        case "pending": return "clock"
        default: return ""
        }
    }

    var ciColor: Color {
        switch pr.ciStatus {
        case "success": return GitHubColors.green
        case "failure": return GitHubColors.red
        case "pending": return GitHubColors.yellow
        default: return GitHubColors.textSubtle
        }
    }

    var body: some View {
        HStack(spacing: GitHubSpacing.sm) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("#\(pr.number)")
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.textMuted)
                    Text(pr.title)
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.text)
                        .lineLimit(1)
                }

                HStack(spacing: GitHubSpacing.xs) {
                    Text(pr.author)
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.textSubtle)

                    Spacer()

                    if !ciIcon.isEmpty {
                        Image(systemName: ciIcon)
                            .font(.system(size: 10))
                            .foregroundStyle(ciColor)
                    }

                    if pr.draft {
                        Text("draft")
                            .font(GitHubTypography.caption)
                            .foregroundStyle(GitHubColors.yellow)
                    }
                }
            }
        }
        .padding(.vertical, GitHubSpacing.xs)
    }
}

// MARK: - Repo Picker

struct PRRepoPickerView: View {
    let repositories: [RepositoryModel]
    @Binding var selectedRepo: RepositoryModel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(repositories) { repo in
            Button {
                selectedRepo = repo
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(repo.name)
                            .font(GitHubTypography.caption)
                            .foregroundStyle(GitHubColors.text)
                        Text(repo.owner)
                            .font(GitHubTypography.caption)
                            .foregroundStyle(GitHubColors.textSubtle)
                    }
                    Spacer()
                    if selectedRepo?.fullName == repo.fullName {
                        Image(systemName: "checkmark")
                            .foregroundStyle(GitHubColors.green)
                    }
                }
            }
            .listRowBackground(GitHubColors.surface)
        }
        .listStyle(.plain)
        .navigationTitle("Select Repo")
    }
}
