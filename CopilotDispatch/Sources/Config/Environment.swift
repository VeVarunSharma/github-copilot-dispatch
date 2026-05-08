import Foundation

enum AppEnvironment: String {
    case local
    case staging
    case production

    var baseURL: String {
        switch self {
        case .local:
            return "http://localhost:3001/api"
        case .staging:
            return "https://copilot-dispatch-staging.azurewebsites.net/api"
        case .production:
            return "https://copilot-dispatch-prod.azurewebsites.net/api"
        }
    }

    static var current: AppEnvironment {
        #if DEBUG
        return .staging
        #else
        return .production
        #endif
    }
}
