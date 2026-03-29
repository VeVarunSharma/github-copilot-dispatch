import Foundation
import SwiftUI

@MainActor
@Observable
class AuthViewModel {
    var userCode: String = ""
    var verificationUri: String = ""
    var isLoading = false
    var isPolling = false
    var error: String?
    var isAuthenticated = false

    private var deviceCode: String = ""
    private var pollInterval: Int = 5
    private var pollTask: Task<Void, Never>?

    func startDeviceCodeFlow() async {
        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.requestDeviceCode()
            userCode = response.userCode
            verificationUri = response.verificationUri
            deviceCode = response.deviceCode
            pollInterval = response.interval
            isLoading = false

            startPolling()
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func startPolling() {
        isPolling = true
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled && !isAuthenticated {
                try? await Task.sleep(for: .seconds(pollInterval))
                if Task.isCancelled { break }

                do {
                    let result = try await APIClient.shared.pollToken(deviceCode: deviceCode)
                    switch result {
                    case .success(let tokenResponse):
                        try? KeychainManager.shared.saveToken(tokenResponse.accessToken)
                        await APIClient.shared.setAuthToken(tokenResponse.accessToken)
                        isAuthenticated = true
                        isPolling = false
                        return
                    case .pending:
                        continue
                    }
                } catch {
                    if let apiError = error as? APIError,
                       case .serverError(let code, _) = apiError,
                       code == 410 {
                        self.error = "Code expired. Please try again."
                        isPolling = false
                        return
                    }
                }
            }
        }
    }

    func cancel() {
        pollTask?.cancel()
        isPolling = false
    }

    func checkExistingAuth() async {
        if let token = KeychainManager.shared.getToken() {
            await APIClient.shared.setAuthToken(token)
            do {
                _ = try await APIClient.shared.getUser()
                isAuthenticated = true
            } catch {
                try? KeychainManager.shared.deleteToken()
                await APIClient.shared.setAuthToken(nil)
            }
        }
    }

    func signOut() async {
        try? KeychainManager.shared.deleteToken()
        await APIClient.shared.setAuthToken(nil)
        isAuthenticated = false
        userCode = ""
        deviceCode = ""
    }
}
