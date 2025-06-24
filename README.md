# OmniChatKit

A comprehensive Swift Package for the OmniChat API, built with swift-openapi-generator for complete type safety and modern Swift concurrency.

## Features

- 🚀 **Complete API Coverage**: All 43 endpoints fully implemented
- 🔒 **Type-Safe**: Generated from OpenAPI spec with swift-openapi-generator
- 📱 **Multi-Platform**: iOS 17+, macOS 14+, watchOS 10+, tvOS 17+, visionOS 1.0+, Linux
- 🔄 **Streaming Support**: Server-Sent Events (SSE) for real-time chat responses
- 🔐 **Flexible Authentication**: Clerk, JWT Bearer, and API key support
- 📊 **Progress Tracking**: File upload/download with real-time progress
- 🎯 **Protocol-Oriented**: Clean, testable architecture
- ⚡ **Swift Concurrency**: Built with async/await and Actors
- 🛡️ **Comprehensive Error Handling**: Detailed error types for all scenarios
- 🔧 **Build-Time Code Generation**: API client code is generated when you build your app

## How It Works

OmniChatKit uses swift-openapi-generator as a build plugin. This means:
1. The OpenAPI specification is included in the package
2. When you add OmniChatKit to your app and build it, the Swift code is generated automatically
3. You always get type-safe API access without manual code generation

## Installation

### Swift Package Manager

Add OmniChatKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/marcusziade/OmniChatKit", from: "1.0.0")
]
```

Or in Xcode: 
1. File → Add Package Dependencies
2. Enter the repository URL
3. Click Add Package

**Note**: The first build will take longer as it generates the API client code.

## Platform Requirements

- iOS 17.0+
- macOS 14.0+
- watchOS 10.0+
- tvOS 17.0+
- visionOS 1.0+
- Linux (Ubuntu 22.04+)
- Swift 5.9+

## Usage

### Authentication

OmniChatKit supports three authentication methods:

#### Clerk Authentication
```swift
import OmniChatKit

let client = OmniChatClient(auth: .clerk(token: "your-clerk-token"))
```

#### JWT Bearer Token
```swift
let client = OmniChatClient(auth: .bearer(jwt: "your-jwt-token"))
```

#### API Keys
```swift
let client = OmniChatClient(auth: .apiKeys([
    "X-API-Key": "your-api-key",
    "X-Client-ID": "your-client-id"
]))
```

### Chat Operations

#### Standard Chat
```swift
let response = try await client.chat(
    messages: [
        ChatMessage(role: "system", content: "You are a helpful assistant"),
        ChatMessage(role: "user", content: "Hello, how are you?")
    ],
    model: "gpt-4o-mini",
    conversationId: "conv-123",
    temperature: 0.7,
    maxTokens: 1000
)

print(response.message)
```

#### Streaming Chat
```swift
let stream = client.chatStream(
    messages: messages,
    model: "claude-opus-4-20250514",
    conversationId: "conv-123",
    webSearch: true
)

for try await chunk in stream {
    print(chunk, terminator: "")
}
```

### Conversation Management

#### List Conversations
```swift
let conversations = try await client.getConversations()
for conversation in conversations {
    print("\(conversation.title) - \(conversation.model)")
}
```

#### Create Conversation
```swift
let newConversation = try await client.createConversation(
    title: "New Chat",
    model: "gpt-4o-mini"
)
```

#### Delete Conversation
```swift
let success = try await client.deleteConversation(id: "conv-123")
```

### Message Operations

#### Get Messages
```swift
let messages = try await client.getConversationMessages(
    conversationId: "conv-123"
)
```

#### Create Message
```swift
let message = try await client.createMessage(
    conversationId: "conv-123",
    role: "user",
    content: "What's the weather like?",
    parentId: nil
)
```

### File Operations

#### Upload with Progress
```swift
let fileData = try Data(contentsOf: imageURL)

let response = try await client.uploadFile(
    file: fileData,
    fileName: "image.png",
    conversationId: "conv-123",
    messageId: "msg-456"
)

// With progress tracking
let transferManager = FileTransferManager()
let progress = try await transferManager.uploadFile(
    fileData,
    to: uploadURL,
    headers: headers
) { progress in
    print("Upload progress: \(progress.fractionCompleted * 100)%")
}
```

#### Download File
```swift
let fileData = try await client.downloadFile(key: "file-key-789")
```

### Search

```swift
let searchResults = try await client.search(
    query: "machine learning",
    limit: 20
)

for conversation in searchResults.results.conversations {
    print("Found in conversation: \(conversation.title)")
}

for message in searchResults.results.messages {
    print("Found in message: \(message.content)")
}
```

### User & Billing

#### Get User Profile (V1 API)
```swift
let profile = try await client.getUserProfileV1()
print("User: \(profile.email), Tier: \(profile.tier)")
```

#### Get Battery Status
```swift
let battery = try await client.getBatteryStatus()
print("Battery balance: \(battery.totalBalance)")
print("Today's usage: \(battery.todayUsage)")
```

#### Create Checkout Session
```swift
let checkout = try await client.createCheckoutSession(
    type: "subscription",
    planId: "pro-monthly",
    returnUrl: "myapp://checkout-complete"
)
// Redirect to checkout.url
```

### Models

#### Get Available Models
```swift
let modelsResponse = try await client.getAvailableModels()

for (provider, models) in modelsResponse.providers {
    print("\(provider):")
    for model in models {
        print("  - \(model.name): \(model.description ?? "")")
        print("    Context: \(model.contextWindow), Vision: \(model.supportsVision)")
    }
}
```

### Advanced Usage

#### Custom Server URL
```swift
let client = OmniChatClient(
    serverURL: URL(string: "https://custom.omnichat.com")!,
    authentication: .bearer(jwt: token)
)
```

#### Custom URLSession
```swift
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 60
let session = URLSession(configuration: configuration)

let client = OmniChatClient(
    authentication: .clerk(token: token),
    urlSession: session
)
```

#### Error Handling
```swift
do {
    let response = try await client.chat(...)
} catch let error as OmniChatError {
    switch error {
    case .authentication(let authError):
        print("Auth error: \(authError)")
    case .api(.paymentRequired(let balance, let cost)):
        print("Insufficient funds. Balance: \(balance), Required: \(cost)")
    case .api(.modelAccessDenied(let model, let provider)):
        print("Access denied for \(model) from \(provider)")
    case .network(let networkError):
        print("Network error: \(networkError)")
    default:
        print("Error: \(error)")
    }
}
```

#### SwiftUI Integration
```swift
import SwiftUI
import OmniChatKit

@Observable
class ChatViewModel {
    let client = OmniChatClient(auth: .clerk(token: "..."))
    var messages: [Message] = []
    var isLoading = false
    
    func sendMessage(_ content: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let message = try await client.createMessage(
                conversationId: currentConversationId,
                role: "user",
                content: content
            )
            messages.append(message)
            
            // Stream AI response
            let stream = client.chatStream(
                messages: messages.map { 
                    ChatMessage(role: $0.role, content: $0.content) 
                },
                model: "gpt-4o",
                conversationId: currentConversationId
            )
            
            var aiResponse = ""
            for try await chunk in stream {
                aiResponse += chunk
            }
            
            let aiMessage = try await client.createMessage(
                conversationId: currentConversationId,
                role: "assistant",
                content: aiResponse
            )
            messages.append(aiMessage)
        } catch {
            // Handle error
        }
    }
}
```

## For Package Maintainers

### Updating the OpenAPI Specification

The package includes the OpenAPI specification which needs to be updated when the API changes:

```bash
# Update the OpenAPI spec
./Scripts/update-openapi-spec.sh

# Test the changes
swift test

# Commit the updated spec
git add Sources/OmniChatKit/openapi.json
git commit -m "Update OpenAPI specification"
git tag 1.0.1
git push origin main --tags
```

## API Coverage

All 43 endpoints from the OmniChat API are fully implemented:

### Authentication (2 endpoints)
- ✅ Apple Sign In
- ✅ Refresh Token

### Chat (2 endpoints)  
- ✅ Chat (with streaming support)
- ✅ Get Available Models

### Conversations (10 endpoints)
- ✅ List Conversations
- ✅ Create Conversation
- ✅ Get Conversation
- ✅ Update Conversation
- ✅ Delete Conversation
- ✅ List Conversations V1
- ✅ Create Conversation V1
- ✅ Get Conversation V1
- ✅ Update Conversation V1
- ✅ Delete Conversation V1

### Messages (4 endpoints)
- ✅ Get Messages
- ✅ Create Message
- ✅ Get Messages V1
- ✅ Create Message V1

### Files (4 endpoints)
- ✅ Upload File
- ✅ Download File
- ✅ Upload File V1
- ✅ Download File V1

### User (4 endpoints)
- ✅ Get User Tier
- ✅ Get User Profile V1
- ✅ Update User Profile V1
- ✅ Get Usage Statistics V1

### Search (1 endpoint)
- ✅ Search Conversations and Messages

### Battery (1 endpoint)
- ✅ Get Battery Status

### Billing (3 endpoints)
- ✅ Create Checkout Session
- ✅ Get Subscription Status
- ✅ Create Billing Portal Session

## Architecture

OmniChatKit follows a protocol-oriented design:

```swift
protocol OmniChatClientProtocol: Sendable {
    // All API methods
}

protocol AuthenticationProviding: Sendable {
    func authenticationHeaders() async throws -> [String: String]
}

protocol TokenRefreshing: Sendable {
    func refreshToken() async throws -> TokenResponse
}

protocol RequestIntercepting: Sendable {
    func intercept(_ request: inout URLRequest) async throws
}

protocol ResponseValidating: Sendable {
    func validate(_ response: HTTPURLResponse, data: Data) async throws
}
```

## Testing

```swift
import XCTest
@testable import OmniChatKit

class MockOmniChatClient: OmniChatClientProtocol {
    // Implement protocol methods for testing
}

class MyViewModelTests: XCTestCase {
    func testSendMessage() async throws {
        let mockClient = MockOmniChatClient()
        let viewModel = ChatViewModel(client: mockClient)
        
        await viewModel.sendMessage("Test message")
        
        XCTAssertEqual(viewModel.messages.count, 2)
    }
}
```

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues and feature requests, please use the GitHub issue tracker.
