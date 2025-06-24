import Foundation
import OmniChatKit

@main
struct BasicUsageExample {
    static func main() async throws {
        // Initialize client with Clerk authentication
        let client = OmniChatClient(auth: .clerk(token: ProcessInfo.processInfo.environment["CLERK_TOKEN"] ?? ""))
        
        print("OmniChat Client Example")
        print("======================\n")
        
        // Example 1: Get available models
        print("1. Fetching available models...")
        let models = try await client.getAvailableModels()
        
        for (provider, modelList) in models.providers {
            print("\n\(provider.uppercased()) Models:")
            for model in modelList {
                print("  - \(model.id): \(model.name)")
                if let description = model.description {
                    print("    \(description)")
                }
            }
        }
        
        // Example 2: Create a conversation
        print("\n2. Creating a new conversation...")
        let conversation = try await client.createConversation(
            title: "Test Conversation",
            model: "gpt-4o-mini"
        )
        print("Created conversation: \(conversation.id) - \(conversation.title)")
        
        // Example 3: Send a message
        print("\n3. Sending a message...")
        let userMessage = try await client.createMessage(
            conversationId: conversation.id,
            role: "user",
            content: "Hello! Can you explain what Swift concurrency is?"
        )
        print("User: \(userMessage.content)")
        
        // Example 4: Stream chat response
        print("\n4. Getting AI response (streaming)...")
        print("Assistant: ", terminator: "")
        
        let stream = client.chatStream(
            messages: [
                ChatMessage(role: "user", content: userMessage.content)
            ],
            model: conversation.model,
            conversationId: conversation.id
        )
        
        var fullResponse = ""
        for try await chunk in stream {
            print(chunk, terminator: "")
            fullResponse += chunk
        }
        print("\n")
        
        // Save the assistant's response
        let assistantMessage = try await client.createMessage(
            conversationId: conversation.id,
            role: "assistant",
            content: fullResponse,
            model: conversation.model
        )
        
        // Example 5: Search
        print("\n5. Searching for 'concurrency'...")
        let searchResults = try await client.search(query: "concurrency", limit: 5)
        
        if !searchResults.results.messages.isEmpty {
            print("Found \(searchResults.results.messages.count) messages")
        }
        
        // Example 6: Get battery status
        print("\n6. Checking battery status...")
        let battery = try await client.getBatteryStatus()
        print("Battery balance: \(battery.totalBalance)")
        print("Daily allowance: \(battery.dailyAllowance)")
        print("Today's usage: \(battery.todayUsage ?? 0)")
        
        // Example 7: List conversations
        print("\n7. Listing all conversations...")
        let conversations = try await client.getConversations()
        print("Total conversations: \(conversations.count)")
        
        for conv in conversations.prefix(5) {
            print("  - \(conv.title) (\(conv.model))")
        }
        
        print("\nExample completed successfully!")
    }
}

// Helper function to demonstrate file upload
func uploadFileExample(client: OmniChatClient, conversationId: String, messageId: String) async throws {
    let imageData = Data("Sample image data".utf8)
    
    let uploadResponse = try await client.uploadFile(
        file: imageData,
        fileName: "test-image.png",
        conversationId: conversationId,
        messageId: messageId
    )
    
    if uploadResponse.success {
        print("File uploaded successfully!")
        if let attachment = uploadResponse.attachment {
            print("File key: \(attachment.r2Key)")
            print("File size: \(attachment.fileSize) bytes")
        }
    }
}

// Helper function to demonstrate error handling
func demonstrateErrorHandling(client: OmniChatClient) async {
    do {
        // This might fail if the model requires payment
        _ = try await client.chat(
            messages: [
                ChatMessage(role: "user", content: "Hello")
            ],
            model: "gpt-4o",
            conversationId: "test-conv"
        )
    } catch let error as OmniChatError {
        switch error {
        case .api(.paymentRequired(let balance, let cost)):
            print("Insufficient battery! Balance: \(balance), Required: \(cost)")
        case .api(.modelAccessDenied(let model, let provider)):
            print("Access denied for model \(model) from \(provider)")
        case .authentication(let authError):
            print("Authentication error: \(authError)")
        default:
            print("Error: \(error.localizedDescription)")
        }
    } catch {
        print("Unexpected error: \(error)")
    }
}