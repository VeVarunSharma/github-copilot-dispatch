import Foundation

// MARK: - Session Status

enum SessionStatus: String, Codable, Sendable {
    case pending
    case working
    case completed
    case failed
    case stalled

    var label: String {
        rawValue.capitalized
    }
}

// MARK: - Session

struct SessionModel: Codable, Identifiable, Sendable {
    let id: String
    let status: String
    let repo: String
    let prompt: String
    let model: String
    let events: [SessionEventModel]
    let pullRequestUrl: String?
    let createdAt: String
    let updatedAt: String

    var sessionStatus: SessionStatus {
        SessionStatus(rawValue: status) ?? .pending
    }
}

// MARK: - Session Event

struct SessionEventModel: Codable, Identifiable, Sendable {
    let index: Int
    let type: String
    let content: String
    let timestamp: String

    var id: Int { index }
}

// MARK: - Session Summary (list endpoint)

struct SessionSummaryModel: Codable, Identifiable, Sendable {
    let id: String
    let status: String
    let repo: String
    let prompt: String
    let model: String
    let eventCount: Int
    let createdAt: String
    let updatedAt: String

    var sessionStatus: SessionStatus {
        SessionStatus(rawValue: status) ?? .pending
    }
}
