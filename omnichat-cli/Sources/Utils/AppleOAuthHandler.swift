import Foundation
#if os(macOS)
import Security
#endif

struct AppleOAuthHandler {
    let clientId: String
    let redirectURI: String
    let scope: String
    
    init(clientId: String = "com.omnichat.cli.service",
         redirectURI: String = "https://omnichat-7pu.pages.dev/apple-auth-callback",
         scope: String = "email name") {
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.scope = scope
    }
    
    func generateAuthorizationURL(state: String, nonce: String) -> URL? {
        var components = URLComponents(string: "https://appleid.apple.com/auth/authorize")
        
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code id_token"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "response_mode", value: "form_post"),
        ]
        
        return components?.url
    }
    
    func generateState() -> String {
        return UUID().uuidString
    }
    
    func generateNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        #if os(macOS)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        #else
        for i in 0..<bytes.count {
            bytes[i] = UInt8.random(in: 0...255)
        }
        #endif
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    struct AuthorizationResponse {
        let code: String
        let idToken: String
        let state: String
    }
    
    func extractAuthorizationResponse(from url: URL) -> AuthorizationResponse? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        let queryItems = components.queryItems ?? []
        guard let code = queryItems.first(where: { $0.name == "code" })?.value,
              let idToken = queryItems.first(where: { $0.name == "id_token" })?.value,
              let state = queryItems.first(where: { $0.name == "state" })?.value else {
            return nil
        }
        
        return AuthorizationResponse(code: code, idToken: idToken, state: state)
    }
}