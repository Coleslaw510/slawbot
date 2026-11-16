import Foundation
import Combine

@MainActor
final class ConversationListViewModel: ObservableObject {
    @Published private(set) var conversations: [ConversationSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isConnected = false
    @Published private(set) var nextPageID: String?
    @Published var errorMessage: String?

    private var lastLoadedRevision: Int?

    func load(settings: AppSettings) async {
        guard settings.isConfigured else {
            conversations = []
            nextPageID = nil
            isConnected = false
            isLoading = false
            errorMessage = nil
            lastLoadedRevision = settings.revision
            return
        }
        guard !isLoading else { return }
        if lastLoadedRevision != settings.revision {
            conversations = []
            nextPageID = nil
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let client = try settings.makeClient()
            let page = try await client.searchConversations()
            conversations = page.items.sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
            nextPageID = page.nextPageId
            lastLoadedRevision = settings.revision
            isConnected = true
            errorMessage = nil
        } catch {
            isConnected = false
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(settings: AppSettings) async {
        guard settings.isConfigured, !isLoading, let pageID = nextPageID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try settings.makeClient()
            let page = try await client.searchConversations(pageID: pageID)
            conversations.append(contentsOf: page.items.sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") })
            nextPageID = page.nextPageId
            isConnected = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
