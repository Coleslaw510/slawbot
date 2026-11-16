import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isWaitingForReply = false
    @Published var errorMessage: String?

    private let conversationID: String
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
            messages = updated
            isLoading = false
            errorMessage = nil
        } catch {
            isLoading = false
            if errorMessage == nil { errorMessage = error.localizedDescription }
        }
    }

    func send(_ text: String, settings: AppSettings) async {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !isWaitingForReply else { return }
        isWaitingForReply = true
        errorMessage = nil
        do {
            let client = try settings.makeClient()
            try await client.sendMessage(conversationID: conversationID, text: cleaned)
            await refresh(settings: settings)
        } catch {
            isWaitingForReply = false
            errorMessage = error.localizedDescription
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
}
