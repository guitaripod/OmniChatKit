import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes
import OSLog
import Observation

@Observable
public final class OmniChatClient: OmniChatClientProtocol {
    private let underlyingClient: APIProtocol
    private let authManager: AuthenticationManager
    private let serverURL: URL
    private let logger = Logger(subsystem: "com.omnichat.kit", category: "OmniChatClient")
    private let session: URLSession
    
    public init(
        serverURL: URL = URL(string: "https://omnichat-7pu.pages.dev")!,
        authentication: AuthenticationType,
        urlSession: URLSession = .shared
    ) {
        self.serverURL = serverURL
        self.authManager = AuthenticationManager(authenticationType: authentication)
        self.session = urlSession
        
        let transport = URLSessionTransport(configuration: .init(session: urlSession))
        self.underlyingClient = Client(
            serverURL: serverURL,
            transport: transport
        )
    }
    
    public init(auth: AuthenticationType) {
        self.init(authentication: auth)
    }
    
    private func makeAuthenticatedClient() async throws -> Client {
        let headers = try await authManager.authenticationHeaders()
        let transport = URLSessionTransport(
            configuration: .init(
                session: session,
                httpHeadersProvider: { request in
                    var httpFields = HTTPFields()
                    for (key, value) in headers {
                        httpFields[HTTPField.Name(key)!] = value
                    }
                    return httpFields
                }
            )
        )
        return Client(serverURL: serverURL, transport: transport)
    }
    
    public func appleSignIn(idToken: String, user: AppleAuthRequest.UserPayload?) async throws -> AuthResponse {
        let client = try await makeAuthenticatedClient()
        let response = try await client.appleSignIn(body: .json(.init(
            idToken: idToken,
            user: user
        )))
        
        switch response {
        case .ok(let okResponse):
            let authResponse = try okResponse.body.json
            if let refreshToken = authResponse.refreshToken {
                await authManager.updateTokens(
                    accessToken: authResponse.accessToken,
                    refreshToken: refreshToken,
                    expiresIn: authResponse.expiresIn
                )
            }
            return authResponse
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid request"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func refreshToken(refreshToken: String) async throws -> RefreshTokenResponse {
        let client = try await makeAuthenticatedClient()
        let response = try await client.refreshToken(body: .json(.init(refreshToken: refreshToken)))
        
        switch response {
        case .ok(let okResponse):
            let tokenResponse = try okResponse.body.json
            await authManager.updateTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: refreshToken,
                expiresIn: tokenResponse.expiresIn
            )
            return tokenResponse
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid refresh token"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .notFound:
            throw OmniChatError.api(.notFound("Refresh token not found"))
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func chat(
        messages: [ChatMessage],
        model: String,
        conversationId: String,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        stream: Bool = false,
        webSearch: Bool? = nil,
        imageGenerationOptions: ImageGenerationOptions? = nil,
        userApiKeys: [String: String]? = nil,
        ollamaBaseUrl: String? = nil
    ) async throws -> ChatResponse {
        let client = try await makeAuthenticatedClient()
        
        let request = Components.Schemas.ChatRequest(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: stream,
            conversationId: conversationId,
            webSearch: webSearch,
            imageGenerationOptions: imageGenerationOptions,
            userApiKeys: userApiKeys,
            ollamaBaseUrl: ollamaBaseUrl.flatMap { URL(string: $0) }
        )
        
        let response = try await client.chatChat_post(body: .json(request))
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid chat request"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .paymentRequired(let paymentResponse):
            if case .json(let error) = try paymentResponse.body {
                throw OmniChatError.api(.paymentRequired(
                    currentBalance: error.currentBalance ?? 0,
                    estimatedCost: error.estimatedCost ?? 0
                ))
            }
            throw OmniChatError.api(.paymentRequired(currentBalance: 0, estimatedCost: 0))
        case .forbidden(let forbiddenResponse):
            if case .json(let error) = try forbiddenResponse.body {
                throw OmniChatError.api(.modelAccessDenied(
                    model: error.model ?? model,
                    provider: error.provider ?? "unknown"
                ))
            }
            throw OmniChatError.api(.forbidden("Access denied"))
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .serviceUnavailable:
            throw OmniChatError.api(.serviceUnavailable)
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func chatStream(
        messages: [ChatMessage],
        model: String,
        conversationId: String,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        webSearch: Bool? = nil,
        imageGenerationOptions: ImageGenerationOptions? = nil,
        userApiKeys: [String: String]? = nil,
        ollamaBaseUrl: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let headers = try await authManager.authenticationHeaders()
                    var request = URLRequest(url: serverURL.appendingPathComponent("/api/chat"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    
                    for (key, value) in headers {
                        request.setValue(value, forHTTPHeaderField: key)
                    }
                    
                    let chatRequest = Components.Schemas.ChatRequest(
                        messages: messages,
                        model: model,
                        temperature: temperature,
                        maxTokens: maxTokens,
                        stream: true,
                        conversationId: conversationId,
                        webSearch: webSearch,
                        imageGenerationOptions: imageGenerationOptions,
                        userApiKeys: userApiKeys,
                        ollamaBaseUrl: ollamaBaseUrl.flatMap { URL(string: $0) }
                    )
                    
                    let encoder = JSONEncoder()
                    request.httpBody = try encoder.encode(chatRequest)
                    
                    let streamingHandler = StreamingResponseHandler(continuation: continuation)
                    
                    let task = session.dataTask(with: request) { data, response, error in
                        Task {
                            if let error = error {
                                await streamingHandler.handleError(error)
                                return
                            }
                            
                            guard let httpResponse = response as? HTTPURLResponse else {
                                await streamingHandler.handleError(OmniChatError.network(.invalidURL))
                                return
                            }
                            
                            guard (200...299).contains(httpResponse.statusCode) else {
                                await streamingHandler.handleError(
                                    OmniChatError.api(.serverError("HTTP \(httpResponse.statusCode)"))
                                )
                                return
                            }
                            
                            if let data = data {
                                await streamingHandler.handleData(data)
                            }
                        }
                    }
                    
                    task.resume()
                    
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func getConversations() async throws -> [Conversation] {
        let client = try await makeAuthenticatedClient()
        let response = try await client.getConversations()
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json.conversations ?? []
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func createConversation(title: String, model: String) async throws -> Conversation {
        let client = try await makeAuthenticatedClient()
        let response = try await client.createConversation(
            body: .json(.init(title: title, model: model))
        )
        
        switch response {
        case .ok(let okResponse):
            guard let conversation = try okResponse.body.json.conversation else {
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
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func deleteConversation(id: String) async throws -> Bool {
        let client = try await makeAuthenticatedClient()
        let response = try await client.deleteConversation(path: .init(id: id))
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json.success ?? false
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .notFound:
            throw OmniChatError.api(.notFound("Conversation not found"))
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func getConversationMessages(conversationId: String) async throws -> [Message] {
        let client = try await makeAuthenticatedClient()
        let response = try await client.getConversationMessages(path: .init(id: conversationId))
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json.messages ?? []
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func createMessage(
        conversationId: String,
        role: String,
        content: String,
        model: String? = nil,
        parentId: String? = nil
    ) async throws -> Message {
        let client = try await makeAuthenticatedClient()
        let response = try await client.createMessage(
            path: .init(id: conversationId),
            body: .json(.init(
                role: .init(rawValue: role) ?? .user,
                content: content,
                model: model,
                parentId: parentId
            ))
        )
        
        switch response {
        case .ok(let okResponse):
            guard let message = try okResponse.body.json.message else {
                throw OmniChatError.decoding(.missingData)
            }
            return message
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid message data"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func uploadFile(
        file: Data,
        fileName: String,
        conversationId: String,
        messageId: String
    ) async throws -> UploadResponse {
        let client = try await makeAuthenticatedClient()
        
        let multipartBody = MultipartBody([
            .init(
                name: "file",
                filename: fileName,
                headerFields: HTTPFields(),
                content: .init(file)
            ),
            .init(
                name: "conversationId",
                filename: nil,
                headerFields: HTTPFields(),
                content: .init(conversationId.data(using: .utf8)!)
            ),
            .init(
                name: "messageId",
                filename: nil,
                headerFields: HTTPFields(),
                content: .init(messageId.data(using: .utf8)!)
            )
        ])
        
        let response = try await client.uploadFile(body: .multipartForm(multipartBody))
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid file upload"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func downloadFile(key: String) async throws -> Data {
        let client = try await makeAuthenticatedClient()
        let response = try await client.uploadFile_get(query: .init(key: key))
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.binary
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid file key"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .forbidden:
            throw OmniChatError.fileOperation(.accessDenied)
        case .notFound:
            throw OmniChatError.fileOperation(.fileNotFound)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func search(query: String, limit: Int? = 20) async throws -> SearchResponse {
        let client = try await makeAuthenticatedClient()
        let response = try await client.searchConversationsAndMessages(
            query: .init(q: query, limit: limit)
        )
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func getBatteryStatus() async throws -> BatteryStatus {
        let client = try await makeAuthenticatedClient()
        let response = try await client.getBatteryStatus()
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func getUserTier() async throws -> String {
        let client = try await makeAuthenticatedClient()
        let response = try await client.getUserTier()
        
        switch response {
        case .ok(let okResponse):
            guard let tier = try okResponse.body.json.tier else {
                throw OmniChatError.decoding(.missingData)
            }
            return tier.rawValue
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func createCheckoutSession(
        type: String,
        planId: String? = nil,
        isAnnual: Bool? = nil,
        batteryUnits: Int? = nil,
        returnUrl: String? = nil
    ) async throws -> CheckoutSessionResponse {
        let client = try await makeAuthenticatedClient()
        let response = try await client.createCheckoutSession(
            body: .json(.init(
                _type: .init(rawValue: type) ?? .subscription,
                planId: planId,
                isAnnual: isAnnual,
                batteryUnits: batteryUnits,
                returnUrl: returnUrl.flatMap { URL(string: $0) }
            ))
        )
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid checkout request"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func getSubscriptionStatus() async throws -> SubscriptionStatus {
        let client = try await makeAuthenticatedClient()
        let response = try await client.getSubscriptionStatus()
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func createBillingPortalSession(returnUrl: String? = nil) async throws -> String {
        let client = try await makeAuthenticatedClient()
        let response = try await client.createBillingPortalSession(
            body: returnUrl != nil ? .json(.init(returnUrl: URL(string: returnUrl!))) : nil
        )
        
        switch response {
        case .ok(let okResponse):
            guard let url = try okResponse.body.json.url else {
                throw OmniChatError.decoding(.missingData)
            }
            return url.absoluteString
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .notFound:
            throw OmniChatError.api(.notFound("Billing account not found"))
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .serviceUnavailable:
            throw OmniChatError.api(.serviceUnavailable)
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func getAvailableModels() async throws -> ModelsResponse {
        let client = try await makeAuthenticatedClient()
        let response = try await client.getAvailableModels()
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func listConversationsV1() async throws -> [ConversationWithLastMessage] {
        let client = try await makeAuthenticatedClient()
        let response = try await client.listConversationsV1()
        
        switch response {
        case .ok(let okResponse):
            let conversations = try okResponse.body.json.conversations ?? []
            return conversations.map { conv in
                ConversationWithLastMessage(
                    conversation: conv,
                    lastMessage: conv.lastMessage
                )
            }
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .tooManyRequests:
            throw OmniChatError.api(.rateLimitExceeded)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func createConversationV1(title: String, model: String? = "gpt-4o-mini") async throws -> Conversation {
        let client = try await makeAuthenticatedClient()
        let response = try await client.createConversationV1(
            body: .json(.init(title: title, model: model))
        )
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid conversation data"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .tooManyRequests:
            throw OmniChatError.api(.rateLimitExceeded)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func getConversationV1(id: String) async throws -> Conversation {
        let client = try await makeAuthenticatedClient()
        let response = try await client.getConversationV1(path: .init(id: id))
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .notFound:
            throw OmniChatError.api(.notFound("Conversation not found"))
        case .tooManyRequests:
            throw OmniChatError.api(.rateLimitExceeded)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func updateConversationV1(
        id: String,
        title: String? = nil,
        isArchived: Bool? = nil
    ) async throws -> Conversation {
        let client = try await makeAuthenticatedClient()
        let response = try await client.updateConversationV1(
            path: .init(id: id),
            body: .json(.init(title: title, isArchived: isArchived))
        )
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid update data"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .notFound:
            throw OmniChatError.api(.notFound("Conversation not found"))
        case .tooManyRequests:
            throw OmniChatError.api(.rateLimitExceeded)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func deleteConversationV1(id: String) async throws -> Bool {
        let client = try await makeAuthenticatedClient()
        let response = try await client.deleteConversationV1(path: .init(id: id))
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json.success ?? false
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .notFound:
            throw OmniChatError.api(.notFound("Conversation not found"))
        case .tooManyRequests:
            throw OmniChatError.api(.rateLimitExceeded)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func getConversationMessagesV1(
        conversationId: String,
        limit: Int? = 50,
        before: String? = nil
    ) async throws -> MessagesResponse {
        let client = try await makeAuthenticatedClient()
        let response = try await client.getConversationMessagesV1(
            path: .init(id: conversationId),
            query: .init(limit: limit, before: before)
        )
        
        switch response {
        case .ok(let okResponse):
            let body = try okResponse.body.json
            return MessagesResponse(
                messages: body.messages ?? [],
                hasMore: body.hasMore ?? false
            )
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .notFound:
            throw OmniChatError.api(.notFound("Conversation not found"))
        case .tooManyRequests:
            throw OmniChatError.api(.rateLimitExceeded)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func createMessageV1(
        conversationId: String,
        role: String,
        content: String,
        model: String? = nil,
        parentId: String? = nil
    ) async throws -> Message {
        let client = try await makeAuthenticatedClient()
        let response = try await client.createMessageV1(
            path: .init(id: conversationId),
            body: .json(.init(
                role: .init(rawValue: role) ?? .user,
                content: content,
                model: model,
                parentId: parentId
            ))
        )
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid message data"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .notFound:
            throw OmniChatError.api(.notFound("Conversation not found"))
        case .tooManyRequests:
            throw OmniChatError.api(.rateLimitExceeded)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func getUserProfileV1() async throws -> UserProfile {
        let client = try await makeAuthenticatedClient()
        let response = try await client.getUserProfileV1()
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .notFound:
            throw OmniChatError.api(.notFound("User profile not found"))
        case .tooManyRequests:
            throw OmniChatError.api(.rateLimitExceeded)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func updateUserProfileV1(name: String? = nil, imageUrl: String? = nil) async throws -> UpdateProfileResponse {
        let client = try await makeAuthenticatedClient()
        let response = try await client.updateUserProfileV1(
            body: .json(.init(
                name: name,
                imageUrl: imageUrl.flatMap { URL(string: $0) }
            ))
        )
        
        switch response {
        case .ok(let okResponse):
            let body = try okResponse.body.json
            return UpdateProfileResponse(
                id: body.id!,
                name: body.name,
                imageUrl: body.imageUrl,
                updatedAt: body.updatedAt!
            )
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid profile data"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .tooManyRequests:
            throw OmniChatError.api(.rateLimitExceeded)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func getUsageStatisticsV1(period: String? = "week") async throws -> UsageStatistics {
        let client = try await makeAuthenticatedClient()
        let response = try await client.getUsageStatisticsV1(
            query: .init(period: period.flatMap { .init(rawValue: $0) })
        )
        
        switch response {
        case .ok(let okResponse):
            let body = try okResponse.body.json
            return UsageStatistics(
                period: body.period ?? "week",
                totalBatteryUsed: body.totalBatteryUsed ?? 0,
                totalMessages: body.totalMessages ?? 0,
                totalConversations: body.totalConversations ?? 0,
                modelUsage: (body.modelUsage ?? [:]).mapValues { modelData in
                    ModelUsage(
                        messageCount: modelData.messageCount ?? 0,
                        batteryUsed: modelData.batteryUsed ?? 0
                    )
                },
                dailyUsage: (body.dailyUsage ?? []).map { daily in
                    DailyUsage(
                        date: daily.date!,
                        batteryUsed: daily.batteryUsed ?? 0,
                        messageCount: daily.messageCount ?? 0
                    )
                }
            )
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .tooManyRequests:
            throw OmniChatError.api(.rateLimitExceeded)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func uploadFileV1(
        file: Data,
        fileName: String,
        conversationId: String,
        messageId: String
    ) async throws -> UploadResponse {
        let client = try await makeAuthenticatedClient()
        
        let multipartBody = MultipartBody([
            .init(
                name: "file",
                filename: fileName,
                headerFields: HTTPFields(),
                content: .init(file)
            ),
            .init(
                name: "conversationId",
                filename: nil,
                headerFields: HTTPFields(),
                content: .init(conversationId.data(using: .utf8)!)
            ),
            .init(
                name: "messageId",
                filename: nil,
                headerFields: HTTPFields(),
                content: .init(messageId.data(using: .utf8)!)
            )
        ])
        
        let response = try await client.uploadFileV1(body: .multipartForm(multipartBody))
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.json
        case .badRequest:
            throw OmniChatError.api(.badRequest("Invalid file upload"))
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .payloadTooLarge:
            throw OmniChatError.validation(.invalidFileSize(maxSize: 10 * 1024 * 1024))
        case .tooManyRequests:
            throw OmniChatError.api(.rateLimitExceeded)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
    
    public func downloadFileV1(key: String) async throws -> Data {
        let client = try await makeAuthenticatedClient()
        let response = try await client.downloadFileV1(path: .init(key: key))
        
        switch response {
        case .ok(let okResponse):
            return try okResponse.body.binary
        case .unauthorized:
            throw OmniChatError.api(.unauthorized)
        case .forbidden:
            throw OmniChatError.fileOperation(.accessDenied)
        case .notFound:
            throw OmniChatError.fileOperation(.fileNotFound)
        case .tooManyRequests:
            throw OmniChatError.api(.rateLimitExceeded)
        case .internalServerError:
            throw OmniChatError.api(.serverError("Internal server error"))
        case .undocumented(let statusCode, _):
            throw OmniChatError.api(.serverError("Unexpected status code: \(statusCode)"))
        }
    }
}