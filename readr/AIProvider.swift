//
//  AIProvider.swift
//  readr
//
//  Created by Rohith Gandhi  on 8/23/25.
//

import Foundation

enum AIProvider: String, CaseIterable {
    case OpenAI = "OpenAI"
    case Anthropic = "Anthropic"

    var displayName: String {
        switch self {
        case .OpenAI:
            return "OpenAI"
        case .Anthropic:
            return "Anthropic"
        }
    }
}

