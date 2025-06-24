import Foundation
import OmniChatKit
import OpenAPIRuntime
import OpenAPIURLSession

// Example showing how to use the generated OmniChat client

@main
struct SimpleExample {
    static func main() async throws {
        // Initialize the generated client
        let client = Client(
            serverURL: URL(string: "https://omnichat-7pu.pages.dev")!,
            transport: URLSessionTransport()
        )
        
        // Example 1: Apple Sign In
        do {
            let authResponse = try await client.appleSignIn(.init(
                body: .json(.init(
                    idToken: "your-apple-id-token"
                ))
            ))
            
            switch authResponse {
            case .ok(let response):
                let auth = try response.body.json
                print("Access token: \(auth.accessToken)")
                print("Refresh token: \(auth.refreshToken)")
            case .badRequest:
                print("Bad request")
            case .unauthorized:
                print("Unauthorized")
            case .internalServerError:
                print("Server error")
            case .undocumented(let statusCode, _):
                print("Unexpected status: \(statusCode)")
            }
        } catch {
            print("Auth error: \(error)")
        }
        
        // Example 2: Get models (using generated method name)
        let modelsResponse = try await client.get_sol_api_sol_models(.init())
        
        switch modelsResponse {
        case .ok(let response):
            let models = try response.body.json
            for (provider, modelList) in models.providers ?? [:] {
                print("\(provider):")
                for model in modelList {
                    print("  - \(model.name): \(model.id)")
                }
            }
        case .unauthorized:
            print("Need to authenticate first")
        case .internalServerError:
            print("Server error")
        case .undocumented(let statusCode, _):
            print("Unexpected status: \(statusCode)")
        }
        
        // Example 3: Create a conversation
        let conversationResponse = try await client.post_sol_api_sol_conversations(.init(
            body: .json(.init(
                title: "Test Conversation",
                model: "gpt-4o-mini"
            ))
        ))
        
        switch conversationResponse {
        case .ok(let response):
            let data = try response.body.json
            if let conversation = data.conversation {
                print("Created conversation: \(conversation.id) - \(conversation.title)")
            }
        case .badRequest:
            print("Invalid conversation data")
        case .unauthorized:
            print("Not authenticated")
        case .internalServerError:
            print("Server error")
        case .undocumented(let statusCode, _):
            print("Unexpected status: \(statusCode)")
        }
    }
}

// For a better developer experience, you might want to create a wrapper
// that provides more intuitive method names:

struct OmniChatAPI {
    let client: Client
    
    init(serverURL: URL = URL(string: "https://omnichat-7pu.pages.dev")!) {
        self.client = Client(
            serverURL: serverURL,
            transport: URLSessionTransport()
        )
    }
    
    func signInWithApple(idToken: String) async throws -> Components.Schemas.AuthResponse {
        let response = try await client.appleSignIn(.init(
            body: .json(.init(idToken: idToken))
        ))
        
        switch response {
        case .ok(let ok):
            return try ok.body.json
        case .badRequest:
            throw APIError.badRequest
        case .unauthorized:
            throw APIError.unauthorized
        case .internalServerError:
            throw APIError.serverError
        case .undocumented(let statusCode, _):
            throw APIError.unexpectedStatus(statusCode)
        }
    }
    
    func getModels() async throws -> Components.Schemas.ModelsResponse {
        let response = try await client.get_sol_api_sol_models(.init())
        
        switch response {
        case .ok(let ok):
            return try ok.body.json
        case .unauthorized:
            throw APIError.unauthorized
        case .internalServerError:
            throw APIError.serverError
        case .undocumented(let statusCode, _):
            throw APIError.unexpectedStatus(statusCode)
        }
    }
    
    enum APIError: Error {
        case badRequest
        case unauthorized
        case serverError
        case unexpectedStatus(Int)
    }
}