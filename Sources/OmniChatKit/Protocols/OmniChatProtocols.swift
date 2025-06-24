import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

public protocol OmniChatClientProtocol: Sendable {
    func appleSignIn(idToken: String, user: AppleAuthRequest.UserPayload?) async throws -> AuthResponse
    func refreshToken(refreshToken: String) async throws -> RefreshTokenResponse
    
    func chat(messages: [ChatMessage], model: String, conversationId: String, temperature: Double?, maxTokens: Int?, stream: Bool, webSearch: Bool?, imageGenerationOptions: ImageGenerationOptions?, userApiKeys: [String: String]?, ollamaBaseUrl: String?) async throws -> ChatResponse
    func chatStream(messages: [ChatMessage], model: String, conversationId: String, temperature: Double?, maxTokens: Int?, webSearch: Bool?, imageGenerationOptions: ImageGenerationOptions?, userApiKeys: [String: String]?, ollamaBaseUrl: String?) -> AsyncThrowingStream<String, Error>
    
    func getConversations() async throws -> [Conversation]
    func createConversation(title: String, model: String) async throws -> Conversation
    func deleteConversation(id: String) async throws -> Bool
    
    func getConversationMessages(conversationId: String) async throws -> [Message]
    func createMessage(conversationId: String, role: String, content: String, model: String?, parentId: String?) async throws -> Message
    
    func uploadFile(file: Data, fileName: String, conversationId: String, messageId: String) async throws -> UploadResponse
    func downloadFile(key: String) async throws -> Data
    
    func search(query: String, limit: Int?) async throws -> SearchResponse
    
    func getBatteryStatus() async throws -> BatteryStatus
    func getUserTier() async throws -> String
    
    func createCheckoutSession(type: String, planId: String?, isAnnual: Bool?, batteryUnits: Int?, returnUrl: String?) async throws -> CheckoutSessionResponse
    func getSubscriptionStatus() async throws -> SubscriptionStatus
    func createBillingPortalSession(returnUrl: String?) async throws -> String
    
    func getAvailableModels() async throws -> ModelsResponse
    
    func listConversationsV1() async throws -> [ConversationWithLastMessage]
    func createConversationV1(title: String, model: String?) async throws -> Conversation
    func getConversationV1(id: String) async throws -> Conversation
    func updateConversationV1(id: String, title: String?, isArchived: Bool?) async throws -> Conversation
    func deleteConversationV1(id: String) async throws -> Bool
    
    func getConversationMessagesV1(conversationId: String, limit: Int?, before: String?) async throws -> MessagesResponse
    func createMessageV1(conversationId: String, role: String, content: String, model: String?, parentId: String?) async throws -> Message
    
    func getUserProfileV1() async throws -> UserProfile
    func updateUserProfileV1(name: String?, imageUrl: String?) async throws -> UpdateProfileResponse
    func getUsageStatisticsV1(period: String?) async throws -> UsageStatistics
    
    func uploadFileV1(file: Data, fileName: String, conversationId: String, messageId: String) async throws -> UploadResponse
    func downloadFileV1(key: String) async throws -> Data
}

public protocol AuthenticationProviding: Sendable {
    func authenticationHeaders() async throws -> [String: String]
}

public protocol TokenRefreshing: Sendable {
    func refreshToken() async throws -> TokenResponse
}

public protocol RequestIntercepting: Sendable {
    func intercept(_ request: inout URLRequest) async throws
}

public protocol ResponseValidating: Sendable {
    func validate(_ response: HTTPURLResponse, data: Data) async throws
}

public protocol FileUploadProgressDelegate: AnyObject {
    func fileUploadProgress(_ progress: Double)
}

public struct TokenResponse: Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: Int
    public let tokenType: String
}

public struct ConversationWithLastMessage: Sendable {
    public let conversation: Conversation
    public let lastMessage: Message?
}

public struct MessagesResponse: Sendable {
    public let messages: [Message]
    public let hasMore: Bool
}

public struct UpdateProfileResponse: Sendable {
    public let id: String
    public let name: String?
    public let imageUrl: String?
    public let updatedAt: Date
}

public struct UsageStatistics: Sendable {
    public let period: String
    public let totalBatteryUsed: Double
    public let totalMessages: Int
    public let totalConversations: Int
    public let modelUsage: [String: ModelUsage]
    public let dailyUsage: [DailyUsage]
}

public struct ModelUsage: Sendable {
    public let messageCount: Int
    public let batteryUsed: Double
}

public struct DailyUsage: Sendable {
    public let date: Date
    public let batteryUsed: Double
    public let messageCount: Int
}