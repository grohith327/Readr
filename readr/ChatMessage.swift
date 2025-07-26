//
//  ChatMessage.swift
//  readr
//
//  Created by Rohith Gandhi  on 7/24/25.
//

import Foundation

struct ChatMessage: Identifiable {
    var id = UUID()
    var text: String
    var isUser: Bool
}
