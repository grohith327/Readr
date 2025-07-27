//
//  ChatService.swift
//  readr
//
//  Created by Rohith Gandhi  on 7/24/25.
//

import Foundation

class ChatService: NSObject, ObservableObject, URLSessionDataDelegate {
    @Published var streamedText = ""
    
    private var dataTask: URLSessionDataTask?
    private var buffer = Data()
    private var onReceiveChunk: ((String) -> Void)?
    
    func sendMessageStream(
        _ message: String,
        apiKey: String,
        firstFewPages: String,
        pageCount: Int,
        selectedContext: String?,
        onChunk: @escaping (String) -> Void) {
        
        streamedText = ""
        self.onReceiveChunk = onChunk
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }
        
        let summaryKeywords = ["summary", "summarize", "overview"]
        let messageLowercased = message.lowercased()

        let shouldInjectContext = summaryKeywords.contains { messageLowercased.contains($0) }

        var systemPrompt = "You are a helpful assistant."
        if let context = selectedContext {
            systemPrompt += " The user has selected the following context: \"\(context)\""
        }
        if shouldInjectContext {
            systemPrompt += " Here is the content of the document: \(firstFewPages.prefix(3000))"
        }

        var messages: [[String: String]] = []
        messages.append(["role": "system", "content": systemPrompt])
        messages.append(["role": "user", "content": message])
            
        print("messages: \(messages)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": "gpt-4",
            "messages": messages,
            "stream": true
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Failed to encode payload")
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
                if let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let choices = dict["choices"] as? [[String: Any]],
                   let delta = choices.first?["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    
                    DispatchQueue.main.async {
                        self.streamedText += content
                        self.onReceiveChunk?(content)
                    }
                }
            } catch {
                print("JSON decode error: \(error)")
            }
        }
    }
}
