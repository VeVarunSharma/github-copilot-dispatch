import SwiftUI

@main
struct CopilotDispatchApp: App {
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    HomeView(onSignOut: {
                        Task { await authViewModel.signOut() }
                    })
                } else {
                    AuthView(viewModel: authViewModel)
                }
            }
            .task {
                await authViewModel.checkExistingAuth()
            }
        }
    }
}
