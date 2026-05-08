import Foundation

// MARK: - PR User

struct PRUserModel: Codable, Identifiable, Sendable {
    let login: String
    let avatarUrl: String

    var id: String { login }
    var isCopilot: Bool { login.lowercased().contains("copilot") }
}

// MARK: - Pull Request

struct PullRequestModel: Codable, Identifiable, Sendable {
    let number: Int
    let title: String
    let author: String
    let branch: String
    let baseBranch: String
    let state: String  // "open", "closed", "merged"
    let additions: Int
    let deletions: Int
    let changedFiles: Int
    let ciStatus: String?  // "success", "failure", "pending", null
    let mergeable: Bool?
    let draft: Bool
    let assignees: [PRUserModel]
    let reviewers: [PRUserModel]
    let createdAt: String
    let updatedAt: String

    var id: Int { number }

    var isOpen: Bool { state == "open" }
    var isMerged: Bool { state == "merged" }

    var stateColor: String {
        switch state {
        case "open": return "green"
        case "merged": return "purple"
        case "closed": return "red"
        default: return "gray"
        }
    }
}

// MARK: - Pull Request Detail

struct PullRequestDetailModel: Codable, Identifiable, Sendable {
    let number: Int
    let title: String
    let author: String
    let branch: String
    let baseBranch: String
    let state: String
    let additions: Int
    let deletions: Int
    let changedFiles: Int
    let ciStatus: String?
    let mergeable: Bool?
    let draft: Bool
    let body: String?
    let assignees: [PRUserModel]
    let reviewers: [PRUserModel]
    let files: [PRFileModel]
    let checks: [CheckRunModel]
    let comments: [PRCommentModel]
    let createdAt: String
    let updatedAt: String

    var id: Int { number }
    var isOpen: Bool { state == "open" }
    var isMerged: Bool { state == "merged" }
}

// MARK: - PR File

struct PRFileModel: Codable, Identifiable, Sendable {
    let filename: String
    let status: String  // "added", "modified", "removed", "renamed"
    let additions: Int
    let deletions: Int

    var id: String { filename }

    var statusIcon: String {
        switch status {
        case "added": return "plus"
        case "removed": return "minus"
        case "renamed": return "arrow.right"
        default: return "pencil"
        }
    }
}

// MARK: - Check Run

struct CheckRunModel: Codable, Identifiable, Sendable {
    let name: String
    let status: String  // "queued", "in_progress", "completed"
    let conclusion: String?  // "success", "failure", "neutral", etc.

    var id: String { name }

    var isPassing: Bool { conclusion == "success" }
    var isFailing: Bool { conclusion == "failure" }
    var isInProgress: Bool { status == "in_progress" || status == "queued" }
}

// MARK: - PR Comment

struct PRCommentModel: Codable, Identifiable, Sendable {
    let id: Int
    let author: String
    let authorAvatarUrl: String
    let body: String
    let createdAt: String
}

// MARK: - Response Wrappers

struct PRListResponse: Codable, Sendable {
    let pullRequests: [PullRequestModel]
}

struct PRChecksResponse: Codable, Sendable {
    let state: String
    let checks: [CheckRunModel]
}

struct ReviewSubmittedResponse: Codable, Sendable {
    let status: String
    let event: String
}

struct MergeResponse: Codable, Sendable {
    let status: String
    let sha: String
}

struct CollaboratorsResponse: Codable, Sendable {
    let collaborators: [PRUserModel]
}

struct AssigneesUpdatedResponse: Codable, Sendable {
    let status: String
}

struct ReviewersRequestedResponse: Codable, Sendable {
    let status: String
}

struct AddAssigneesAPIRequest: Codable, Sendable {
    let assignees: [String]
}

struct RequestReviewersAPIRequest: Codable, Sendable {
    let reviewers: [String]
}
