import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    @Published private(set) var serverURL: String
    @Published private(set) var defaultRepository: String
    @Published private(set) var defaultBranch: String
    @Published private(set) var accessToken: String
    @Published private(set) var revision = 0

    private enum Keys {
        static let serverURL = "slawbot.serverURL"
        static let repository = "slawbot.defaultRepository"
        static let branch = "slawbot.defaultBranch"
    }

    init() {
        serverURL = UserDefaults.standard.string(forKey: Keys.serverURL) ?? ""
        defaultRepository = UserDefaults.standard.string(forKey: Keys.repository) ?? ""
        defaultBranch = UserDefaults.standard.string(forKey: Keys.branch) ?? "main"
        accessToken = KeychainStore.readAccessToken()
    }

    var isConfigured: Bool { ServerURLValidator.parse(serverURL) != nil }

    @discardableResult
    func save(serverURL: String, repository: String, branch: String, accessToken: String) -> Bool {
        let normalizedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedRepository = repository.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard KeychainStore.saveAccessToken(accessToken) else { return false }

        self.serverURL = normalizedURL
        self.defaultRepository = normalizedRepository
        self.defaultBranch = normalizedBranch.isEmpty ? "main" : normalizedBranch
        self.accessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(self.serverURL, forKey: Keys.serverURL)
        UserDefaults.standard.set(self.defaultRepository, forKey: Keys.repository)
        UserDefaults.standard.set(self.defaultBranch, forKey: Keys.branch)
        revision += 1
        return true
    }

    func makeClient() throws -> OpenHandsAPIClient {
        guard let url = ServerURLValidator.parse(serverURL) else { throw APIError.invalidServerURL }
        return OpenHandsAPIClient(baseURL: url, accessToken: accessToken)
    }
}
