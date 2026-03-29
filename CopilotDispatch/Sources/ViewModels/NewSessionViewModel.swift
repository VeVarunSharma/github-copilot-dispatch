import Foundation
import SwiftUI

#if os(watchOS)
import WatchKit
#endif

@MainActor
@Observable
class NewSessionViewModel {
    var repositories: [RepositoryModel] = []
    var selectedRepo: RepositoryModel?
    var taskDescription: String = ""
    var isLoadingRepos = false
    var isLaunching = false
    var error: String?
    var createdSession: SessionModel?

    var canLaunch: Bool {
        selectedRepo != nil
            && !taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isLaunching
    }

    func loadRepositories() async {
        isLoadingRepos = true
        error = nil
        do {
            let response = try await APIClient.shared.listRepos()
            repositories = response.repositories
            if selectedRepo == nil {
                selectedRepo = repositories.first
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingRepos = false
    }

    func launchSession() async {
        guard let repo = selectedRepo else { return }

        isLaunching = true
        error = nil

        do {
            let session = try await APIClient.shared.createSession(
                repo: repo.fullName,
                prompt: taskDescription
            )
            createdSession = session
            #if os(watchOS)
            WKInterfaceDevice.current().play(.success)
            #endif
        } catch {
            self.error = error.localizedDescription
            #if os(watchOS)
            WKInterfaceDevice.current().play(.failure)
            #endif
        }
        isLaunching = false
    }
}
