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
    static let account = "OpenAIKey"

    static func saveKey(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }

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

    static func retrieveKey() -> String? {
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
           let key = String(data: data, encoding: .utf8) {
            return key
        }
        return nil
    }
}
