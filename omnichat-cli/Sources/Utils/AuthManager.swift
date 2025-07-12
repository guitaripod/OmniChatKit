import Foundation
import OmniChatKit
import Files
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes

class AuthManager {
    static let shared = AuthManager()
    
    private let configFolder: Folder
    private let tokenFile: File
    
    private init() {
        do {
            let homeFolder = try Folder(path: NSHomeDirectory())
            configFolder = try homeFolder.createSubfolderIfNeeded(at: ".omnichat-cli")
            
            if configFolder.containsFile(named: "token.json") {
                tokenFile = try configFolder.file(named: "token.json")
            } else {
                tokenFile = try configFolder.createFile(named: "token.json")
                try tokenFile.write("{}")
            }
        } catch {
            fatalError("Failed to initialize auth storage: \(error)")
        }
    }
    
    struct StoredAuth: Codable {
        let type: String
        let token: String?
        let apiKeys: [String: String]?
        let refreshToken: String?
        let expiresAt: Date?
        let serverURL: String
    }
    
    func saveAuth(type: AuthenticationType, refreshToken: String? = nil, expiresAt: Date? = nil, serverURL: String) throws {
        let stored: StoredAuth
        
        switch type {
        case .bearer(let jwt):
            stored = StoredAuth(
                type: "bearer",
                token: jwt,
                apiKeys: nil,
                refreshToken: refreshToken,
                expiresAt: expiresAt,
                serverURL: serverURL
            )
        case .clerk(let token):
            stored = StoredAuth(
                type: "clerk",
                token: token,
                apiKeys: nil,
                refreshToken: refreshToken,
                expiresAt: expiresAt,
                serverURL: serverURL
            )
        case .apiKeys(let keys):
            stored = StoredAuth(
                type: "apiKeys",
                token: nil,
                apiKeys: keys,
                refreshToken: nil,
                expiresAt: nil,
                serverURL: serverURL
            )
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(stored)
        try tokenFile.write(data)
        
        ConsoleOutput.printSuccess("Authentication saved successfully")
    }
    
    func loadAuth() -> (auth: AuthenticationType, serverURL: String)? {
        guard let data = try? tokenFile.read() else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let stored = try? decoder.decode(StoredAuth.self, from: data) else { return nil }
        
        if let expiresAt = stored.expiresAt, expiresAt < Date() {
            ConsoleOutput.printWarning("Stored token has expired")
            return nil
        }
        
        let auth: AuthenticationType
        switch stored.type {
        case "bearer":
            guard let token = stored.token else { return nil }
            auth = .bearer(jwt: token)
        case "clerk":
            guard let token = stored.token else { return nil }
            auth = .clerk(token: token)
        case "apiKeys":
            guard let keys = stored.apiKeys else { return nil }
            auth = .apiKeys(keys)
        default:
            return nil
        }
        
        return (auth, stored.serverURL)
    }
    
    func clearAuth() throws {
        try tokenFile.write("{}")
        ConsoleOutput.printSuccess("Authentication cleared")
    }
    
    func getClient(serverURL: String? = nil) throws -> Client {
        guard let (auth, savedURL) = loadAuth() else {
            throw CLIError.notAuthenticated
        }
        
        let url = serverURL ?? savedURL
        var middlewares: [ClientMiddleware] = []
        
        // Add authentication middleware based on type
        switch auth {
        case .bearer(let jwt):
            middlewares.append(AuthMiddleware(headerName: "Authorization", headerValue: "Bearer \(jwt)"))
        case .clerk(let token):
            middlewares.append(AuthMiddleware(headerName: "Authorization", headerValue: "Bearer \(token)"))
        case .apiKeys(let keys):
            for (header, value) in keys {
                middlewares.append(AuthMiddleware(headerName: header, headerValue: value))
            }
        }
        
        return Client(
            serverURL: URL(string: url)!,
            transport: URLSessionTransport(),
            middlewares: middlewares
        )
    }
}

enum CLIError: LocalizedError {
    case notAuthenticated
    case invalidInput
    case apiError(String)
    case fileNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please run 'omnichat auth' first."
        case .invalidInput:
            return "Invalid input provided"
        case .apiError(let message):
            return "API Error: \(message)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}

// MARK: - Authentication Middleware

struct AuthMiddleware: ClientMiddleware {
    let headerName: String
    let headerValue: String
    
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var modifiedRequest = request
        modifiedRequest.headerFields[HTTPField.Name(headerName)!] = headerValue
        return try await next(modifiedRequest, body, baseURL)
    }
}