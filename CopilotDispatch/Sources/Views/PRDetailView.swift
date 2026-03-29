import SwiftUI
import WatchKit

struct PRDetailView: View {
    let owner: String
    let repo: String
    let prNumber: Int

    @State private var pr: PullRequestDetailModel?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showCommentSheet = false
    @State private var showMergeConfirm = false
    @State private var reviewEvent: String?
    @State private var actionMessage: String?
    @State private var showAssigneePicker = false
    @State private var showReviewerPicker = false
    @State private var collaborators: [PRUserModel] = []
    @State private var isLoadingCollaborators = false

    var body: some View {
        Group {
            if isLoading && pr == nil {
                ProgressView().tint(GitHubColors.green)
            } else if let pr {
                ScrollView {
                    VStack(alignment: .leading, spacing: GitHubSpacing.md) {
                        headerSection(pr)

                        diffStatsSection(pr)

                        if !pr.checks.isEmpty {
                            checksSection(pr.checks)
                        }

                        if !pr.files.isEmpty {
                            filesSection(pr.files)
                        }

                        if !pr.comments.isEmpty {
                            commentsSection(pr.comments)
                        }

                        assigneesSection(pr.assignees)

                        reviewersSection(pr.reviewers)

                        if let msg = actionMessage {
                            Text(msg)
                                .font(GitHubTypography.caption)
                                .foregroundStyle(GitHubColors.green)
                                .transition(.opacity)
                        }

                        if pr.isOpen {
                            actionsSection(pr)
                        }
                    }
                    .padding(GitHubSpacing.sm)
                }
            } else if let error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(GitHubColors.red)
                    Text(error)
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.textMuted)
                }
            }
        }
        .background(GitHubColors.background)
        .navigationTitle("PR #\(prNumber)")
        .sheet(isPresented: $showCommentSheet) {
            PRCommentSheet(
                event: reviewEvent ?? "COMMENT",
                owner: owner,
                repo: repo,
                prNumber: prNumber,
                isPresented: $showCommentSheet,
                onSubmitted: {
                    actionMessage = "Review submitted"
                    Task { await loadPR() }
                }
            )
        }
        .confirmationDialog("Merge this PR?", isPresented: $showMergeConfirm, titleVisibility: .visible) {
            Button("Squash & Merge") { Task { await mergePR(method: "squash") } }
            Button("Create Merge Commit") { Task { await mergePR(method: "merge") } }
            Button("Rebase & Merge") { Task { await mergePR(method: "rebase") } }
        }
        .sheet(isPresented: $showAssigneePicker) {
            UserPickerSheet(
                title: "Add Assignee",
                collaborators: collaborators,
                isLoading: isLoadingCollaborators,
                showCopilot: false,
                onSelect: { login in Task { await addAssigneeAction(login) } },
                isPresented: $showAssigneePicker
            )
        }
        .sheet(isPresented: $showReviewerPicker) {
            UserPickerSheet(
                title: "Request Review",
                collaborators: collaborators,
                isLoading: isLoadingCollaborators,
                showCopilot: true,
                onSelect: { login in Task { await requestReviewerAction(login) } },
                isPresented: $showReviewerPicker
            )
        }
        .task { await startPolling() }
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerSection(_ pr: PullRequestDetailModel) -> some View {
        VStack(alignment: .leading, spacing: GitHubSpacing.xs) {
            HStack {
                Text(pr.title)
                    .font(GitHubTypography.headline)
                    .foregroundStyle(GitHubColors.text)
                    .lineLimit(3)
                Spacer()
                prStateBadge(pr)
            }

            Text(pr.author)
                .font(GitHubTypography.caption)
                .foregroundStyle(GitHubColors.textMuted)

            HStack(spacing: GitHubSpacing.xs) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10))
                    .foregroundStyle(GitHubColors.blue)
                Text("\(pr.branch) → \(pr.baseBranch)")
                    .font(GitHubTypography.caption)
                    .foregroundStyle(GitHubColors.blue)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func diffStatsSection(_ pr: PullRequestDetailModel) -> some View {
        HStack(spacing: GitHubSpacing.md) {
            Text("+\(pr.additions)")
                .font(GitHubTypography.terminal)
                .foregroundStyle(GitHubColors.green)
            Text("-\(pr.deletions)")
                .font(GitHubTypography.terminal)
                .foregroundStyle(GitHubColors.red)
            Text("\(pr.changedFiles) files")
                .font(GitHubTypography.caption)
                .foregroundStyle(GitHubColors.textMuted)
        }
        .padding(GitHubSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(GitHubColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func checksSection(_ checks: [CheckRunModel]) -> some View {
        VStack(alignment: .leading, spacing: GitHubSpacing.xs) {
            Text("CI/CD Checks")
                .font(GitHubTypography.caption)
                .foregroundStyle(GitHubColors.textMuted)

            ForEach(checks) { check in
                HStack(spacing: GitHubSpacing.sm) {
                    Image(systemName: checkIcon(check))
                        .font(.system(size: 12))
                        .foregroundStyle(checkColor(check))
                    Text(check.name)
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.text)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func filesSection(_ files: [PRFileModel]) -> some View {
        VStack(alignment: .leading, spacing: GitHubSpacing.xs) {
            Text("Files")
                .font(GitHubTypography.caption)
                .foregroundStyle(GitHubColors.textMuted)

            ForEach(files) { file in
                HStack(spacing: GitHubSpacing.sm) {
                    Image(systemName: file.statusIcon)
                        .font(.system(size: 10))
                        .foregroundStyle(GitHubColors.blue)
                    Text(file.filename.split(separator: "/").last.map(String.init) ?? file.filename)
                        .font(GitHubTypography.code)
                        .foregroundStyle(GitHubColors.text)
                        .lineLimit(1)
                    Spacer()
                    Text("+\(file.additions)")
                        .font(GitHubTypography.code)
                        .foregroundStyle(GitHubColors.green)
                    Text("-\(file.deletions)")
                        .font(GitHubTypography.code)
                        .foregroundStyle(GitHubColors.red)
                }
            }
        }
    }

    @ViewBuilder
    private func commentsSection(_ comments: [PRCommentModel]) -> some View {
        VStack(alignment: .leading, spacing: GitHubSpacing.sm) {
            Text("Comments (\(comments.count))")
                .font(GitHubTypography.caption)
                .foregroundStyle(GitHubColors.textMuted)

            ForEach(comments) { comment in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(comment.author)
                            .font(GitHubTypography.caption)
                            .foregroundStyle(GitHubColors.blue)
                        Spacer()
                    }
                    Text(comment.body)
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.text)
                        .lineLimit(4)
                }
                .padding(GitHubSpacing.sm)
                .background(GitHubColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private func actionsSection(_ pr: PullRequestDetailModel) -> some View {
        VStack(spacing: GitHubSpacing.sm) {
            Divider().background(GitHubColors.border)

            CopilotButton("Approve", icon: "hand.thumbsup.fill", style: .primary) {
                Task { await quickReview("APPROVE") }
            }

            CopilotButton("Comment", icon: "text.bubble", style: .secondary) {
                reviewEvent = "COMMENT"
                showCommentSheet = true
            }

            CopilotButton("Request Changes", icon: "exclamationmark.triangle", style: .danger) {
                reviewEvent = "REQUEST_CHANGES"
                showCommentSheet = true
            }

            if pr.mergeable == true {
                CopilotButton("Merge", icon: "arrow.triangle.merge", style: .primary) {
                    showMergeConfirm = true
                }
            }
        }
    }

    @ViewBuilder
    private func assigneesSection(_ assignees: [PRUserModel]) -> some View {
        VStack(alignment: .leading, spacing: GitHubSpacing.xs) {
            Text("Assignees")
                .font(GitHubTypography.caption)
                .foregroundStyle(GitHubColors.textMuted)

            if assignees.isEmpty {
                Text("No assignees")
                    .font(GitHubTypography.caption)
                    .foregroundStyle(GitHubColors.textSubtle)
            } else {
                ForEach(assignees) { user in
                    HStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(GitHubColors.blue)
                        Text(user.login)
                            .font(GitHubTypography.caption)
                            .foregroundStyle(GitHubColors.text)
                        Spacer()
                        if pr?.isOpen == true {
                            Button {
                                Task { await removeAssignee(user.login) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(GitHubColors.textSubtle)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if pr?.isOpen == true {
                Button {
                    Task { await loadCollaborators() }
                    showAssigneePicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                        Text("Add Assignee")
                            .font(GitHubTypography.caption)
                    }
                    .foregroundStyle(GitHubColors.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func reviewersSection(_ reviewers: [PRUserModel]) -> some View {
        VStack(alignment: .leading, spacing: GitHubSpacing.xs) {
            Text("Reviewers")
                .font(GitHubTypography.caption)
                .foregroundStyle(GitHubColors.textMuted)

            if reviewers.isEmpty {
                Text("No reviewers requested")
                    .font(GitHubTypography.caption)
                    .foregroundStyle(GitHubColors.textSubtle)
            } else {
                ForEach(reviewers) { user in
                    HStack {
                        Image(systemName: user.isCopilot ? "sparkles" : "person.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(user.isCopilot ? GitHubColors.purple : GitHubColors.blue)
                        Text(user.isCopilot ? "Copilot" : user.login)
                            .font(GitHubTypography.caption)
                            .foregroundStyle(GitHubColors.text)
                        Spacer()
                        if pr?.isOpen == true {
                            Button {
                                Task { await removeReviewerAction(user.login) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(GitHubColors.textSubtle)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if pr?.isOpen == true {
                Button {
                    Task { await loadCollaborators() }
                    showReviewerPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                        Text("Request Review")
                            .font(GitHubTypography.caption)
                    }
                    .foregroundStyle(GitHubColors.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func prStateBadge(_ pr: PullRequestDetailModel) -> some View {
        let (text, color): (String, Color) = {
            if pr.draft { return ("Draft", GitHubColors.yellow) }
            switch pr.state {
            case "merged": return ("Merged", GitHubColors.purple)
            case "closed": return ("Closed", GitHubColors.red)
            default: return ("Open", GitHubColors.green)
            }
        }()
        return Text(text)
            .font(GitHubTypography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, GitHubSpacing.xs)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func checkIcon(_ check: CheckRunModel) -> String {
        if check.isInProgress { return "clock" }
        if check.isPassing { return "checkmark.circle.fill" }
        if check.isFailing { return "xmark.circle.fill" }
        return "circle"
    }

    private func checkColor(_ check: CheckRunModel) -> Color {
        if check.isInProgress { return GitHubColors.yellow }
        if check.isPassing { return GitHubColors.green }
        if check.isFailing { return GitHubColors.red }
        return GitHubColors.textMuted
    }

    // MARK: - Actions

    private func startPolling() async {
        while !Task.isCancelled {
            await loadPR()
            try? await Task.sleep(for: .seconds(10))
            if pr?.state != "open" { break }
        }
    }

    private func loadPR() async {
        do {
            pr = try await APIClient.shared.getPR(owner: owner, repo: repo, number: prNumber)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func quickReview(_ event: String) async {
        do {
            _ = try await APIClient.shared.submitReview(owner: owner, repo: repo, number: prNumber, event: event)
            WKInterfaceDevice.current().play(.success)
            actionMessage = event == "APPROVE" ? "Approved ✓" : "Review submitted"
            await loadPR()
        } catch {
            WKInterfaceDevice.current().play(.failure)
            actionMessage = "Failed: \(error.localizedDescription)"
        }
    }

    private func mergePR(method: String) async {
        do {
            _ = try await APIClient.shared.mergePR(owner: owner, repo: repo, number: prNumber, mergeMethod: method)
            WKInterfaceDevice.current().play(.success)
            actionMessage = "Merged ✓"
            await loadPR()
        } catch {
            WKInterfaceDevice.current().play(.failure)
            actionMessage = "Merge failed"
        }
    }

    private func loadCollaborators() async {
        isLoadingCollaborators = true
        do {
            let response = try await APIClient.shared.listCollaborators(owner: owner, repo: repo)
            collaborators = response.collaborators
        } catch {
            collaborators = []
        }
        isLoadingCollaborators = false
    }

    private func addAssigneeAction(_ login: String) async {
        do {
            _ = try await APIClient.shared.addAssignees(owner: owner, repo: repo, number: prNumber, assignees: [login])
            WKInterfaceDevice.current().play(.success)
            await loadPR()
        } catch {
            WKInterfaceDevice.current().play(.failure)
            actionMessage = "Failed to add assignee"
        }
    }

    private func removeAssignee(_ login: String) async {
        do {
            _ = try await APIClient.shared.removeAssignee(owner: owner, repo: repo, number: prNumber, login: login)
            WKInterfaceDevice.current().play(.click)
            await loadPR()
        } catch {
            WKInterfaceDevice.current().play(.failure)
        }
    }

    private func requestReviewerAction(_ login: String) async {
        do {
            _ = try await APIClient.shared.requestReviewers(owner: owner, repo: repo, number: prNumber, reviewers: [login])
            WKInterfaceDevice.current().play(.success)
            await loadPR()
        } catch {
            WKInterfaceDevice.current().play(.failure)
            actionMessage = "Failed to request reviewer"
        }
    }

    private func removeReviewerAction(_ login: String) async {
        do {
            _ = try await APIClient.shared.removeReviewer(owner: owner, repo: repo, number: prNumber, login: login)
            WKInterfaceDevice.current().play(.click)
            await loadPR()
        } catch {
            WKInterfaceDevice.current().play(.failure)
        }
    }
}

// MARK: - Comment Sheet

struct PRCommentSheet: View {
    let event: String
    let owner: String
    let repo: String
    let prNumber: Int
    @Binding var isPresented: Bool
    var onSubmitted: () -> Void

    @State private var comment = ""
    @State private var isSending = false

    var body: some View {
        VStack(spacing: GitHubSpacing.md) {
            Text(event == "REQUEST_CHANGES" ? "Request Changes" : "Add Comment")
                .font(GitHubTypography.headline)
                .foregroundStyle(GitHubColors.text)

            TextField("Comment...", text: $comment)
                .textFieldStyle(.plain)
                .padding(GitHubSpacing.sm)
                .background(GitHubColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            CopilotButton("Submit", icon: "paperplane.fill") {
                Task {
                    isSending = true
                    do {
                        _ = try await APIClient.shared.submitReview(
                            owner: owner, repo: repo, number: prNumber,
                            event: event, body: comment
                        )
                        WKInterfaceDevice.current().play(.success)
                        onSubmitted()
                        isPresented = false
                    } catch {
                        WKInterfaceDevice.current().play(.failure)
                    }
                    isSending = false
                }
            }
            .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .opacity(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
        }
        .padding(GitHubSpacing.sm)
        .background(GitHubColors.background)
    }
}

// MARK: - User Picker Sheet

struct UserPickerSheet: View {
    let title: String
    let collaborators: [PRUserModel]
    let isLoading: Bool
    let showCopilot: Bool
    let onSelect: (String) -> Void
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: GitHubSpacing.sm) {
                Text(title)
                    .font(GitHubTypography.headline)
                    .foregroundStyle(GitHubColors.text)

                if isLoading {
                    ProgressView().tint(GitHubColors.green)
                } else {
                    if showCopilot {
                        Button {
                            onSelect("copilot[bot]")
                            isPresented = false
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(GitHubColors.purple)
                                Text("Copilot (AI Review)")
                                    .font(GitHubTypography.caption)
                                    .foregroundStyle(GitHubColors.text)
                                Spacer()
                            }
                            .padding(GitHubSpacing.sm)
                            .background(GitHubColors.purple.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        Divider().background(GitHubColors.border)
                    }

                    ForEach(collaborators) { user in
                        Button {
                            onSelect(user.login)
                            isPresented = false
                        } label: {
                            HStack {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(GitHubColors.blue)
                                Text(user.login)
                                    .font(GitHubTypography.caption)
                                    .foregroundStyle(GitHubColors.text)
                                Spacer()
                            }
                            .padding(.vertical, GitHubSpacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(GitHubSpacing.sm)
        }
        .background(GitHubColors.background)
    }
}
