import Foundation

enum BrowserOpener {
    static func open(url: URL) throws {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        try process.run()
        process.waitUntilExit()
        #elseif os(Linux)
        let commands = ["xdg-open", "gnome-open", "kde-open", "firefox", "chromium", "google-chrome"]
        
        for command in commands {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [command]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    let openProcess = Process()
                    openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    openProcess.arguments = [command, url.absoluteString]
                    try openProcess.run()
                    return
                }
            } catch {
                continue
            }
        }
        
        throw BrowserError.noBrowserFound
        #else
        throw BrowserError.unsupportedPlatform
        #endif
    }
}

enum BrowserError: LocalizedError {
    case noBrowserFound
    case unsupportedPlatform
    
    var errorDescription: String? {
        switch self {
        case .noBrowserFound:
            return "No web browser found. Please open the URL manually."
        case .unsupportedPlatform:
            return "Browser opening is not supported on this platform."
        }
    }
}