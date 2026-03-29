import Foundation
import SwiftUI

@MainActor
@Observable
class PRListViewModel {
    var repositories: [RepositoryModel] = []
    var selectedRepo: RepositoryModel?
    var pullRequests: [PullRequestModel] = []
    var isLoadingRepos = false
    var isLoadingPRs = false
    var error: String?

    private var pollTask: Task<Void, Never>?

    func loadRepositories() async {
        isLoadingRepos = true
        do {
            let response = try await APIClient.shared.listRepos()
            repositories = response.repositories
            if selectedRepo == nil {
                selectedRepo = repositories.first
            }
            if selectedRepo != nil {
                await loadPRs()
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingRepos = false
    }

    func loadPRs() async {
        guard let repo = selectedRepo else { return }
        isLoadingPRs = pullRequests.isEmpty
        error = nil
        do {
            let parts = repo.fullName.split(separator: "/")
            guard parts.count == 2 else { return }
            let response = try await APIClient.shared.listPRs(
                owner: String(parts[0]),
                repo: String(parts[1])
            )
            pullRequests = response.pullRequests
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingPRs = false
    }

    func selectRepo(_ repo: RepositoryModel) {
        selectedRepo = repo
        pullRequests = []
        startPolling()
    }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await loadPRs()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
