import ArgumentParser
import Foundation
import OmniChatKit
import Rainbow
import OpenAPIRuntime
import OpenAPIURLSession
import Files

struct Auth: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "🔐 Authentication management",
        subcommands: [
            Apple.self,
            Bearer.self,
            Clerk.self,
            ApiKey.self,
            Status.self,
            Logout.self,
            Refresh.self
        ]
    )
    
    struct Apple: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Sign in with Apple"
        )
        
        @Option(name: .shortAndLong, help: "Server URL")
        var server: String = "https://omnichat-7pu.pages.dev"
        
        @Flag(name: .shortAndLong, help: "Show raw response")
        var raw = false
        
        mutating func run() async throws {
            ConsoleOutput.printHeader("🍎 Sign in with Apple")
            
            let token = try await performOAuthFlow()
            
            let spinner = ConsoleOutput.startSpinner(message: "Authenticating with OmniChat...")
            defer { ConsoleOutput.stopSpinner(spinner) }
            
            let client = Client(
                serverURL: URL(string: server)!,
                transport: URLSessionTransport()
            )
            
            do {
                let response = try await client.appleSignIn(.init(
                    body: .json(.init(idToken: token))
                ))
                
                ConsoleOutput.stopSpinner(spinner)
                
                switch response {
                case .ok(let ok):
                    let authResponse = try ok.body.json
                    
                    if raw {
                        if let data = try? JSONEncoder().encode(authResponse) {
                            ConsoleOutput.printJSON(data)
                        }
                    } else {
                        ConsoleOutput.printSuccess("Authentication successful!")
                        ConsoleOutput.printKeyValue("Access Token", String(authResponse.accessToken.prefix(20)) + "...", color: .green)
                        ConsoleOutput.printKeyValue("Refresh Token", String(authResponse.refreshToken.prefix(20)) + "...", color: .blue)
                        ConsoleOutput.printKeyValue("Expires In", "\(authResponse.expiresIn) seconds", color: .yellow)
                        
                        let user = authResponse.user
                        ConsoleOutput.printSubheader("User Information")
                        if let id = user.id {
                            ConsoleOutput.printKeyValue("ID", id)
                        }
                        if let email = user.email {
                            ConsoleOutput.printKeyValue("Email", email)
                        }
                    }
                    
                    let expiresAt = Date().addingTimeInterval(TimeInterval(authResponse.expiresIn))
                    try AuthManager.shared.saveAuth(
                        type: .bearer(jwt: authResponse.accessToken),
                        refreshToken: authResponse.refreshToken,
                        expiresAt: expiresAt,
                        serverURL: server
                    )
                    
                case .badRequest:
                    ConsoleOutput.printError("Bad request - invalid ID token")
                    throw ExitCode.failure
                case .unauthorized:
                    ConsoleOutput.printError("Unauthorized")
                    throw ExitCode.failure
                case .internalServerError:
                    ConsoleOutput.printError("Server error")
                    throw ExitCode.failure
                case .undocumented(let statusCode, _):
                    ConsoleOutput.printError("Unexpected status: \(statusCode)")
                    throw ExitCode.failure
                }
                
            } catch {
                ConsoleOutput.stopSpinner(spinner)
                ConsoleOutput.printError("Authentication failed: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
        
        private func performOAuthFlow() async throws -> String {
            ConsoleOutput.printInfo("Opening your browser to sign in with Apple...")
            
            let port = 9876
            let callbackServer = OAuthCallbackServer(port: port)
            let oauth = AppleOAuthHandler(
                clientId: "com.omnichat.cli.service",
                redirectURI: "\(server)/apple-auth-callback"
            )
            
            let state = oauth.generateState()
            let nonce = oauth.generateNonce()
            
            guard let authURL = oauth.generateAuthorizationURL(state: state, nonce: nonce) else {
                throw OAuthError.serverError("Failed to generate authorization URL")
            }
            
            do {
                try await callbackServer.start()
                
                try BrowserOpener.open(url: authURL)
                
                ConsoleOutput.printInfo("Please complete sign in with Apple in your browser...")
                let token = try await callbackServer.waitForIdToken(timeout: 300)
                
                try await callbackServer.stop()
                ConsoleOutput.printSuccess("Successfully received authentication from Apple!")
                
                return token
            } catch {
                try? await callbackServer.stop()
                if case OAuthError.timeout = error {
                    ConsoleOutput.printError("Sign in timed out. Please try again.")
                }
                throw error
            }
        }
    }
    
    struct Bearer: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Authenticate with JWT bearer token"
        )
        
        @Option(name: .shortAndLong, help: "JWT token")
        var token: String
        
        @Option(name: .shortAndLong, help: "Server URL")
        var server: String = "https://omnichat-7pu.pages.dev"
        
        mutating func run() async throws {
            ConsoleOutput.printHeader("🔑 Bearer Token Authentication")
            
            try AuthManager.shared.saveAuth(
                type: .bearer(jwt: token),
                serverURL: server
            )
            
            ConsoleOutput.printSuccess("Bearer token saved successfully")
            ConsoleOutput.printInfo("Testing connection...")
            
            let client = try AuthManager.shared.getClient(serverURL: server)
            
            do {
                let response = try await client.get_sol_api_sol_v1_sol_user_sol_profile(.init())
                switch response {
                case .ok(let ok):
                    let user = try ok.body.json
                    ConsoleOutput.printSuccess("Connection successful!")
                    ConsoleOutput.printKeyValue("User ID", user.id)
                    ConsoleOutput.printKeyValue("Email", user.email)
                case .unauthorized:
                    ConsoleOutput.printWarning("Token is invalid or expired")
                default:
                    ConsoleOutput.printWarning("Could not verify token")
                }
            } catch {
                ConsoleOutput.printWarning("Could not verify token: \(error.localizedDescription)")
            }
        }
    }
    
    struct Clerk: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Authenticate with Clerk session token"
        )
        
        @Option(name: .shortAndLong, help: "Clerk session token")
        var token: String
        
        @Option(name: .shortAndLong, help: "Server URL")
        var server: String = "https://omnichat-7pu.pages.dev"
        
        mutating func run() async throws {
            ConsoleOutput.printHeader("🔐 Clerk Authentication")
            
            try AuthManager.shared.saveAuth(
                type: .clerk(token: token),
                serverURL: server
            )
            
            ConsoleOutput.printSuccess("Clerk token saved successfully")
        }
    }
    
    struct ApiKey: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Authenticate with API keys"
        )
        
        @Option(name: .shortAndLong, help: "API key header name")
        var header: String = "X-API-Key"
        
        @Option(name: .shortAndLong, help: "API key value")
        var key: String
        
        @Option(name: .shortAndLong, help: "Server URL")
        var server: String = "https://omnichat-7pu.pages.dev"
        
        mutating func run() async throws {
            ConsoleOutput.printHeader("🗝️ API Key Authentication")
            
            try AuthManager.shared.saveAuth(
                type: .apiKeys([header: key]),
                serverURL: server
            )
            
            ConsoleOutput.printSuccess("API key saved successfully")
        }
    }
    
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Check authentication status"
        )
        
        mutating func run() async throws {
            ConsoleOutput.printHeader("🔍 Authentication Status")
            
            guard let (auth, serverURL) = AuthManager.shared.loadAuth() else {
                ConsoleOutput.printWarning("Not authenticated")
                ConsoleOutput.printInfo("Run 'omnichat auth apple' or 'omnichat auth bearer' to authenticate")
                return
            }
            
            ConsoleOutput.printSuccess("Authenticated")
            ConsoleOutput.printKeyValue("Server", serverURL)
            
            switch auth {
            case .bearer:
                ConsoleOutput.printKeyValue("Type", "Bearer JWT", color: .green)
            case .clerk:
                ConsoleOutput.printKeyValue("Type", "Clerk Session", color: .blue)
            case .apiKeys(let keys):
                ConsoleOutput.printKeyValue("Type", "API Keys", color: .yellow)
                for (header, _) in keys {
                    ConsoleOutput.printKeyValue("Header", header)
                }
            }
            
            ConsoleOutput.printInfo("Testing connection...")
            
            do {
                let client = try AuthManager.shared.getClient()
                let response = try await client.get_sol_api_sol_v1_sol_user_sol_profile(.init())
                
                switch response {
                case .ok(let ok):
                    let user = try ok.body.json
                    ConsoleOutput.printSuccess("Connection successful!")
                    ConsoleOutput.printSubheader("User Information")
                    ConsoleOutput.printKeyValue("ID", user.id)
                    ConsoleOutput.printKeyValue("Email", user.email)
                    if let name = user.name {
                        ConsoleOutput.printKeyValue("Name", name)
                    }
                    ConsoleOutput.printKeyValue("Tier", user.tier.rawValue)
                    
                    if let battery = user.battery {
                        if let balance = battery.totalBalance {
                            ConsoleOutput.printKeyValue("Battery Balance", "\(balance)")
                        }
                    }
                case .unauthorized:
                    ConsoleOutput.printError("Authentication expired or invalid")
                default:
                    ConsoleOutput.printError("Connection failed")
                }
            } catch {
                ConsoleOutput.printError("Connection failed: \(error.localizedDescription)")
            }
        }
    }
    
    struct Logout: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Clear stored authentication"
        )
        
        mutating func run() async throws {
            ConsoleOutput.printHeader("👋 Logout")
            
            try AuthManager.shared.clearAuth()
            ConsoleOutput.printSuccess("Logged out successfully")
        }
    }
    
    struct Refresh: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Refresh authentication token"
        )
        
        mutating func run() async throws {
            ConsoleOutput.printHeader("🔄 Refresh Token")
            
            guard let (_, serverURL) = AuthManager.shared.loadAuth() else {
                ConsoleOutput.printError("Not authenticated")
                throw ExitCode.failure
            }
            
            ConsoleOutput.printInfo("Refreshing token...")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            guard let tokenFile = try? Files.Folder(path: NSHomeDirectory())
                .subfolder(at: ".omnichat-cli")
                .file(named: "token.json"),
                  let data = try? tokenFile.read(),
                  let stored = try? decoder.decode(AuthManager.StoredAuth.self, from: data),
                  let refreshToken = stored.refreshToken else {
                ConsoleOutput.printError("No refresh token available")
                throw ExitCode.failure
            }
            
            let client = Client(
                serverURL: URL(string: serverURL)!,
                transport: URLSessionTransport()
            )
            
            do {
                let response = try await client.refreshToken(.init(
                    body: .json(.init(refreshToken: refreshToken))
                ))
                
                switch response {
                case .ok(let ok):
                    let refreshResponse = try ok.body.json
                    
                    let expiresAt = Date().addingTimeInterval(TimeInterval(refreshResponse.expiresIn))
                    try AuthManager.shared.saveAuth(
                        type: .bearer(jwt: refreshResponse.accessToken),
                        refreshToken: refreshToken,  // Keep the same refresh token
                        expiresAt: expiresAt,
                        serverURL: serverURL
                    )
                    
                    ConsoleOutput.printSuccess("Token refreshed successfully")
                    ConsoleOutput.printKeyValue("New Expiry", "\(refreshResponse.expiresIn) seconds", color: .green)
                    
                case .badRequest:
                    ConsoleOutput.printError("Invalid refresh token")
                    throw ExitCode.failure
                case .unauthorized:
                    ConsoleOutput.printError("Refresh token expired")
                    throw ExitCode.failure
                default:
                    ConsoleOutput.printError("Failed to refresh token")
                    throw ExitCode.failure
                }
                
            } catch {
                ConsoleOutput.printError("Failed to refresh token: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
}