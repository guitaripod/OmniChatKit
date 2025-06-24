import Foundation
#if os(Linux)
import FoundationNetworking
#endif
#if canImport(OSLog)
import OSLog
#else
import Logging
#endif

public struct SSEEvent: Sendable {
    public let id: String?
    public let event: String?
    public let data: String
    public let retry: Int?
}

public actor SSEParser {
    #if canImport(OSLog)
    private let logger = Logger(subsystem: "com.omnichat.kit", category: "SSEParser")
    #else
    private let logger = Logger(label: "com.omnichat.kit.SSEParser")
    #endif
    
    public init() {}
    
    public func parseEvents(from data: Data) async throws -> [SSEEvent] {
        guard let string = String(data: data, encoding: .utf8) else {
            throw OmniChatError.streaming(.invalidFormat)
        }
        
        var events: [SSEEvent] = []
        var currentEvent = SSEEventBuilder()
        
        let lines = string.components(separatedBy: .newlines)
        
        for line in lines {
            if line.isEmpty {
                if currentEvent.hasData {
                    events.append(currentEvent.build())
                    currentEvent = SSEEventBuilder()
                }
                continue
            }
            
            if line.hasPrefix(":") {
                continue
            }
            
            if let colonIndex = line.firstIndex(of: ":") {
                let field = String(line[..<colonIndex])
                var value = String(line[line.index(after: colonIndex)...])
                
                if value.hasPrefix(" ") {
                    value = String(value.dropFirst())
                }
                
                switch field {
                case "id":
                    currentEvent.id = value
                case "event":
                    currentEvent.event = value
                case "data":
                    if currentEvent.data.isEmpty {
                        currentEvent.data = value
                    } else {
                        currentEvent.data += "\n" + value
                    }
                case "retry":
                    currentEvent.retry = Int(value)
                default:
                    logger.debug("Unknown SSE field: \(field)")
                }
            }
        }
        
        if currentEvent.hasData {
            events.append(currentEvent.build())
        }
        
        return events
    }
}

private struct SSEEventBuilder {
    var id: String?
    var event: String?
    var data: String = ""
    var retry: Int?
    
    var hasData: Bool {
        !data.isEmpty
    }
    
    func build() -> SSEEvent {
        SSEEvent(id: id, event: event, data: data, retry: retry)
    }
}

public final class StreamingResponseHandler: @unchecked Sendable {
    private let continuation: AsyncThrowingStream<String, any Error>.Continuation
    private let parser = SSEParser()
    #if canImport(OSLog)
    private let logger = Logger(subsystem: "com.omnichat.kit", category: "StreamingResponseHandler")
    #else
    private let logger = Logger(label: "com.omnichat.kit.StreamingResponseHandler")
    #endif
    private var buffer = Data()
    
    init(continuation: AsyncThrowingStream<String, any Error>.Continuation) {
        self.continuation = continuation
    }
    
    public func handleData(_ data: Data) async {
        buffer.append(data)
        
        do {
            let events = try await parser.parseEvents(from: buffer)
            buffer.removeAll()
            
            for event in events {
                if event.data == "[DONE]" {
                    continuation.finish()
                    return
                }
                
                continuation.yield(event.data)
            }
        } catch {
            logger.error("Failed to parse SSE events: \(error)")
            continuation.finish(throwing: error)
        }
    }
    
    public func handleError(_ error: any Error) {
        continuation.finish(throwing: error)
    }
    
    public func handleCompletion() {
        continuation.finish()
    }
}

public extension AsyncThrowingStream where Element == String {
    static func chatStream(
        from urlSession: URLSession,
        request: URLRequest
    ) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream<String, any Error> { continuation in
            let handler = StreamingResponseHandler(continuation: continuation)
            
            let task = urlSession.dataTask(with: request) { data, response, error in
                Task {
                    if let error = error {
                        await handler.handleError(error)
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        await handler.handleError(OmniChatError.network(.invalidURL))
                        return
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        await handler.handleError(OmniChatError.api(.serverError("HTTP \(httpResponse.statusCode)")))
                        return
                    }
                    
                    if let data = data {
                        await handler.handleData(data)
                    }
                    
                    await handler.handleCompletion()
                }
            }
            
            task.resume()
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}