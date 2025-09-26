//
//  ChatPanel.swift
//  readr
//
//  Created by Rohith Gandhi  on 7/24/25.
//

import SwiftUI

struct MultilineText: View {
    let text: String
    let isMarkdown: Bool

    init(_ text: String, isMarkdown: Bool = false) {
        self.text = text
        self.isMarkdown = isMarkdown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(text.components(separatedBy: "\n"), id: \.self) { line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(" ")
                        .font(.body)
                } else {
                    if isMarkdown, let attributed = try? AttributedString(markdown: line) {
                        Text(attributed)
                            .font(.body)
                    } else {
                        Text(line)
                            .font(.body)
                    }
                }
            }
        }
    }
}

struct ChatPanel: View {
    @Binding var chatMessages: [ChatMessage]
    @Binding var newMessage: String
    @Binding var isLoading: Bool
    @Binding var selectedContext: String?
    @Binding var openAIKey: String
    @Binding var anthropicKey: String
    @Binding var selectedProvider: AIProvider
    var sendMessage: () -> Void
    
    private var currentKey: String {
        switch selectedProvider {
        case .OpenAI:
            return openAIKey
        case .Anthropic:
            return anthropicKey
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if currentKey.isEmpty {
                Spacer()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Please provide a \(selectedProvider.displayName) API key to continue.")
                        .foregroundColor(.red)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
                Spacer()
            } else if chatMessages.isEmpty {
                Spacer()
                Text("")
                    .foregroundColor(.secondary)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(chatMessages) { message in
                                HStack {
                                    if message.isUser {
                                        Spacer()
                                        MultilineText(message.text)
                                            .padding(12)
                                            .background(Color.accentColor.opacity(0.15))
                                            .cornerRadius(16)
                                            .frame(maxWidth: 300, alignment: .trailing)
                                    } else {
                                        MultilineText(message.text, isMarkdown: true)
                                            .padding(12)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(16)
                                            .frame(maxWidth: 300, alignment: .leading)
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal)
                                .id(message.id)
                            }
                            
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: chatMessages.last?.text) {
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Divider()

            if let context = selectedContext {
                HStack {
                    Text("📎 Context: \"\(context.prefix(50))…\"")
                        .font(.footnote)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)

                    Button(action: { selectedContext = nil }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            
            HStack(spacing: 10) {
                ZStack(alignment: .trailing) {
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
                        .disabled(currentKey.isEmpty)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .padding(.trailing, 16)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    
}
