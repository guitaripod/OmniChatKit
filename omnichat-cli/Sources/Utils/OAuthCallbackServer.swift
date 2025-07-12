import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1

final class OAuthCallbackServer: @unchecked Sendable {
    private let port: Int
    private let callbackPath: String
    private var channel: Channel?
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var authorizationCode: String?
    private var idToken: String?
    private let semaphore = DispatchSemaphore(value: 0)
    
    init(port: Int = 9876, callbackPath: String = "/callback") {
        self.port = port
        self.callbackPath = callbackPath
    }
    
    deinit {
        try? group.syncShutdownGracefully()
    }
    
    func start() async throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(OAuthHTTPHandler(callbackPath: self.callbackPath) { code, idToken in
                        self.authorizationCode = code
                        self.idToken = idToken
                        self.semaphore.signal()
                    })
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        channel = try await bootstrap.bind(host: "127.0.0.1", port: port).get()
    }
    
    func waitForCallback(timeout: TimeInterval = 300) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let result = self.semaphore.wait(timeout: .now() + timeout)
                
                if result == .success, let code = self.authorizationCode {
                    continuation.resume(returning: code)
                } else {
                    continuation.resume(throwing: OAuthError.timeout)
                }
            }
        }
    }
    
    func waitForIdToken(timeout: TimeInterval = 300) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let result = self.semaphore.wait(timeout: .now() + timeout)
                
                if result == .success, let token = self.idToken {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: OAuthError.timeout)
                }
            }
        }
    }
    
    func stop() async throws {
        try await channel?.close()
        try await group.shutdownGracefully()
    }
}

private class OAuthHTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let callbackPath: String
    private let onTokensReceived: (String?, String?) -> Void
    private var requestHead: HTTPRequestHead?
    private var bodyData = Data()
    
    init(callbackPath: String, onTokensReceived: @escaping (String?, String?) -> Void) {
        self.callbackPath = callbackPath
        self.onTokensReceived = onTokensReceived
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let head):
            requestHead = head
            
        case .body(let body):
            var data = body
            if let bytes = data.readBytes(length: data.readableBytes) {
                bodyData.append(contentsOf: bytes)
            }
            
        case .end:
            guard let head = requestHead else { return }
            
            if head.uri.hasPrefix(callbackPath) {
                if head.method == .POST {
                    handleFormPost(context: context)
                } else {
                    // Check for ID token in fragment or query params
                    if let idToken = extractIdToken(from: head.uri) {
                        onTokensReceived(nil, idToken)
                        sendSuccessResponse(context: context)
                    } else if let code = extractCode(from: head.uri) {
                        onTokensReceived(code, nil)
                        sendSuccessResponse(context: context)
                    } else if let error = extractError(from: head.uri) {
                        sendErrorResponse(context: context, message: error)
                    } else {
                        sendErrorResponse(context: context, message: "No authorization code found")
                    }
                }
            } else {
                send404Response(context: context)
            }
            
            bodyData = Data()
        }
    }
    
    private func extractCode(from uri: String) -> String? {
        guard let url = URL(string: "http://localhost\(uri)"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        return code
    }
    
    private func extractIdToken(from uri: String) -> String? {
        guard let url = URL(string: "http://localhost\(uri)"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let idToken = components.queryItems?.first(where: { $0.name == "id_token" })?.value else {
            return nil
        }
        return idToken
    }
    
    private func extractError(from uri: String) -> String? {
        guard let url = URL(string: "http://localhost\(uri)"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let error = components.queryItems?.first(where: { $0.name == "error" })?.value else {
            return nil
        }
        return error
    }
    
    private func handleFormPost(context: ChannelHandlerContext) {
        guard let formData = String(data: bodyData, encoding: .utf8) else {
            sendErrorResponse(context: context, message: "Invalid form data")
            return
        }
        
        let params = formData.split(separator: "&")
            .compactMap { pair -> (String, String)? in
                let parts = pair.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return (String(parts[0]), String(parts[1]).removingPercentEncoding ?? String(parts[1]))
            }
            .reduce(into: [String: String]()) { result, pair in
                result[pair.0] = pair.1
            }
        
        if let idToken = params["id_token"] {
            onTokensReceived(params["code"], idToken)
            sendSuccessResponse(context: context)
        } else {
            sendErrorResponse(context: context, message: "No ID token found in response")
        }
    }
    
    private func sendSuccessResponse(context: ChannelHandlerContext) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Authentication Successful</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background-color: #f5f5f5;
                }
                .container {
                    text-align: center;
                    padding: 40px;
                    background: white;
                    border-radius: 10px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }
                h1 { color: #4CAF50; }
                p { color: #666; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>✅ Authentication Successful!</h1>
                <p>You can now close this window and return to the terminal.</p>
                <p>OmniChat CLI has received your authentication.</p>
            </div>
        </body>
        </html>
        """
        
        sendHTMLResponse(context: context, html: html, status: .ok)
    }
    
    private func sendErrorResponse(context: ChannelHandlerContext, message: String) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Authentication Failed</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background-color: #f5f5f5;
                }
                .container {
                    text-align: center;
                    padding: 40px;
                    background: white;
                    border-radius: 10px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }
                h1 { color: #f44336; }
                p { color: #666; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>❌ Authentication Failed</h1>
                <p>\(message)</p>
                <p>Please return to the terminal and try again.</p>
            </div>
        </body>
        </html>
        """
        
        sendHTMLResponse(context: context, html: html, status: .badRequest)
    }
    
    private func send404Response(context: ChannelHandlerContext) {
        sendHTMLResponse(context: context, html: "<h1>404 Not Found</h1>", status: .notFound)
    }
    
    private func sendHTMLResponse(context: ChannelHandlerContext, html: String, status: HTTPResponseStatus) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/html; charset=utf-8")
        headers.add(name: "Content-Length", value: "\(html.utf8.count)")
        
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        
        var buffer = context.channel.allocator.buffer(capacity: html.utf8.count)
        buffer.writeString(html)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        
        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
            context.close(promise: nil)
        }
    }
}

enum OAuthError: LocalizedError {
    case timeout
    case noCode
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "OAuth callback timed out. Please try again."
        case .noCode:
            return "No authorization code received."
        case .serverError(let message):
            return "OAuth server error: \(message)"
        }
    }
}