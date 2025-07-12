import ArgumentParser
import OmniChatKit
import Rainbow
import Foundation

struct OmniChatCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "omnichat",
        abstract: "🚀 Beautiful CLI for testing OmniChatKit".bold,
        discussion: """
        A comprehensive testing tool for the OmniChatKit Swift package.
        Supports all authentication methods, endpoints, and streaming features.
        
        Built with ❤️ for Linux and macOS.
        """,
        version: "1.0.0",
        subcommands: [
            Auth.self,
            Chat.self,
            Models.self,
            Test.self,
            Config.self
        ],
        defaultSubcommand: nil
    )
    
    struct GlobalOptions: ParsableArguments {
        @Option(name: .shortAndLong, help: "Server URL (defaults to https://omnichat-7pu.pages.dev)")
        var server: String = "https://omnichat-7pu.pages.dev"
        
        @Flag(name: .shortAndLong, help: "Enable verbose logging")
        var verbose = false
        
        @Flag(name: .shortAndLong, help: "Output raw JSON responses")
        var json = false
        
        @Option(name: .shortAndLong, help: "Config file path")
        var config: String?
    }
}

// For Linux compatibility with async commands
#if os(Linux)
import Dispatch

Task {
    do {
        try await OmniChatCLI.main()
        exit(0)
    } catch {
        exit(1)
    }
}

dispatchMain()
#else
OmniChatCLI.main()
#endif
