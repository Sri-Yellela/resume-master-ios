import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

/// `POST /api/auth/login`.
///
/// `authContext` here is SESSION-BOUND — its session_sid is the throwaway sid of this request. It
/// is NOT the credential to keep: filed under a browser session that does not exist, any browser
/// sign-out sweeping that sid would revoke it. Exchange it immediately and discard it.
struct LoginResponse: Decodable {
    let ok: Bool?
    let authContext: String
    let user: PublicUser?
}

struct PublicUser: Decodable, Equatable {
    let id: Int?
    let username: String?
    let email: String?
}

/// `GET /api/auth/mobile-token` — THE mobile auth step.
///
/// This token has session_sid NULL, so `revokeBrowserAuthContexts` never sweeps it and signing out
/// of a browser cannot silently kill the phone. Both windows are returned rather than documented,
/// so the app can show a real expiry instead of a hardcoded guess.
struct MobileTokenResponse: Decodable {
    let token: String
    /// Slides on every authenticated request, up to `absoluteSeconds` from issue.
    let idleSeconds: Double?
    let absoluteSeconds: Double?
}

struct AuthMeResponse: Decodable {
    let user: PublicUser?
}
