import XCTest
@testable import OmniChatKit
import OpenAPIRuntime
import HTTPTypes

final class OmniChatClientTests: XCTestCase {
    var client: OmniChatClient!
    var mockURLSession: URLSession!
    
    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        mockURLSession = URLSession(configuration: configuration)
        
        client = OmniChatClient(
            serverURL: URL(string: "https://test.omnichat.com")!,
            authentication: .bearer(jwt: "test-token"),
            urlSession: mockURLSession
        )
    }
    
    override func tearDown() {
        client = nil
        mockURLSession = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }
    
    func testAuthenticationHeaders() async throws {
        let authManager = AuthenticationManager(authenticationType: .bearer(jwt: "test-jwt-token"))
        let headers = try await authManager.authenticationHeaders()
        
        XCTAssertEqual(headers["Authorization"], "Bearer test-jwt-token")
    }
    
    func testClerkAuthentication() async throws {
        let authManager = AuthenticationManager(authenticationType: .clerk(token: "clerk-token"))
        let headers = try await authManager.authenticationHeaders()
        
        XCTAssertEqual(headers["Authorization"], "Bearer clerk-token")
    }
    
    func testAPIKeysAuthentication() async throws {
        let apiKeys = [
            "X-API-Key": "api-key-123",
            "X-Client-ID": "client-456"
        ]
        let authManager = AuthenticationManager(authenticationType: .apiKeys(apiKeys))
        let headers = try await authManager.authenticationHeaders()
        
        XCTAssertEqual(headers, apiKeys)
    }
    
    func testChatStreamParsing() async throws {
        let parser = SSEParser()
        let sseData = """
        event: message
        data: {"content": "Hello"}
        
        event: message
        data: {"content": " World"}
        
        data: [DONE]
        
        """.data(using: .utf8)!
        
        let events = try await parser.parseEvents(from: sseData)
        
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].data, "{\"content\": \"Hello\"}")
        XCTAssertEqual(events[1].data, "{\"content\": \" World\"}")
        XCTAssertEqual(events[2].data, "[DONE]")
    }
    
    func testErrorHandling() async {
        do {
            _ = try await client.getConversations()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is OmniChatError)
        }
    }
    
    func testFileUploadProgress() async {
        let progress = FileUploadProgress(totalBytes: 1000)
        
        XCTAssertEqual(progress.totalBytes, 1000)
        XCTAssertEqual(progress.uploadedBytes, 0)
        XCTAssertEqual(progress.fractionCompleted, 0)
        XCTAssertFalse(progress.isCompleted)
        
        progress.updateProgress(uploadedBytes: 500)
        XCTAssertEqual(progress.uploadedBytes, 500)
        XCTAssertEqual(progress.fractionCompleted, 0.5)
        
        progress.markCompleted()
        XCTAssertTrue(progress.isCompleted)
        XCTAssertEqual(progress.fractionCompleted, 1.0)
        XCTAssertEqual(progress.uploadedBytes, 1000)
    }
    
    func testFileDownloadProgress() async {
        let progress = FileDownloadProgress(totalBytes: 2000)
        
        XCTAssertEqual(progress.totalBytes, 2000)
        XCTAssertEqual(progress.downloadedBytes, 0)
        XCTAssertEqual(progress.fractionCompleted, 0)
        XCTAssertFalse(progress.isCompleted)
        
        progress.updateProgress(downloadedBytes: 1000)
        XCTAssertEqual(progress.downloadedBytes, 1000)
        XCTAssertEqual(progress.fractionCompleted, 0.5)
        
        let testData = "Test data".data(using: .utf8)!
        progress.markCompleted(with: testData)
        XCTAssertTrue(progress.isCompleted)
        XCTAssertEqual(progress.fractionCompleted, 1.0)
        XCTAssertEqual(progress.data, testData)
    }
    
    func testAsyncSequenceExtensions() async throws {
        let stream = AsyncThrowingStream<String> { continuation in
            continuation.yield("Hello")
            continuation.yield(" ")
            continuation.yield("World")
            continuation.finish()
        }
        
        let collected = try await stream.collectToString()
        XCTAssertEqual(collected, "Hello World")
        
        let stream2 = AsyncThrowingStream<String> { continuation in
            continuation.yield("One")
            continuation.yield("Two")
            continuation.yield("Three")
            continuation.finish()
        }
        
        let array = try await stream2.collectToArray()
        XCTAssertEqual(array, ["One", "Two", "Three"])
    }
    
    func testAllEndpointsAvailable() {
        let requiredMethods: [String] = [
            "appleSignIn",
            "refreshToken",
            "chat",
            "chatStream",
            "getConversations",
            "createConversation",
            "deleteConversation",
            "getConversationMessages",
            "createMessage",
            "uploadFile",
            "downloadFile",
            "search",
            "getBatteryStatus",
            "getUserTier",
            "createCheckoutSession",
            "getSubscriptionStatus",
            "createBillingPortalSession",
            "getAvailableModels",
            "listConversationsV1",
            "createConversationV1",
            "getConversationV1",
            "updateConversationV1",
            "deleteConversationV1",
            "getConversationMessagesV1",
            "createMessageV1",
            "getUserProfileV1",
            "updateUserProfileV1",
            "getUsageStatisticsV1",
            "uploadFileV1",
            "downloadFileV1"
        ]
        
        let clientMirror = Mirror(reflecting: client!)
        let clientType = type(of: client!)
        
        for methodName in requiredMethods {
            let selector = Selector(methodName)
            XCTAssertTrue(
                clientType.instancesRespond(to: selector) ||
                clientMirror.children.contains { $0.label == methodName },
                "Method \(methodName) not found in OmniChatClient"
            )
        }
    }
}

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: OmniChatError.network(.connectionFailed))
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}