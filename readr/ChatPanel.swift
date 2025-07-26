//
//  ChatPanel.swift
//  readr
//
//  Created by Rohith Gandhi  on 7/24/25.
//

import SwiftUI

struct ChatPanel: View {
    @Binding var chatMessages: [ChatMessage]
    @Binding var newMessage: String
    @Binding var isLoading: Bool
    var sendMessage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if chatMessages.isEmpty {
                Spacer()
                Text("")
                    .foregroundColor(.secondary)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(chatMessages) { message in
                            HStack {
                                if message.isUser {
                                    Spacer()
                                    Text(message.text)
                                        .padding(12)
                                        .background(Color.accentColor.opacity(0.15))
                                        .cornerRadius(16)
                                        .frame(maxWidth: 300, alignment: .trailing)
                                } else {
                                    if let atrributed = try? AttributedString(markdown: message.text) {
                                        Text(atrributed)
                                            .padding(12)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(16)
                                            .frame(maxWidth: 300, alignment: .leading)
                                    } else {
                                        Text(message.text)
                                            .padding(12)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(16)
                                            .frame(maxWidth: 300, alignment: .leading)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }

            Divider()

            HStack(spacing: 10) {
                TextField("Type your question…", text: $newMessage)
                    .onSubmit {
                        sendMessage()
                    }
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .font(.body)
                    .frame(height: 50)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 12)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    
}
