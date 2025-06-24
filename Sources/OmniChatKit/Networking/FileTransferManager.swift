import Foundation
#if os(Linux)
import FoundationNetworking
#endif
#if canImport(OSLog)
import OSLog
#else
import Logging
#endif

public final class FileUploadProgress: @unchecked Sendable {
    public let totalBytes: Int64
    public private(set) var uploadedBytes: Int64 = 0
    public private(set) var fractionCompleted: Double = 0
    public private(set) var isCompleted = false
    public private(set) var error: (any Error)?
    
    private let lock = NSLock()
    
    init(totalBytes: Int64) {
        self.totalBytes = totalBytes
    }
    
    func updateProgress(uploadedBytes: Int64) {
        lock.lock()
        defer { lock.unlock() }
        
        self.uploadedBytes = uploadedBytes
        self.fractionCompleted = totalBytes > 0 ? Double(uploadedBytes) / Double(totalBytes) : 0
    }
    
    func markCompleted() {
        lock.lock()
        defer { lock.unlock() }
        
        self.isCompleted = true
        self.fractionCompleted = 1.0
        self.uploadedBytes = totalBytes
    }
    
    func markFailed(with error: any Error) {
        lock.lock()
        defer { lock.unlock() }
        
        self.error = error
        self.isCompleted = true
    }
}

public final class FileDownloadProgress: @unchecked Sendable {
    public let totalBytes: Int64
    public private(set) var downloadedBytes: Int64 = 0
    public private(set) var fractionCompleted: Double = 0
    public private(set) var isCompleted = false
    public private(set) var error: (any Error)?
    public private(set) var data: Data?
    
    private let lock = NSLock()
    
    init(totalBytes: Int64) {
        self.totalBytes = totalBytes
    }
    
    func updateProgress(downloadedBytes: Int64, data: Data? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        self.downloadedBytes = downloadedBytes
        self.fractionCompleted = totalBytes > 0 ? Double(downloadedBytes) / Double(totalBytes) : 0
        if let data = data {
            self.data = data
        }
    }
    
    func markCompleted(with data: Data) {
        lock.lock()
        defer { lock.unlock() }
        
        self.isCompleted = true
        self.fractionCompleted = 1.0
        self.downloadedBytes = totalBytes
        self.data = data
    }
    
    func markFailed(with error: any Error) {
        lock.lock()
        defer { lock.unlock() }
        
        self.error = error
        self.isCompleted = true
    }
}

public final class FileTransferManager: NSObject, @unchecked Sendable {
    #if canImport(OSLog)
    private let logger = Logger(subsystem: "com.omnichat.kit", category: "FileTransferManager")
    #else
    private let logger = Logger(label: "com.omnichat.kit.FileTransferManager")
    #endif
    private let session: URLSession
    private var uploadTasks: [URLSessionUploadTask: FileUploadProgress] = [:]
    private var downloadTasks: [URLSessionDownloadTask: FileDownloadProgress] = [:]
    private let lock = NSLock()
    
    public override init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 600
        
        self.session = URLSession(
            configuration: configuration,
            delegate: nil,
            delegateQueue: nil
        )
        super.init()
    }
    
    public func uploadFile(
        _ data: Data,
        to url: URL,
        headers: [String: String],
        progressHandler: ((FileUploadProgress) -> Void)? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let progress = FileUploadProgress(totalBytes: Int64(data.count))
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.uploadTask(with: request, from: data) { [weak self] data, response, error in
                self?.lock.lock()
                defer { self?.lock.unlock() }
                
                if let error = error {
                    progress.markFailed(with: error)
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = OmniChatError.network(.invalidURL)
                    progress.markFailed(with: error)
                    continuation.resume(throwing: error)
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let error = OmniChatError.api(.serverError("HTTP \(httpResponse.statusCode)"))
                    progress.markFailed(with: error)
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    let error = OmniChatError.decoding(.missingData)
                    progress.markFailed(with: error)
                    continuation.resume(throwing: error)
                    return
                }
                
                progress.markCompleted()
                continuation.resume(returning: data)
            }
            
            lock.lock()
            uploadTasks[task] = progress
            lock.unlock()
            
            progressHandler?(progress)
            
            task.resume()
        }
    }
    
    public func downloadFile(
        from url: URL,
        headers: [String: String],
        progressHandler: ((FileDownloadProgress) -> Void)? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let progress = FileDownloadProgress(totalBytes: -1)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: request) { [weak self] localURL, response, error in
                self?.lock.lock()
                defer { self?.lock.unlock() }
                
                if let error = error {
                    progress.markFailed(with: error)
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = OmniChatError.network(.invalidURL)
                    progress.markFailed(with: error)
                    continuation.resume(throwing: error)
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let error = OmniChatError.api(.serverError("HTTP \(httpResponse.statusCode)"))
                    progress.markFailed(with: error)
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let localURL = localURL else {
                    let error = OmniChatError.fileOperation(.downloadFailed("No file URL"))
                    progress.markFailed(with: error)
                    continuation.resume(throwing: error)
                    return
                }
                
                do {
                    let data = try Data(contentsOf: localURL)
                    progress.markCompleted(with: data)
                    continuation.resume(returning: data)
                } catch {
                    progress.markFailed(with: error)
                    continuation.resume(throwing: error)
                }
            }
            
            lock.lock()
            downloadTasks[task] = progress
            lock.unlock()
            
            progressHandler?(progress)
            
            task.resume()
        }
    }
}

extension FileTransferManager: URLSessionTaskDelegate {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        if let uploadTask = task as? URLSessionUploadTask,
           let progress = uploadTasks[uploadTask] {
            progress.updateProgress(uploadedBytes: totalBytesSent)
        }
    }
}

extension FileTransferManager: URLSessionDownloadDelegate {
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        if let progress = downloadTasks[downloadTask] {
            progress.updateProgress(downloadedBytes: totalBytesWritten)
        }
    }
    
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Handled in the completion handler
    }
}