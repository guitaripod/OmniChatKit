import ArgumentParser
import Foundation
import OmniChatKit
import Rainbow

struct Models: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "🤖 List available AI models"
    )
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json = false
    
    mutating func run() async throws {
        let client = try AuthManager.shared.getClient()
        
        if !json {
            ConsoleOutput.printHeader("🤖 Available AI Models")
        }
        
        do {
            let response = try await client.get_sol_api_sol_models(.init())
            
            switch response {
            case .ok(let ok):
                let modelsResponse = try ok.body.json
                
                if json {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    if let data = try? encoder.encode(modelsResponse) {
                        print(String(data: data, encoding: .utf8) ?? "{}")
                    }
                } else {
                    // The providers field is a dictionary-like structure in the generated code
                    // You would need to properly parse this based on the actual response structure
                    ConsoleOutput.printInfo("Models retrieved successfully")
                    ConsoleOutput.printInfo("Note: Full model display implementation needed based on actual API response structure")
                }
                
            case .unauthorized:
                ConsoleOutput.printError("Authentication required")
                throw ExitCode.failure
                
            case .internalServerError:
                ConsoleOutput.printError("Server error")
                throw ExitCode.failure
                
            case .undocumented(let statusCode, _):
                ConsoleOutput.printError("Unexpected status: \(statusCode)")
                throw ExitCode.failure
            }
            
        } catch {
            ConsoleOutput.printError("Failed to fetch models: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}