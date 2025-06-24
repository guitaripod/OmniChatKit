import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes

/// A minimal example client that shows how to use the generated code
public struct OmniChatClientMinimal {
    private let client: Client
    
    public init(
        serverURL: URL = URL(string: "https://omnichat-7pu.pages.dev")!,
        transport: (any ClientTransport)? = nil
    ) {
        self.client = Client(
            serverURL: serverURL,
            transport: transport ?? URLSessionTransport()
        )
    }
    
    /// Sign in with Apple
    public func signInWithApple(idToken: String) async throws -> Components.Schemas.AuthResponse {
        let response = try await client.appleSignIn(.init(
            body: .json(.init(idToken: idToken))
        ))
        
        switch response {
        case .ok(let ok):
            return try ok.body.json
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid request"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status: \(statusCode)"))
        }
    }
    
    /// Get available models
    public func getModels() async throws -> Components.Schemas.ModelsResponse {
        let response = try await client.get_sol_api_sol_models(.init())
        
        switch response {
        case .ok(let ok):
            return try ok.body.json
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status: \(statusCode)"))
        }
    }
    
    /// Create a conversation
    public func createConversation(title: String, model: String) async throws -> Components.Schemas.Conversation {
        let response = try await client.post_sol_api_sol_conversations(.init(
            body: .json(.init(
                title: title,
                model: model
            ))
        ))
        
        switch response {
        case .ok(let ok):
            let data = try ok.body.json
            guard let conversation = data.conversation else {
                throw OmniChatError.decoding(.missingData)
            }
            return conversation
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid conversation data"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status: \(statusCode)"))
        }
    }
}