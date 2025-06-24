import XCTest
@testable import OmniChatKit

final class OmniChatClientMinimalTests: XCTestCase {
    func testClientInitialization() {
        let client = OmniChatClientMinimal()
        XCTAssertNotNil(client)
    }
    
    func testCustomServerURL() {
        let customURL = URL(string: "https://custom.omnichat.com")!
        let client = OmniChatClientMinimal(serverURL: customURL)
        XCTAssertNotNil(client)
    }
    
    func testErrorTypes() {
        let authError = OmniChatError.authentication(.missingToken)
        XCTAssertEqual(authError.errorDescription, "Authentication token is missing")
        
        let apiError = OmniChatError.api(.unauthorized)
        XCTAssertEqual(apiError.errorDescription, "Unauthorized")
        
        let networkError = OmniChatError.network(.timeout)
        XCTAssertEqual(networkError.errorDescription, "Request timed out")
    }
    
    func testAuthenticationTypes() {
        let clerkAuth = AuthenticationType.clerk(token: "test-token")
        let bearerAuth = AuthenticationType.bearer(jwt: "test-jwt")
        let apiKeysAuth = AuthenticationType.apiKeys(["X-API-Key": "test-key"])
        
        XCTAssertNotNil(clerkAuth)
        XCTAssertNotNil(bearerAuth)
        XCTAssertNotNil(apiKeysAuth)
    }
}