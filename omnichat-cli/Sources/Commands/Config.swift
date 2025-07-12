import ArgumentParser
import Foundation
import OmniChatKit
import Rainbow
import Files

struct Config: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "⚙️ Manage CLI configuration",
        subcommands: [
            Get.self,
            Set.self,
            List.self,
            Reset.self,
            Path.self
        ],
        defaultSubcommand: List.self
    )
    
    struct ConfigManager {
        static let shared = ConfigManager()
        
        private let configFile: File
        
        private init() {
            do {
                let homeFolder = try Folder(path: NSHomeDirectory())
                let configFolder = try homeFolder.createSubfolderIfNeeded(at: ".omnichat-cli")
                
                if configFolder.containsFile(named: "config.json") {
                    configFile = try configFolder.file(named: "config.json")
                } else {
                    configFile = try configFolder.createFile(named: "config.json")
                    try configFile.write("{}")
                }
            } catch {
                fatalError("Failed to initialize config: \(error)")
            }
        }
        
        func get(_ key: String) -> Any? {
            guard let data = try? configFile.read(),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            return json[key]
        }
        
        func set(_ key: String, value: Any) throws {
            var json: [String: Any] = [:]
            
            if let data = try? configFile.read(),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                json = existing
            }
            
            json[key] = value
            
            let newData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            try configFile.write(newData)
        }
        
        func list() -> [String: Any] {
            guard let data = try? configFile.read(),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return [:]
            }
            
            return json
        }
        
        func reset() throws {
            try configFile.write("{}")
        }
        
        var path: String {
            return configFile.path
        }
    }
    
    struct Get: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Get configuration value"
        )
        
        @Argument(help: "Configuration key")
        var key: String
        
        mutating func run() async throws {
            let config = ConfigManager.shared
            
            if let value = config.get(key) {
                ConsoleOutput.printKeyValue(key, "\(value)", color: .green)
            } else {
                ConsoleOutput.printWarning("Key '\(key)' not found in configuration")
            }
        }
    }
    
    struct Set: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Set configuration value"
        )
        
        @Argument(help: "Configuration key")
        var key: String
        
        @Argument(help: "Configuration value")
        var value: String
        
        mutating func run() async throws {
            let config = ConfigManager.shared
            
            let parsedValue: Any
            if let boolValue = Bool(value) {
                parsedValue = boolValue
            } else if let intValue = Int(value) {
                parsedValue = intValue
            } else if let doubleValue = Double(value) {
                parsedValue = doubleValue
            } else {
                parsedValue = value
            }
            
            do {
                try config.set(key, value: parsedValue)
                ConsoleOutput.printSuccess("Configuration updated")
                ConsoleOutput.printKeyValue(key, "\(parsedValue)", color: .green)
            } catch {
                ConsoleOutput.printError("Failed to update configuration: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all configuration values"
        )
        
        @Flag(name: .shortAndLong, help: "Output as JSON")
        var json = false
        
        mutating func run() async throws {
            let config = ConfigManager.shared
            let values = config.list()
            
            if json {
                let data = try JSONSerialization.data(withJSONObject: values, options: .prettyPrinted)
                print(String(data: data, encoding: .utf8) ?? "{}")
            } else {
                ConsoleOutput.printHeader("⚙️ Configuration")
                
                if values.isEmpty {
                    ConsoleOutput.printInfo("No configuration values set")
                } else {
                    let availableKeys = [
                        "default_model": "Default AI model for chat",
                        "default_server": "Default server URL",
                        "enable_streaming": "Enable streaming responses by default",
                        "max_tokens": "Default maximum tokens for responses",
                        "temperature": "Default temperature for AI responses",
                        "auto_save_conversations": "Automatically save conversations",
                        "show_token_usage": "Show token usage after responses",
                        "theme": "Color theme (dark/light/auto)",
                        "log_level": "Logging level (debug/info/warning/error)"
                    ]
                    
                    for (key, description) in availableKeys.sorted(by: { $0.key < $1.key }) {
                        if let value = values[key] {
                            print("\n\(key.bold)")
                            print("  Value: \(String(describing: value).green)")
                            print("  Description: \(description.dim)")
                        }
                    }
                    
                    let customKeys = values.keys.filter { !availableKeys.keys.contains($0) }
                    if !customKeys.isEmpty {
                        ConsoleOutput.printSubheader("Custom Configuration")
                        for key in customKeys.sorted() {
                            if let value = values[key] {
                                ConsoleOutput.printKeyValue(key, "\(value)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    struct Reset: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Reset configuration to defaults"
        )
        
        @Flag(name: .shortAndLong, help: "Skip confirmation")
        var force = false
        
        mutating func run() async throws {
            if !force {
                ConsoleOutput.printWarning("This will reset all configuration to defaults.")
                print("Continue? (y/N): ", terminator: "")
                
                guard let response = readLine(), response.lowercased() == "y" else {
                    ConsoleOutput.printInfo("Cancelled")
                    return
                }
            }
            
            let config = ConfigManager.shared
            
            do {
                try config.reset()
                ConsoleOutput.printSuccess("Configuration reset to defaults")
            } catch {
                ConsoleOutput.printError("Failed to reset configuration: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct Path: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show configuration file path"
        )
        
        mutating func run() async throws {
            let config = ConfigManager.shared
            ConsoleOutput.printHeader("📁 Configuration File")
            ConsoleOutput.printKeyValue("Path", config.path, color: .blue)
            
            #if os(macOS)
            ConsoleOutput.printInfo("Open in Finder: open ~/.omnichat-cli/")
            #else
            ConsoleOutput.printInfo("View directory: ls -la ~/.omnichat-cli/")
            #endif
        }
    }
}