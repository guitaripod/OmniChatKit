import Foundation
#if canImport(OSLog)
import OSLog
#else
import Logging
#endif
#if canImport(Security)
import Security
#endif

public enum AuthenticationType: Sendable {
    case clerk(token: String)
    case bearer(jwt: String)
    case apiKeys([String: String])
}

public actor AuthenticationManager {
    private var authenticationType: AuthenticationType
    private var refreshTokenValue: String?
    private var accessToken: String?
    private var tokenExpirationDate: Date?
    #if canImport(OSLog)
    private let logger = Logger(subsystem: "com.omnichat.kit", category: "AuthenticationManager")
    #else
    private let logger = Logger(label: "com.omnichat.kit.AuthenticationManager")
    #endif
    
    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private let keychainService = "com.omnichat.kit.auth"
    #endif
    
    public init(authenticationType: AuthenticationType) {
        self.authenticationType = authenticationType
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
        Task {
            await loadStoredTokens()
        }
        #endif
    }
    
    public func authenticationHeaders() async throws -> [String: String] {
        switch authenticationType {
        case .clerk(let token):
            return ["Authorization": "Bearer \(token)"]
        case .bearer(let jwt):
            if let tokenExpirationDate = tokenExpirationDate,
               Date() > tokenExpirationDate.addingTimeInterval(-60) {
                logger.info("Token expired or expiring soon, refreshing...")
                let newToken = try await refreshToken()
                self.accessToken = newToken.accessToken
                self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(newToken.expiresIn))
                return ["Authorization": "Bearer \(newToken.accessToken)"]
            }
            return ["Authorization": "Bearer \(jwt)"]
        case .apiKeys(let keys):
            return keys
        }
    }
    
    public func refreshToken() async throws -> (accessToken: String, refreshToken: String?, expiresIn: Int) {
        guard let refreshTokenValue = refreshTokenValue else {
            throw OmniChatError.authentication(.missingRefreshToken)
        }
        
        throw OmniChatError.authentication(.tokenRefreshNotImplemented)
    }
    
    public func updateTokens(accessToken: String, refreshToken: String?, expiresIn: Int) async {
        self.accessToken = accessToken
        self.refreshTokenValue = refreshToken
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
        await storeTokensInKeychain()
        #endif
    }
    
    public func clearTokens() async {
        self.accessToken = nil
        self.refreshTokenValue = nil
        self.tokenExpirationDate = nil
        
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
        await clearKeychainTokens()
        #endif
    }
    
    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private func storeTokensInKeychain() async {
        if let accessToken = accessToken {
            await storeKeychainItem(key: "accessToken", value: accessToken)
        }
        
        if let refreshTokenValue = refreshTokenValue {
            await storeKeychainItem(key: "refreshToken", value: refreshTokenValue)
        }
        
        if let tokenExpirationDate = tokenExpirationDate {
            let expirationString = ISO8601DateFormatter().string(from: tokenExpirationDate)
            await storeKeychainItem(key: "tokenExpiration", value: expirationString)
        }
    }
    
    private func loadStoredTokens() async {
        if let storedAccessToken = await loadKeychainItem(key: "accessToken") {
            self.accessToken = storedAccessToken
        }
        
        if let storedRefreshToken = await loadKeychainItem(key: "refreshToken") {
            self.refreshTokenValue = storedRefreshToken
        }
        
        if let expirationString = await loadKeychainItem(key: "tokenExpiration"),
           let expirationDate = ISO8601DateFormatter().date(from: expirationString) {
            self.tokenExpirationDate = expirationDate
        }
    }
    
    private func storeKeychainItem(key: String, value: String) async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: value.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Failed to store keychain item: \(key)")
        }
    }
    
    private func loadKeychainItem(key: String) async -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        
        return nil
    }
    
    private func clearKeychainTokens() async {
        let keys = ["accessToken", "refreshToken", "tokenExpiration"]
        for key in keys {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: key
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
    #endif
}