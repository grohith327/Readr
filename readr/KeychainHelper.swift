//
//  KeychainHelper.swift
//  readr
//
//  Created by Rohith Gandhi  on 7/24/25.
//

import Foundation
import Security

struct KeychainHelper {
    static let service = "com.altic.readr"
    static let account = "APIKeys"

    struct APIKeys: Codable {
        var OpenAIKey: String?
        var AnthropicKey: String?
    }

    static func saveKeys(_ keys: APIKeys) {
        guard let data = try? JSONEncoder().encode(keys) else { return }

        // Delete any existing item
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary
        SecItemDelete(query)

        // Add new item
        let attributes = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ] as CFDictionary
        SecItemAdd(attributes, nil)
    }

    static func retrieveKeys() -> APIKeys? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ] as CFDictionary

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query, &dataTypeRef)

        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let keys = try? JSONDecoder().decode(APIKeys.self, from: data) {
            return keys
        }
        return nil
    }

    static func saveKey(_ key: String, for provider: AIProvider) {
        var currentKeys = retrieveKeys() ?? APIKeys()

        switch provider {
        case .OpenAI:
            currentKeys.OpenAIKey = key
        case .Anthropic:
            currentKeys.AnthropicKey = key
        }

        saveKeys(currentKeys)
    }

    static func retrieveKey(for provider: AIProvider) -> String? {
        guard let keys = retrieveKeys() else { return nil }

        switch provider {
        case .OpenAI:
            return keys.OpenAIKey
        case .Anthropic:
            return keys.AnthropicKey
        }
    }
}
