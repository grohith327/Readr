//
//  ChatService.swift
//  readr
//
//  Created by Rohith Gandhi  on 7/24/25.
//

import Foundation

let systemPrompt = """
You are Readr, a smart, friendly, and knowledgeable assistant integrated into a PDF reading application.

Your primary goal is to help users interact intelligently with the contents of their open PDF documents, and also to act as a 
general-purpose assistant when the user’s question isn’t related to the PDF. 

## PDF Context Awareness
- If the user’s question seems to relate to the PDF file (e.g., referring to sections, content, summaries, analysis, terminology, etc.), 
use the context (<pdfContext> or >) from the PDF provided below.
- Be explicit when your answer is based on the document vs. when it is based on general knowledge.

- If the user’s question relates to the PDF file (e.g., asking about specific sections, summaries, terminology, etc.), use the 
provided context (`<context>`) to answer accurately.
- Prioritize `<context>` when available, as it indicates what the user is focused on.
- Clearly distinguish when your answer is based on the document vs. when it is based on general knowledge.

## Guidance for PDF-based Questions
- Offer helpful summaries, definitions, or explanations of sections or terms in the document.
- You may suggest follow-up questions or insights related to the document’s subject matter.
- If the user is vague (e.g., “Can you help me with this?”), try to clarify whether they are referring to the PDF or something else.

## General-Purpose Assistance
- If the user’s question has no clear relation to the PDF, switch seamlessly into a general-purpose assistant role.
- You can help with writing, coding, learning, brainstorming, and general problem solving.

## Tone & Communication Style
- Be warm, concise, and professional.
- Encourage curiosity and guide users toward clarity.
- If you need to ask clarifying questions, keep them brief and purposeful.
"""

class ChatService: NSObject, ObservableObject, URLSessionDataDelegate {
    @Published var streamedText = ""
    
    private var dataTask: URLSessionDataTask?
    private var onReceiveChunk: ((String) -> Void)?
    
    func sendMessageStream(
        messages chatMessages: [ChatMessage],
        apiKey: String,
        provider: AIProvider,
        onChunk: @escaping (String) -> Void) {

        streamedText = ""
        self.onReceiveChunk = onChunk
        
        let baseURL: String
        let model: String

        switch provider {
        case .OpenAI:
            baseURL = "https://api.openai.com/v1/chat/completions"
            model = "gpt-4o"
        case .Anthropic:
            baseURL = "https://api.anthropic.com/v1/messages"
            model = "claude-sonnet-4-20250514"
        }

        guard let url = URL(string: baseURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any]

        switch provider {
        case .OpenAI:
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            var messages: [[String: String]] = [
                ["role": "system", "content": systemPrompt]
            ]

            for msg in chatMessages {
                var content: String = msg.text
                if (msg.context?.isEmpty == false) {
                    content += "\n<context>\(msg.context ?? "")\n</context>"
                }
                messages.append([
                    "role": msg.isUser ? "user" : "assistant",
                    "content": content
                ])
            }

            payload = [
                "model": model,
                "messages": messages,
                "stream": true
            ]

        case .Anthropic:
            request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

            var messages: [[String: String]] = []

            // Ensure messages start with user and alternate properly
            var lastRole = ""
            for msg in chatMessages {
                let currentRole = msg.isUser ? "user" : "assistant"

                // Skip consecutive messages from same role to maintain alternation
                if currentRole == lastRole {
                    continue
                }

                var content: String = msg.text
                if (msg.context?.isEmpty == false) {
                    content += "\n<context>\(msg.context ?? "")\n</context>"
                }
                messages.append([
                    "role": currentRole,
                    "content": content
                ])
                lastRole = currentRole
            }

            // Ensure we have at least one message and it starts with user
            if messages.isEmpty || messages.first?["role"] != "user" {
                messages.insert(["role": "user", "content": "Hello"], at: 0)
            }

            payload = [
                "model": model,
                "messages": messages,
                "system": systemPrompt,
                "max_tokens": 4096,
                "stream": true
            ]
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return
        }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let raw = String(data: data, encoding: .utf8) else { return }

        let lines = raw.components(separatedBy: "\n")
        for line in lines {
            guard line.starts(with: "data: ") else { continue }
            let jsonLine = line.dropFirst(6)
            if jsonLine == "[DONE]" { return }

            guard let jsonData = jsonLine.data(using: .utf8) else { continue }
            do {
                if let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    var content: String?

                    // Handle OpenAI format
                    if let choices = dict["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any] {
                        content = delta["content"] as? String
                    }
                    // Handle Anthropic format
                    else if dict["type"] as? String == "content_block_delta",
                            let deltaDict = dict["delta"] as? [String: Any] {
                        content = deltaDict["text"] as? String
                    }

                    if let content = content {
                        DispatchQueue.main.async {
                            self.streamedText += content
                            self.onReceiveChunk?(content)
                        }
                    }
                }
            } catch {
                continue
            }
        }
    }

}
