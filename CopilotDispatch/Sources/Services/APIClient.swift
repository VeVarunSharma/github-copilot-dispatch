import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .unauthorized: return "Authentication required"
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
        case .decodingError(let err): return "Decoding error: \(err.localizedDescription)"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    var baseURL: String = AppEnvironment.current.baseURL
    var authToken: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
    }

    func setBaseURL(_ url: String) {
        self.baseURL = url
    }

    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    // MARK: - Auth Endpoints

    func requestDeviceCode() async throws -> DeviceCodeResponse {
        return try await post("/auth/device-code")
    }

    func pollToken(deviceCode: String) async throws -> TokenPollResult {
        let body = PollTokenRequest(deviceCode: deviceCode)
        let (data, response) = try await rawRequest(.post, path: "/auth/poll-token", body: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 200 {
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            return .success(tokenResponse)
        } else if httpResponse.statusCode == 202 {
            return .pending
        } else {
            let errorBody = try? decoder.decode(ErrorBody.self, from: data)
            throw APIError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorBody?.message ?? "Unknown error"
            )
        }
    }

    func getUser() async throws -> GitHubUser {
        return try await get("/auth/user")
    }

    // MARK: - Session Endpoints

    func createSession(repo: String, prompt: String, model: String? = nil) async throws
        -> SessionModel
    {
        let body = CreateSessionRequest(repo: repo, prompt: prompt, model: model)
        return try await post("/sessions", body: body)
    }

    func listSessions(status: String? = nil, limit: Int = 20) async throws -> SessionListResponse {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let status { queryItems.append(URLQueryItem(name: "status", value: status)) }
        return try await get("/sessions", queryItems: queryItems)
    }

    func getSession(id: String, sinceEvent: Int? = nil) async throws -> SessionModel {
        var queryItems: [URLQueryItem] = []
        if let sinceEvent {
            queryItems.append(URLQueryItem(name: "sinceEvent", value: "\(sinceEvent)"))
        }
        return try await get("/sessions/\(id)", queryItems: queryItems)
    }

    func sendMessage(sessionId: String, message: String) async throws -> MessageSentResponse {
        let body = SendMessageRequest(message: message)
        return try await post("/sessions/\(sessionId)/send", body: body)
    }

    func cancelSession(id: String) async throws -> CancelSessionResponse {
        return try await delete("/sessions/\(id)")
    }

    // MARK: - Repo Endpoints

    func listRepos(sort: String = "updated", limit: Int = 30) async throws -> RepoListResponse {
        let queryItems = [
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        return try await get("/repos", queryItems: queryItems)
    }

    // MARK: - Pull Request Endpoints

    func listPRs(owner: String, repo: String, state: String = "open", limit: Int = 20) async throws -> PRListResponse {
        let queryItems = [
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        return try await get("/repos/\(owner)/\(repo)/pulls", queryItems: queryItems)
    }

    func getPR(owner: String, repo: String, number: Int) async throws -> PullRequestDetailModel {
        return try await get("/repos/\(owner)/\(repo)/pulls/\(number)")
    }

    func submitReview(owner: String, repo: String, number: Int, event: String, body: String? = nil) async throws -> ReviewSubmittedResponse {
        let requestBody = SubmitReviewAPIRequest(event: event, body: body)
        return try await post("/repos/\(owner)/\(repo)/pulls/\(number)/review", body: requestBody)
    }

    func mergePR(owner: String, repo: String, number: Int, mergeMethod: String = "squash") async throws -> MergeResponse {
        let requestBody = MergePRAPIRequest(mergeMethod: mergeMethod)
        return try await put("/repos/\(owner)/\(repo)/pulls/\(number)/merge", body: requestBody)
    }

    func getPRChecks(owner: String, repo: String, number: Int) async throws -> PRChecksResponse {
        return try await get("/repos/\(owner)/\(repo)/pulls/\(number)/checks")
    }

    // MARK: - Assignee & Reviewer Endpoints

    func addAssignees(owner: String, repo: String, number: Int, assignees: [String]) async throws -> AssigneesUpdatedResponse {
        let body = AddAssigneesAPIRequest(assignees: assignees)
        return try await post("/repos/\(owner)/\(repo)/pulls/\(number)/assignees", body: body)
    }

    func removeAssignee(owner: String, repo: String, number: Int, login: String) async throws -> AssigneesUpdatedResponse {
        return try await delete("/repos/\(owner)/\(repo)/pulls/\(number)/assignees/\(login)")
    }

    func requestReviewers(owner: String, repo: String, number: Int, reviewers: [String]) async throws -> ReviewersRequestedResponse {
        let body = RequestReviewersAPIRequest(reviewers: reviewers)
        return try await post("/repos/\(owner)/\(repo)/pulls/\(number)/reviewers", body: body)
    }

    func removeReviewer(owner: String, repo: String, number: Int, login: String) async throws -> ReviewersRequestedResponse {
        return try await delete("/repos/\(owner)/\(repo)/pulls/\(number)/reviewers/\(login)")
    }

    func listCollaborators(owner: String, repo: String) async throws -> CollaboratorsResponse {
        return try await get("/repos/\(owner)/\(repo)/collaborators")
    }

    // MARK: - HTTP Methods

    private func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws
        -> T
    {
        let (data, _) = try await rawRequest(.get, path: path, queryItems: queryItems)
        return try decodeResponse(data)
    }

    private func post<T: Decodable>(_ path: String) async throws -> T {
        let (data, _) = try await rawRequest(.post, path: path)
        return try decodeResponse(data)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let (data, _) = try await rawRequest(.post, path: path, body: body)
        return try decodeResponse(data)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        let (data, _) = try await rawRequest(.delete, path: path)
        return try decodeResponse(data)
    }

    private func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let (data, _) = try await rawRequest(.put, path: path, body: body)
        return try decodeResponse(data)
    }

    private func rawRequest<B: Encodable>(
        _ method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: B? = nil as String?
    ) async throws -> (Data, URLResponse) {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body, !(body is String) {
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 401
            {
                throw APIError.unauthorized
            }

            if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode >= 400
            {
                let errorBody = try? decoder.decode(ErrorBody.self, from: data)
                throw APIError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: errorBody?.message ?? "Unknown error"
                )
            }

            return (data, response)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
}

// MARK: - Request/Response Types

struct DeviceCodeResponse: Codable, Sendable {
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int
    let deviceCode: String
}

struct PollTokenRequest: Codable, Sendable {
    let deviceCode: String
}

struct TokenResponse: Codable, Sendable {
    let accessToken: String
    let tokenType: String
    let scope: String
}

enum TokenPollResult: Sendable {
    case success(TokenResponse)
    case pending
}

struct GitHubUser: Codable, Sendable {
    let login: String
    let name: String?
    let avatarUrl: String
}

struct CreateSessionRequest: Codable, Sendable {
    let repo: String
    let prompt: String
    let model: String?
}

struct SendMessageRequest: Codable, Sendable {
    let message: String
}

struct SessionListResponse: Codable, Sendable {
    let sessions: [SessionSummaryModel]
}

struct MessageSentResponse: Codable, Sendable {
    let status: String
}

struct CancelSessionResponse: Codable, Sendable {
    let id: String
    let status: String
}

struct RepoListResponse: Codable, Sendable {
    let repositories: [RepositoryModel]
}

struct ErrorBody: Codable, Sendable {
    let error: String
    let message: String
    let statusCode: Int
}

struct SubmitReviewAPIRequest: Codable, Sendable {
    let event: String
    let body: String?
}

struct MergePRAPIRequest: Codable, Sendable {
    let mergeMethod: String
}
