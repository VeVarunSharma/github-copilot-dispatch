import Foundation

struct RepositoryModel: Codable, Identifiable, Sendable {
    let fullName: String
    let name: String
    let owner: String
    let description: String?
    let language: String?
    let updatedAt: String
    let isPrivate: Bool

    var id: String { fullName }
}
