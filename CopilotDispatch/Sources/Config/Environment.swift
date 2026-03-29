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
            return "https://b9b0-2607-fea8-531e-2000-648b-3bbe-cca4-d6ab.ngrok-free.app/api"
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
