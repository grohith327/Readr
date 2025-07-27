//
//  ContentView.swift
//  readr
//
//  Created by Rohith Gandhi  on 7/22/25.
//

import SwiftUI
import PDFKit

struct PDFKitView: NSViewRepresentable {
    @Binding var url: URL?
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        context.coordinator.pdfView = pdfView
        return pdfView
    }
    
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        if let url = url {
            nsView.document = PDFDocument(url: url)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var pdfView: PDFView?
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {
    @objc func openDocument() {
        NotificationCenter.default.post(name: NSNotification.Name("ManualOpenPDF"), object: nil)
    }
    
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        NotificationCenter.default.post(name: NSNotification.Name("ManualOpenPDF"), object: url)
        return true
    }
}

struct PDFKitViewWithReference: NSViewRepresentable {
    @Binding var url: URL?
    @Binding var pdfView: PDFView?

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        DispatchQueue.main.async {
            self.pdfView = view
        }
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if let url = url {
            nsView.document = PDFDocument(url: url)
        } else {
            nsView.document = nil
        }
    }
}

struct ContentView: View {
    @State private var chatMessages: [ChatMessage] = []
    @State private var newMessage: String = ""
    @State private var pdfUrl: URL? = nil
    @State private var pdfView: PDFView? = nil
    @State private var chatWidth: CGFloat = 300
    @State private var docTitle: String = ""
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 0
    @State private var isChatVisible: Bool = true
    @State private var isLoadingResponse: Bool = false
    @State private var openAIKey: String = KeychainHelper.retrieveKey() ?? ""
    @State private var isKeyFieldVisible: Bool = false
    @State private var firstFewPages: String = ""
    @State private var selectedText: String? = nil
    
    @StateObject private var chatService = ChatService()

    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ZStack {
                if pdfUrl == nil {
                    VStack {
                        Spacer()
                        Button("Open PDF", action: openPDF)
                            .controlSize(.large)
                            .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                } else {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            PDFContainerView(url: $pdfUrl, pdfView: $pdfView)
                                .frame(width: geometry.size.width - (isChatVisible ? chatWidth : 0))
                                .layoutPriority(1)

                            if isChatVisible {
                                Divider()
                                    .background(Color.gray.opacity(0.5))
                                    .frame(width: 4)
                                    .gesture(
                                        DragGesture(minimumDistance: 10)
                                            .onChanged { value in
                                                DispatchQueue.main.async {
                                                    let newWidth = chatWidth - value.translation.width
                                                    chatWidth = min(max(newWidth, 200), geometry.size.width * 0.7)
                                                }
                                            }
                                    )
                                    .onHover {
                                        hovering in
                                        if hovering {
                                            NSCursor.resizeLeftRight.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.1))

                               ChatPanel(
                                chatMessages: $chatMessages,
                                newMessage: $newMessage,
                                isLoading: $isLoadingResponse,
                                selectedContext: $selectedText,
                                sendMessage: sendMessage,
                               )
                                    .frame(width: chatWidth)
                                    .transition(.move(edge: .trailing))
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            NSApp.windows.first?.title = "Readr"
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)) { _ in
            addMenuShortcut()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.PDFViewPageChanged, object: pdfView)) { _ in
            updatePageInfo()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ManualOpenPDF"))) { notification in
            if let url = notification.object as? URL {
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
                pdfUrl = url
                setDocumentMeta(from: url)
            } else {
                openPDF()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.PDFViewSelectionChanged, object: pdfView)) { _ in
            selectedText = pdfView?.currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let item = providers.first else { return false }
            _ = item.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url, url.pathExtension.lowercased() == "pdf" else { return }
                DispatchQueue.main.async {
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                    pdfUrl = url
                    setDocumentMeta(from: url)
                }
            }
            return true
        }
    }
    
    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(docTitle)
                    .font(.subheadline)
                    .lineLimit(1)
                if totalPages > 0 {
                    Text("\(currentPage) / \(totalPages)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Spacer()
            if pdfUrl != nil {
                Button(action: {
                    withAnimation {
                        isKeyFieldVisible.toggle()
                    }
                }) {
                    Image(systemName: "key")
                        .imageScale(.large)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal)
                }
                .popover(isPresented: $isKeyFieldVisible) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OpenAI API Key")
                            .font(.headline)
                        SecureField("sk-...", text: $openAIKey, onCommit: {
                            KeychainHelper.saveKey(openAIKey)
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 300)

                        Button("Save") {
                            KeychainHelper.saveKey(openAIKey)
                            isKeyFieldVisible = false
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding()
                    .frame(width: 320)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
                .onHover {
                    hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                
                
                Button(action: {
                    withAnimation {
                        isChatVisible.toggle()
                    }
                }) {
                    Image(systemName: isChatVisible ? "sidebar.trailing" : "sidebar.leading")
                        .imageScale(.large)
                        .foregroundColor(.accentColor)
                        .padding(.leading)
                }
                .buttonStyle(.plain)
                .onHover {
                    hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func openPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let selectedURL = panel.url {
            NSDocumentController.shared.noteNewRecentDocumentURL(selectedURL)
            pdfUrl = selectedURL
            setDocumentMeta(from: selectedURL)
        }
    }

    private func addMenuShortcut() {
        guard let mainMenu = NSApp.mainMenu,
              let fileMenu = mainMenu.item(withTitle: "File")?.submenu,
              fileMenu.item(withTitle: "Open") == nil,
              let appDelegate = NSApp.delegate as? AppDelegate else {
            return
        }

        let openItem = NSMenuItem(title: "Open", action: #selector(AppDelegate.openDocument), keyEquivalent: "o")
        openItem.target = appDelegate
        fileMenu.addItem(openItem)
    }
    
    
    private func updatePageInfo() {
        guard let pdfView = pdfView, let doc = pdfView.document else { return }
        if let page = pdfView.currentPage {
            currentPage = doc.index(for: page) + 1
        }
        totalPages = doc.pageCount
    }

    private func setDocumentMeta(from url: URL) {
        docTitle = url.lastPathComponent
        // wait for PDFView to load the document before reading counts
        DispatchQueue.main.async {
            updatePageInfo()
            extractFirstFewPagesText(from: url)
        }
    }
    
    private func sendMessage() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMessage = ChatMessage(text: trimmed, isUser: true)
        chatMessages.append(userMessage)
        newMessage = ""

        let placeholderID = UUID()
        chatMessages.append(ChatMessage(id: placeholderID, text: "", isUser: false))
        
        chatService.sendMessageStream(
            trimmed,
            apiKey: openAIKey,
            firstFewPages: firstFewPages,
            pageCount: pdfView?.document?.pageCount ?? 0,
            selectedContext: selectedText) { chunk in
            if let index = chatMessages.firstIndex(where: { $0.id == placeholderID }) {
                chatMessages[index].text += chunk
            }
        }
    }
    
    private func extractFirstFewPagesText(from url: URL, maxPages: Int = 5) {
        guard let pdf = PDFDocument(url: url) else {
            return
        }

        let endPage = min(maxPages, pdf.pageCount)
        var text = ""

        for i in 0..<endPage {
            if let pageText = pdf.page(at: i)?.string {
                text += pageText + "\n\n"
            }
        }

        firstFewPages = text
    }
}

#Preview {
    ContentView()
}
