import Foundation

/// Sign-in, and the durable mobile credential.
///
/// Two steps, not one. `POST /api/auth/login` returns `authContext`, which is session-bound to the
/// throwaway sid of that request — keeping it would file the phone's credential under a browser
/// session that does not exist, and any browser sign-out sweeping that sid would silently revoke
/// it. So it is exchanged immediately at `GET /api/auth/mobile-token` for a token whose session_sid
/// is NULL, and the authContext is discarded.
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    enum State: Equatable {
        case unknown        // launch, before the stored credential has been checked
        case signedOut
        case signedIn(PublicUser?)
    }

    @Published private(set) var state: State = .unknown
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private let client = APIClient.shared

    private init() {}

    var isSignedIn: Bool { if case .signedIn = state { return true }; return false }

    /// Called once at launch. Installs the 401 handler and adopts a stored token if one is valid.
    func restore() async {
        await client.setUnauthorizedHandler { [weak self] in
            await self?.handleUnauthorized()
        }

        guard KeychainTokenStore.shared.read() != nil else {
            state = .signedOut
            return
        }

        // A stored token is not proof of a live session — it may have passed its idle or absolute
        // window. One cheap authenticated call settles it before the feed starts making requests.
        do {
            let me = try await client.get("/api/auth/me", as: AuthMeResponse.self)
            state = .signedIn(me.user)
        } catch APIError.unauthorized {
            KeychainTokenStore.shared.clear()
            state = .signedOut
        } catch {
            // A transport failure is not a signed-out user. Trust the stored token and let the
            // first real request decide; signing someone out because a tunnel dropped is worse.
            state = .signedIn(nil)
        }
    }

    func signIn(username: String, password: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let login = try await client.post(
                "/api/auth/login",
                body: LoginRequest(username: username, password: password),
                as: LoginResponse.self)

            // Exchange immediately. The authContext is used for exactly this one call and is
            // never written to the Keychain.
            KeychainTokenStore.shared.save(login.authContext)
            let minted = try await client.get("/api/auth/mobile-token", as: MobileTokenResponse.self)
            KeychainTokenStore.shared.save(minted.token)

            state = .signedIn(login.user)
        } catch let error as APIError {
            KeychainTokenStore.shared.clear()
            errorMessage = error == .unauthorized
                ? "That username and password did not match."
                : error.userMessage
            state = .signedOut
        } catch {
            KeychainTokenStore.shared.clear()
            errorMessage = "Could not sign in. Please try again."
            state = .signedOut
        }
    }

    func signOut() async {
        // Best effort: the local credential is cleared whether or not the server call lands, so a
        // sign-out on a flaky connection still leaves nothing behind on the device.
        _ = try? await client.post("/api/auth/logout", body: [String: String](), as: EmptyResponse.self)
        KeychainTokenStore.shared.clear()
        state = .signedOut
    }

    private func handleUnauthorized() async {
        KeychainTokenStore.shared.clear()
        state = .signedOut
        errorMessage = "Your session expired. Please sign in again."
    }
}

/// For endpoints whose body carries nothing this client needs.
struct EmptyResponse: Decodable {
    init(from decoder: Decoder) throws {}
}
