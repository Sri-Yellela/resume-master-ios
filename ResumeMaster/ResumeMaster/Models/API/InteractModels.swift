import Foundation

/// Echoes the RESOLVED job id and the values now stored, so a client reconciles against what the
/// server holds rather than against what it optimistically rendered.
struct InteractResponse: Decodable {
    let success: Bool?
    let jobId: String?
    let starred: Bool?
    let disliked: Bool?
}
