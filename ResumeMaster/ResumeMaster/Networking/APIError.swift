import Foundation

/// The failures this API actually produces, kept distinct because the UI must react differently
/// to each. Flattening them into one "request failed" is how a daily cap becomes a mystery.
enum APIError: Error, Equatable {
    /// 401. Also what an expired or revoked token produces — the contract is explicit that a
    /// client must read this as "sign in again" rather than as a transient error.
    case unauthorized

    /// 409 from POST /api/apply/runs: the queue cap. Carries the real numbers so the UI can say
    /// what is left instead of just refusing.
    case queueCapReached(queuedLast24h: Int, limit: Int, remaining: Int, message: String)

    /// 409 from approve/reject: the rows are no longer awaiting a decision. Usually another
    /// device got there first, so the correct response is to re-fetch, not to show an error.
    case noApprovableJobs(message: String)

    /// 400 `cursor_sort_mismatch` / `cursor_malformed`. The cursor belongs to a different
    /// ordering; the feed must start over rather than render an arbitrary slice.
    case cursorInvalid(code: String)

    /// 503 from readiness. A STATE, not a failure — render it, do not retry it in a loop.
    case unavailable(reason: String)

    /// 410. A retired endpoint. If this ever fires, this client is calling something the server
    /// removed and the contract copy in Contract/ is stale.
    case retired(path: String, message: String)

    case http(status: Int, message: String)
    case decoding(String)
    case transport(String)

    var userMessage: String {
        switch self {
        case .unauthorized:
            return "Your session expired. Please sign in again."
        case .queueCapReached(let used, let limit, _, let message):
            return message.isEmpty ? "Daily queue limit reached: \(used) of \(limit) in the last 24h." : message
        case .noApprovableJobs:
            return "Those applications are no longer awaiting a decision."
        case .cursorInvalid:
            return "The job feed changed. Pull to refresh."
        case .unavailable(let reason):
            return reason.isEmpty ? "Auto-apply is unavailable right now." : reason
        case .retired(let path, _):
            return "This app called a removed endpoint (\(path)). Update required."
        case .http(let status, let message):
            return message.isEmpty ? "Request failed (\(status))." : message
        case .decoding:
            return "The server sent something this version of the app does not understand."
        case .transport:
            return "Could not reach Resume Master. Check your connection."
        }
    }
}
