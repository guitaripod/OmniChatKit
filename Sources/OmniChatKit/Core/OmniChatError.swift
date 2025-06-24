import Foundation

public enum OmniChatError: LocalizedError, Sendable {
    case authentication(AuthenticationError)
    case api(APIError)
    case network(NetworkError)
    case decoding(DecodingError)
    case streaming(StreamError)
    case validation(ValidationError)
    case fileOperation(FileOperationError)
    
    public var errorDescription: String? {
        switch self {
        case .authentication(let error):
            return error.errorDescription
        case .api(let error):
            return error.errorDescription
        case .network(let error):
            return error.errorDescription
        case .decoding(let error):
            return error.errorDescription
        case .streaming(let error):
            return error.errorDescription
        case .validation(let error):
            return error.errorDescription
        case .fileOperation(let error):
            return error.errorDescription
        }
    }
}

public enum AuthenticationError: LocalizedError, Sendable {
    case missingToken
    case missingRefreshToken
    case invalidToken
    case tokenExpired
    case tokenRefreshFailed(String)
    case tokenRefreshNotImplemented
    case unauthorized
    
    public var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Authentication token is missing"
        case .missingRefreshToken:
            return "Refresh token is missing"
        case .invalidToken:
            return "Authentication token is invalid"
        case .tokenExpired:
            return "Authentication token has expired"
        case .tokenRefreshFailed(let reason):
            return "Failed to refresh token: \(reason)"
        case .tokenRefreshNotImplemented:
            return "Token refresh not implemented for this authentication type"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}

public enum APIError: LocalizedError, Sendable {
    case badRequest(String)
    case unauthorized
    case forbidden(String)
    case notFound(String)
    case paymentRequired(currentBalance: Double, estimatedCost: Double)
    case modelAccessDenied(model: String, provider: String)
    case rateLimitExceeded
    case serverError(String)
    case serviceUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .unauthorized:
            return "Unauthorized"
        case .forbidden(let message):
            return "Forbidden: \(message)"
        case .notFound(let resource):
            return "Not found: \(resource)"
        case .paymentRequired(let balance, let cost):
            return "Insufficient battery balance. Current: \(balance), Required: \(cost)"
        case .modelAccessDenied(let model, let provider):
            return "Access denied for model \(model) from provider \(provider)"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .serverError(let message):
            return "Server error: \(message)"
        case .serviceUnavailable:
            return "Service unavailable"
        }
    }
}

public enum NetworkError: LocalizedError, Sendable {
    case connectionFailed
    case timeout
    case noInternetConnection
    case invalidURL
    case requestCancelled
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Connection failed"
        case .timeout:
            return "Request timed out"
        case .noInternetConnection:
            return "No internet connection"
        case .invalidURL:
            return "Invalid URL"
        case .requestCancelled:
            return "Request was cancelled"
        }
    }
}

public enum DecodingError: LocalizedError, Sendable {
    case invalidResponse
    case missingData
    case typeMismatch(expected: String, actual: String)
    case keyNotFound(String)
    case invalidJSON
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response format"
        case .missingData:
            return "Response data is missing"
        case .typeMismatch(let expected, let actual):
            return "Type mismatch: expected \(expected), got \(actual)"
        case .keyNotFound(let key):
            return "Required key not found: \(key)"
        case .invalidJSON:
            return "Invalid JSON format"
        }
    }
}

public enum StreamError: LocalizedError, Sendable {
    case connectionLost
    case invalidFormat
    case streamClosed
    case streamTimeout
    case incompleteMesage
    
    public var errorDescription: String? {
        switch self {
        case .connectionLost:
            return "Stream connection lost"
        case .invalidFormat:
            return "Invalid stream format"
        case .streamClosed:
            return "Stream closed unexpectedly"
        case .streamTimeout:
            return "Stream timed out"
        case .incompleteMesage:
            return "Incomplete stream message"
        }
    }
}

public enum ValidationError: LocalizedError, Sendable {
    case invalidParameter(name: String, reason: String)
    case missingRequiredField(String)
    case invalidFileSize(maxSize: Int)
    case unsupportedFileType(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidParameter(let name, let reason):
            return "Invalid parameter '\(name)': \(reason)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidFileSize(let maxSize):
            return "File size exceeds maximum allowed size of \(maxSize) bytes"
        case .unsupportedFileType(let type):
            return "Unsupported file type: \(type)"
        }
    }
}

public enum FileOperationError: LocalizedError, Sendable {
    case uploadFailed(String)
    case downloadFailed(String)
    case fileNotFound
    case accessDenied
    case storageLimitExceeded
    
    public var errorDescription: String? {
        switch self {
        case .uploadFailed(let reason):
            return "File upload failed: \(reason)"
        case .downloadFailed(let reason):
            return "File download failed: \(reason)"
        case .fileNotFound:
            return "File not found"
        case .accessDenied:
            return "File access denied"
        case .storageLimitExceeded:
            return "Storage limit exceeded"
        }
    }
}