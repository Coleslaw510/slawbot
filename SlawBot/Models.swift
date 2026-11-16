import Foundation

struct ConversationPage: Decodable {
    let items: [ConversationSummary]
    let nextPageId: String?
}

struct ConversationSummary: Decodable, Hashable, Identifiable {
    let id: String
    let title: String?
    let selectedRepository: String?
    let selectedBranch: String?
    let sandboxStatus: String?
    let executionStatus: String?
    let updatedAt: String?

    var displayTitle: String {
        let value = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Untitled conversation" : value
    }

    var repositoryLabel: String? {
        guard let selectedRepository, !selectedRepository.isEmpty else { return nil }
        if let selectedBranch, !selectedBranch.isEmpty {
            return "\(selectedRepository) · \(selectedBranch)"
        }
        return selectedRepository
    }

    init(id: String, title: String?, selectedRepository: String?, selectedBranch: String?, sandboxStatus: String? = nil, executionStatus: String? = nil, updatedAt: String? = nil) {
        self.id = id
        self.title = title
        self.selectedRepository = selectedRepository
        self.selectedBranch = selectedBranch
        self.sandboxStatus = sandboxStatus
        self.executionStatus = executionStatus
        self.updatedAt = updatedAt
    }
}

struct StartTask: Decodable {
    let id: String?
    let status: String?
    let detail: String?
    let appConversationId: String?
}

struct OpenAPIEnvelope: Decodable {
    let info: OpenAPIInfo
}

struct OpenAPIInfo: Decodable {
    let title: String?
    let version: String?
}

struct EventPage: Decodable {
    let items: [OpenHandsEvent]
    let nextPageId: String?
}

struct OpenHandsEvent: Decodable {
    let id: String?
    let kind: String?
    let timestamp: String?
    let source: String?
    let llmMessage: OpenHandsMessage?
}

struct OpenHandsMessage: Decodable {
    let role: String?
    let content: [MessageContentBlock]?
}

struct MessageContentBlock: Decodable {
    let type: String?
    let text: String?
    let imageUrls: [String]?
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let role: String
    let text: String
    let timestamp: String?

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }

    static func from(_ event: OpenHandsEvent) -> ChatMessage? {
        guard event.kind == "MessageEvent", let message = event.llmMessage else { return nil }
        let role = message.role ?? (event.source == "user" ? "user" : "assistant")
        guard role == "user" || role == "assistant" else { return nil }
        let text = (message.content ?? []).compactMap { block -> String? in
            if block.type == "text" { return block.text }
            if block.type == "image" { return "[Image]" }
            return nil
        }.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let fallbackID = "\(event.timestamp ?? "event")-\(role)-\(text.hashValue)"
        return ChatMessage(id: event.id ?? fallbackID, role: role, text: text, timestamp: event.timestamp)
    }
}
