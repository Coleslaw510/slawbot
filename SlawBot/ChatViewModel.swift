import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var pendingMessage: ChatMessage?
    @Published private(set) var isLoading = true
    @Published private(set) var isWaitingForReply = false
    @Published var errorMessage: String?

    private let conversationID: String
    private var pendingMessageSentAt: Date?
    private var pollingTask: Task<Void, Never>?

    init(conversationID: String, isRunning: Bool = false) {
        self.conversationID = conversationID
        self.isWaitingForReply = isRunning
    }

    func refresh(settings: AppSettings) async {
        do {
            let client = try settings.makeClient()
            let updated = try await client.fetchMessages(conversationID: conversationID)
            let previousAssistantIDs = Set(messages.filter(\.isAssistant).map(\.id))
            if isWaitingForReply,
               updated.contains(where: { $0.isAssistant && !previousAssistantIDs.contains($0.id) }) {
                isWaitingForReply = false
            }
            if let pendingMessage, let sentAt = pendingMessageSentAt,
               updated.contains(where: { matchesPending($0, pending: pendingMessage, sentAt: sentAt) }) {
                self.pendingMessage = nil
                pendingMessageSentAt = nil
            }
            messages = updated
            isLoading = false
            errorMessage = nil
        } catch {
            isLoading = false
            if errorMessage == nil { errorMessage = error.localizedDescription }
        }
    }

    func send(_ text: String, settings: AppSettings) async -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !isWaitingForReply else { return false }

        let sentAt = Date()
        pendingMessageSentAt = sentAt
        pendingMessage = ChatMessage(
            id: "local-\(UUID().uuidString)",
            role: "user",
            text: cleaned,
            timestamp: ISO8601DateFormatter().string(from: sentAt)
        )
        isWaitingForReply = true
        errorMessage = nil

        do {
            let client = try settings.makeClient()
            try await client.sendMessage(conversationID: conversationID, text: cleaned)
            await refresh(settings: settings)
            return true
        } catch {
            isWaitingForReply = false
            pendingMessage = nil
            pendingMessageSentAt = nil
            errorMessage = error.localizedDescription
            return false
        }
    }

    func startPolling(settings: AppSettings) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { return }
                await self.refresh(settings: settings)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func matchesPending(_ message: ChatMessage, pending: ChatMessage, sentAt: Date) -> Bool {
        guard message.isUser, message.text == pending.text, let timestamp = message.timestamp else { return false }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = fractional.date(from: timestamp) ?? ISO8601DateFormatter().date(from: timestamp)
        return date.map { $0 >= sentAt.addingTimeInterval(-10) } ?? false
    }
}
