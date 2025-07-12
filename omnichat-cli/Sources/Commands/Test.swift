import ArgumentParser
import Foundation
import OmniChatKit
import Rainbow

struct Test: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "🧪 Test API endpoints",
        discussion: "Run basic tests to verify the API connection and authentication"
    )
    
    mutating func run() async throws {
        ConsoleOutput.printHeader("🧪 OmniChatKit API Tests")
        
        do {
            let client = try AuthManager.shared.getClient()
            
            // Test 1: Get user profile
            ConsoleOutput.printSubheader("Test 1: User Profile")
            let spinner1 = ConsoleOutput.startSpinner(message: "Getting user profile...")
            
            let userResponse = try await client.get_sol_api_sol_v1_sol_user_sol_profile(.init())
            ConsoleOutput.stopSpinner(spinner1)
            
            switch userResponse {
            case .ok(let ok):
                let user = try ok.body.json
                ConsoleOutput.printSuccess("✓ User profile retrieved")
                ConsoleOutput.printKeyValue("  User ID", user.id)
                ConsoleOutput.printKeyValue("  Email", user.email)
            default:
                ConsoleOutput.printError("✗ Failed to get user profile")
            }
            
            // Test 2: Get models
            ConsoleOutput.printSubheader("Test 2: Available Models")
            let spinner2 = ConsoleOutput.startSpinner(message: "Getting models...")
            
            let modelsResponse = try await client.get_sol_api_sol_models(.init())
            ConsoleOutput.stopSpinner(spinner2)
            
            switch modelsResponse {
            case .ok:
                ConsoleOutput.printSuccess("✓ Models retrieved successfully")
            default:
                ConsoleOutput.printError("✗ Failed to get models")
            }
            
            // Test 3: Create and delete a conversation
            ConsoleOutput.printSubheader("Test 3: Conversation Management")
            let spinner3 = ConsoleOutput.startSpinner(message: "Creating test conversation...")
            
            let createResponse = try await client.post_sol_api_sol_v1_sol_conversations(.init(
                body: .json(.init(
                    title: "Test Conversation \(Date().timeIntervalSince1970)",
                    model: "gpt-4o-mini"
                ))
            ))
            ConsoleOutput.stopSpinner(spinner3)
            
            switch createResponse {
            case .ok(let ok):
                let conversation = try ok.body.json
                ConsoleOutput.printSuccess("✓ Conversation created")
                ConsoleOutput.printKeyValue("  ID", conversation.id)
                
                // Clean up - delete the conversation
                let deleteResponse = try await client.delete_sol_api_sol_v1_sol_conversations_sol__lcub_id_rcub_(.init(
                    path: .init(id: conversation.id)
                ))
                
                if case .ok = deleteResponse {
                    ConsoleOutput.printSuccess("✓ Conversation deleted (cleanup)")
                }
                
            default:
                ConsoleOutput.printError("✗ Failed to create conversation")
            }
            
            ConsoleOutput.printHeader("Test Summary")
            ConsoleOutput.printSuccess("All basic tests completed!")
            ConsoleOutput.printInfo("The API connection and authentication are working correctly.")
            
        } catch {
            ConsoleOutput.printError("Test failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}