import ArgumentParser
import Foundation
import OmniChatKit
import Rainbow
import OpenAPIRuntime
import OpenAPIURLSession

struct Chat: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "💬 Interactive chat with AI models",
        discussion: """
        Start an interactive chat session with AI models.
        Supports streaming responses and multiple models.
        
        Examples:
          omnichat chat                    # Start interactive chat with default model
          omnichat chat -m gpt-4o          # Use specific model
          omnichat chat "Hello!"           # Send single message
          omnichat chat -c conv-123        # Continue existing conversation
        """
    )
    
    @Argument(help: "Initial message (optional - starts interactive mode if not provided)")
    var message: String?
    
    @Option(name: .shortAndLong, help: "Model to use (e.g., gpt-4o, claude-opus-4-20250514)")
    var model: String = "gpt-4o-mini"
    
    @Option(name: .shortAndLong, help: "Conversation ID to continue")
    var conversationId: String?
    
    @Flag(name: .shortAndLong, help: "Disable streaming (wait for complete response)")
    var noStream = false
    
    @Flag(name: .shortAndLong, help: "Show token usage and timing")
    var verbose = false
    
    @Option(name: .shortAndLong, help: "System prompt")
    var system: String?
    
    @Option(name: .shortAndLong, help: "Temperature (0.0-2.0)")
    var temperature: Double = 0.7
    
    @Option(name: .shortAndLong, help: "Max tokens")
    var maxTokens: Int = 4096
    
    mutating func run() async throws {
        let client = try AuthManager.shared.getClient()
        
        ConsoleOutput.printHeader("💬 OmniChat Interactive Session")
        ConsoleOutput.printKeyValue("Model", model.cyan)
        
        if let convId = conversationId {
            ConsoleOutput.printKeyValue("Conversation", convId.yellow)
            
            // Try to get conversation details
            let response = try? await client.get_sol_api_sol_v1_sol_conversations_sol__lcub_id_rcub_(.init(
                path: .init(id: convId)
            ))
            
            if case .ok(let ok) = response,
               let conv = try? ok.body.json {
                ConsoleOutput.printKeyValue("Title", conv.title)
                // Note: messageCount field not available in generated API
            }
        }
        
        ConsoleOutput.printInfo("Type 'exit' or press Ctrl+C to quit")
        ConsoleOutput.printInfo("Type 'clear' to start a new conversation")
        ConsoleOutput.printInfo("Type 'models' to list available models")
        print()
        
        var messages: [Components.Schemas.ChatMessage] = []
        
        if let systemPrompt = system {
            messages.append(.init(
                role: .system,
                content: systemPrompt
            ))
        }
        
        if let initialMessage = message {
            await sendMessage(initialMessage, to: &messages, using: client)
        }
        
        while true {
            print("\n" + "You: ".green.bold, terminator: "")
            guard let input = readLine(), !input.isEmpty else { continue }
            
            switch input.lowercased() {
            case "exit", "quit", "q":
                ConsoleOutput.printInfo("Goodbye! 👋")
                return
                
            case "clear":
                messages.removeAll()
                conversationId = nil
                ConsoleOutput.printSuccess("Conversation cleared")
                continue
                
            case "models":
                await listModels(using: client)
                continue
                
            case "history":
                printHistory(messages)
                continue
                
            default:
                await sendMessage(input, to: &messages, using: client)
            }
        }
    }
    
    private mutating func sendMessage(_ content: String, to messages: inout [Components.Schemas.ChatMessage], using client: Client) async {
        messages.append(.init(
            role: .user,
            content: content
        ))
        
        let startTime = Date()
        print("\n" + "Assistant: ".blue.bold, terminator: "")
        
        do {
            let request = Components.Schemas.ChatRequest(
                messages: messages,
                model: model,
                temperature: temperature,
                maxTokens: maxTokens,
                stream: !noStream,
                conversationId: conversationId ?? ""
            )
            
            let response = try await client.post_sol_api_sol_chat(.init(
                body: .json(request)
            ))
            
            switch response {
            case .ok(let ok):
                if noStream {
                    // Non-streaming response
                    if case .json(let chatResponse) = ok.body {
                        let content = chatResponse.message ?? ""
                        print(content.white)
                        messages.append(.init(
                            role: .assistant,
                            content: content
                        ))
                        
                        if verbose {
                            let duration = Date().timeIntervalSince(startTime)
                            ConsoleOutput.printInfo("Time: \(String(format: "%.2fs", duration))")
                        }
                    }
                } else {
                    // Streaming response
                    var fullResponse = ""
                    
                    if case .text_event_hyphen_stream(let stream) = ok.body {
                        for try await bytes in stream {
                            if let string = String(data: Data(bytes), encoding: .utf8) {
                                // Parse SSE format
                                if string.hasPrefix("data: ") {
                                    let data = string.dropFirst(6)
                                    if data.hasPrefix("[DONE]") {
                                        break
                                    }
                                    
                                    if let jsonData = data.data(using: .utf8),
                                       let chunk = try? JSONDecoder().decode(StreamChunk.self, from: jsonData),
                                       let delta = chunk.choices.first?.delta.content {
                                        print(delta.white, terminator: "")
                                        fflush(stdout)
                                        fullResponse += delta
                                    }
                                }
                            }
                        }
                        
                        print() // Newline after streaming
                        
                        if !fullResponse.isEmpty {
                            messages.append(.init(
                                role: .assistant,
                                content: fullResponse
                            ))
                        }
                        
                        if verbose {
                            let duration = Date().timeIntervalSince(startTime)
                            ConsoleOutput.printInfo("Time: \(String(format: "%.2fs", duration))")
                        }
                    }
                }
                
            case .badRequest:
                print()
                ConsoleOutput.printError("Bad request - check your input")
            case .unauthorized:
                print()
                ConsoleOutput.printError("Authentication failed - please re-authenticate")
            case .code402:
                print()
                ConsoleOutput.printError("Payment required - insufficient credits")
            case .forbidden:
                print()
                ConsoleOutput.printError("Access denied for this model")
            case .internalServerError:
                print()
                ConsoleOutput.printError("Server error - please try again")
            case .serviceUnavailable:
                print()
                ConsoleOutput.printError("Service temporarily unavailable")
            case .undocumented(let statusCode, _):
                print()
                ConsoleOutput.printError("Unexpected error (status: \(statusCode))")
            }
            
        } catch {
            print()
            ConsoleOutput.printError("Chat error: \(error.localizedDescription)")
            
            // Remove the user message on error
            if messages.count > 1 {
                messages.removeLast()
            }
        }
    }
    
    private func listModels(using client: Client) async {
        ConsoleOutput.printSubheader("Available Models")
        
        do {
            let response = try await client.get_sol_api_sol_models(.init())
            
            switch response {
            case .ok(let ok):
                _ = try ok.body.json
                
                // The providers field contains the models
                // This is a simplified version - you'd need to properly parse the response
                ConsoleOutput.printInfo("Models loaded - implementation needed for display")
                
            default:
                ConsoleOutput.printError("Failed to fetch models")
            }
        } catch {
            ConsoleOutput.printError("Failed to fetch models: \(error.localizedDescription)")
        }
    }
    
    private func printHistory(_ messages: [Components.Schemas.ChatMessage]) {
        ConsoleOutput.printSubheader("Conversation History")
        
        for (index, message) in messages.enumerated() {
            let role = message.role.rawValue.capitalized
            let content = message.content
            
            print("\n[\(index + 1)] \(role.bold.applyingColor(roleColor(for: message.role)))")
            print(content.wrapped(width: 80, indent: 4))
        }
    }
    
    private func roleColor(for role: Components.Schemas.ChatMessage.rolePayload) -> NamedColor {
        switch role {
        case .system: return .yellow
        case .user: return .green
        case .assistant: return .blue
        case .tool: return .magenta
        }
    }
}

// Helper struct for parsing streaming chunks
private struct StreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }
        let delta: Delta
    }
    let choices: [Choice]
}

extension String {
    func wrapped(width: Int, indent: Int = 0) -> String {
        let words = self.split(separator: " ")
        var lines: [String] = []
        var currentLine = String(repeating: " ", count: indent)
        
        for word in words {
            if currentLine.count + word.count + 1 > width {
                lines.append(currentLine)
                currentLine = String(repeating: " ", count: indent) + String(word)
            } else {
                if currentLine.count > indent {
                    currentLine += " "
                }
                currentLine += word
            }
        }
        
        if currentLine.count > indent {
            lines.append(currentLine)
        }
        
        return lines.joined(separator: "\n")
    }
}