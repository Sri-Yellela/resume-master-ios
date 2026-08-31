import Foundation

/// One place that knows how to talk to the API: it attaches the bearer credential, maps status
/// codes onto `APIError`, and decodes. Every service goes through it so that "am I authenticated"
/// and "what does a 409 mean here" are each answered once.
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()

    /// Set by AuthService when a 401 comes back, so the UI can present sign-in. An actor cannot
    /// hand out a Published property, so the signal is a callback the app installs once.
    private var onUnauthorized: (@Sendable () async -> Void)?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func setUnauthorizedHandler(_ handler: @escaping @Sendable () async -> Void) {
        onUnauthorized = handler
    }

    // MARK: - Requests

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        try await send(request(path, method: "GET", query: query), as: type)
    }

    func post<Body: Encodable, T: Decodable>(
        _ path: String, body: Body, as type: T.Type, idempotencyKey: String? = nil
    ) async throws -> T {
        var req = request(path, method: "POST")
        req.httpBody = try JSONEncoder().encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey {
            // Without this a retry on a flaky connection queues the run twice — and every queued
            // job costs a resume generation.
            req.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        return try await send(req, as: type)
    }

    func patch<Body: Encodable, T: Decodable>(_ path: String, body: Body, as type: T.Type) async throws -> T {
        var req = request(path, method: "PATCH")
        req.httpBody = try JSONEncoder().encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(req, as: type)
    }

    private func request(_ path: String, method: String, query: [URLQueryItem] = []) -> URLRequest {
        var components = URLComponents(
            url: APIConfig.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }

        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = KeychainTokenStore.shared.read() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    // MARK: - Response handling

    private func send<T: Decodable>(_ req: URLRequest, as type: T.Type) async throws -> T {
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Malformed response.")
        }

        if (200..<300).contains(http.statusCode) {
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding("\(type): \(error)")
            }
        }

        throw mapFailure(status: http.statusCode, path: req.url?.path ?? "", data: data)
    }

    /// The error envelope is `{error, message}`, plus endpoint-specific numbers on the cap 409.
    private func mapFailure(status: Int, path: String, data: Data) -> APIError {
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let code    = body["error"]   as? String ?? ""
        let message = body["message"] as? String ?? ""

        switch status {
        case 401:
            Task { await onUnauthorized?() }
            return .unauthorized

        case 400 where code.hasPrefix("cursor_"):
            return .cursorInvalid(code: code)

        case 409 where body["limit"] != nil:
            return .queueCapReached(
                queuedLast24h: body["queuedLast24h"] as? Int ?? 0,
                limit:         body["limit"] as? Int ?? 0,
                remaining:     body["remaining"] as? Int ?? 0,
                message:       message)

        case 409:
            return .noApprovableJobs(message: message)

        case 410:
            return .retired(path: path, message: message)

        case 503:
            return .unavailable(reason: message)

        default:
            return .http(status: status, message: message)
        }
    }
}
