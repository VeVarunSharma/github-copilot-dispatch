import Foundation
import SwiftUI

@MainActor
@Observable
class SessionsViewModel {
    var sessions: [SessionSummaryModel] = []
    var isLoading = false
    var error: String?

    private var pollTask: Task<Void, Never>?

    func loadSessions() async {
        isLoading = sessions.isEmpty
        error = nil
        do {
            let response = try await APIClient.shared.listSessions()
            sessions = response.sessions
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await loadSessions()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func cancelSession(id: String) async {
        do {
            _ = try await APIClient.shared.cancelSession(id: id)
            await loadSessions()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
