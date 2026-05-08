import SwiftUI

struct NewSessionView: View {
    @State private var viewModel = NewSessionViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: GitHubSpacing.md) {
                // Repository picker
                VStack(alignment: .leading, spacing: GitHubSpacing.xs) {
                    Text("Repository")
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.textMuted)

                    if viewModel.isLoadingRepos {
                        HStack {
                            ProgressView()
                                .tint(GitHubColors.purple)
                                .scaleEffect(0.8)
                            Text("Loading repos...")
                                .font(GitHubTypography.caption)
                                .foregroundStyle(GitHubColors.textMuted)
                        }
                    } else {
                        NavigationLink {
                            RepoPickerView(
                                repositories: viewModel.repositories,
                                selectedRepo: $viewModel.selectedRepo
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
                    }
                }

                // Task description
                VStack(alignment: .leading, spacing: GitHubSpacing.xs) {
                    Text("Task")
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.textMuted)

                    TextField("Describe the task...", text: $viewModel.taskDescription)
                        .font(GitHubTypography.caption)
                        .textFieldStyle(.plain)
                        .padding(GitHubSpacing.sm)
                        .background(GitHubColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Error display
                if let error = viewModel.error {
                    Text(error)
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.red)
                        .multilineTextAlignment(.center)
                }

                // Launch button
                CopilotButton(
                    "Launch",
                    icon: "paperplane.fill",
                    style: .primary
                ) {
                    Task {
                        await viewModel.launchSession()
                        if viewModel.createdSession != nil {
                            dismiss()
                        }
                    }
                }
                .opacity(viewModel.canLaunch ? 1.0 : 0.5)
                .disabled(!viewModel.canLaunch)

                if viewModel.isLaunching {
                    ProgressView()
                        .tint(GitHubColors.purple)
                }
            }
            .padding(GitHubSpacing.sm)
        }
        .background(GitHubColors.background)
        .navigationTitle("New Session")
        .task {
            await viewModel.loadRepositories()
        }
    }
}

// MARK: - Repository Picker

struct RepoPickerView: View {
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

                    if let language = repo.language {
                        Text(language)
                            .font(GitHubTypography.caption)
                            .foregroundStyle(GitHubColors.blue)
                    }

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
