import Foundation

struct CommunityUser: Decodable {
    let id: Int
    let username: String
    let isAdmin: Bool?
}

struct CommunitySession: Decodable {
    let username: String
    let expiresAt: String?
}

struct CommunityMeResponse: Decodable {
    let user: CommunityUser?
}

struct CommunityFeedResponse: Decodable {
    let posts: [CommunityPost]
}

struct CommunityPost: Decodable, Identifiable {
    let id: Int
    let username: String
    let caption: String?
    let species: String?
    let weightKg: Double?
    let lengthCm: Double?
    let catchLocation: String?
    let lure: String?
    let createdAt: String?
    let imageUrl: String
    var likeCount: Int
    var commentCount: Int
    var likedByMe: Bool
    let canDelete: Bool?

    var imageURL: URL? {
        if let url = URL(string: imageUrl), url.scheme != nil { return url }
        return URL(string: imageUrl, relativeTo: CommunityAPI.baseURL)?.absoluteURL
    }
}

struct CommunityCommentsResponse: Decodable {
    let comments: [CommunityComment]
}

struct CommunityComment: Decodable, Identifiable {
    let id: Int
    let username: String
    let body: String
    let createdAt: String?
    let canDelete: Bool?
}

struct CommunityLikeResponse: Decodable {
    let liked: Bool
    let likeCount: Int
}

private struct CommunityErrorResponse: Decodable {
    let error: String?
}

enum CommunityAPIError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Palvelin vastasi odottamattomasti."
        case .server(let message): return message
        }
    }
}

final class CommunityAPI {
    static let baseURL = URL(string: "https://api.fastfishin.com")!
    static let shared = CommunityAPI()

    // URLSession's cookie store keeps the API's HttpOnly ff_session cookie out of app code.
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpShouldSetCookies = true
        session = URLSession(configuration: configuration)
    }

    func currentUser() async throws -> CommunityUser? {
        let response: CommunityMeResponse = try await request(path: "/api/auth/me")
        return response.user
    }

    func login(username: String, password: String) async throws -> CommunitySession {
        try await jsonRequest(path: "/api/auth/login", body: ["username": username, "password": password])
    }

    func signup(username: String, password: String) async throws -> CommunitySession {
        try await jsonRequest(path: "/api/auth/signup", body: ["username": username, "password": password])
    }

    func logout() async throws {
        let _: LogoutResponse = try await jsonRequest(path: "/api/auth/logout", body: [:])
    }

    func feed(before: Int? = nil) async throws -> [CommunityPost] {
        var components = URLComponents(url: endpoint("/api/posts"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "limit", value: "30")]
        if let before { items.append(URLQueryItem(name: "before", value: String(before))) }
        components.queryItems = items
        let (data, response) = try await session.data(from: components.url!)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(CommunityFeedResponse.self, from: data).posts
    }

    func deletePost(postID: Int) async throws {
        let _: LogoutResponse = try await jsonRequest(path: "/api/posts/\(postID)/delete", body: [:])
    }

    func toggleLike(postID: Int) async throws -> CommunityLikeResponse {
        try await jsonRequest(path: "/api/posts/\(postID)/like", body: [:])
    }

    func comments(postID: Int) async throws -> [CommunityComment] {
        let response: CommunityCommentsResponse = try await request(path: "/api/posts/\(postID)/comments")
        return response.comments
    }

    func addComment(postID: Int, body: String) async throws -> CommunityComment {
        try await jsonRequest(path: "/api/posts/\(postID)/comments", body: ["body": body])
    }

    func publish(imageData: Data, caption: String, species: String? = nil,
                 weightKg: Double? = nil, lengthCm: Double? = nil, lure: String? = nil) async throws {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("/api/posts"))
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()

        func appendField(_ name: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }

        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"image\"; filename=\"catch.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(imageData)
        body.append(Data("\r\n".utf8))
        appendField("caption", caption)
        appendField("species", species)
        if let weightKg { appendField("weightKg", String(weightKg)) }
        if let lengthCm { appendField("lengthCm", String(lengthCm)) }
        appendField("lure", lure)
        body.append(Data("--\(boundary)--\r\n".utf8))
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, successCodes: [201])
    }

    private struct LogoutResponse: Decodable { let ok: Bool }

    private func endpoint(_ path: String) -> URL {
        URL(string: path, relativeTo: Self.baseURL)!.absoluteURL
    }

    private func request<T: Decodable>(path: String) async throws -> T {
        let (data, response) = try await session.data(from: endpoint(path))
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func jsonRequest<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, successCodes: [200, 201])
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data, successCodes: Set<Int> = [200]) throws {
        guard let http = response as? HTTPURLResponse else { throw CommunityAPIError.invalidResponse }
        guard successCodes.contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(CommunityErrorResponse.self, from: data).error)
                ?? "Pyyntö epäonnistui (\(http.statusCode))."
            throw CommunityAPIError.server(message)
        }
    }
}
