import Foundation
import AuthenticationServices
import UIKit

/*
 * LinkedIn OIDC Profile Import - iOS
 * Uses ASWebAuthenticationSession (native, secure, sandboxed browser)
 * Scopes: openid profile email
 * Endpoint: https://api.linkedin.com/v2/userinfo (OIDC standard)
 *
 * This service does NOT store the access token.
 * It fetches name + email, maps to resume fields, discards the token.
 */

struct LinkedInUserInfo: Codable {
  let sub: String
  let name: String
  let given_name: String
  let family_name: String
  let email: String
  let picture: String?
}

struct LinkedInResumeFields {
  let name: String
  let email: String
  let photoURL: URL?
}

@MainActor
class LinkedInAuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

  static let shared = LinkedInAuthService()

  private let resumeMasterBaseURL = APIConfig.baseURL.absoluteString
  // For local dev: "http://localhost:3000"

  @Published var isImporting = false
  @Published var importError: String?

  func startImport(completion: @escaping (LinkedInResumeFields?) -> Void) {
    guard let authURL = URL(string: "\(resumeMasterBaseURL)/auth/linkedin?source=ios") else { return }

    // Must match CFBundleURLSchemes in Info.plist, or the session never returns.
    let callbackScheme = "draft"

    isImporting = true
    importError = nil

    let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
      Task { @MainActor in
        self?.isImporting = false

        if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
          completion(nil)
          return
        }

        guard let callbackURL = callbackURL,
              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
          self?.importError = "LinkedIn import failed. Please try again."
          completion(nil)
          return
        }

        let params = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
          guard let value = item.value else { return nil }
          return (item.name, value)
        })

        if params["linkedin_import"] == "success",
           let dataParam = params["data"],
           let jsonData = Data(base64URLEncoded: dataParam) {
          do {
            let fields = try JSONDecoder().decode([String: String].self, from: jsonData)
            let resumeFields = LinkedInResumeFields(
              name: fields["name"] ?? "",
              email: fields["email"] ?? "",
              photoURL: fields["photoUrl"].flatMap(URL.init)
            )
            completion(resumeFields)
          } catch {
            self?.importError = "Could not read LinkedIn data."
            completion(nil)
          }
        } else if params["linkedin_import"] == "denied" {
          completion(nil)
        } else {
          self?.importError = "LinkedIn import failed. Please try again."
          completion(nil)
        }
      }
    }

    session.presentationContextProvider = self
    session.prefersEphemeralWebBrowserSession = false
    session.start()
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?.windows.first { $0.isKeyWindow }
      ?? ASPresentationAnchor()
  }
}

private extension Data {
  init?(base64URLEncoded input: String) {
    var base64 = input.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let padding = 4 - base64.count % 4
    if padding < 4 { base64 += String(repeating: "=", count: padding) }
    self.init(base64Encoded: base64)
  }
}
