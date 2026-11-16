import Foundation

struct OpenHandsAPIClient {
    let baseURL: URL
    let accessToken: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private static let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
    }()

    init(baseURL: URL, accessToken: String = "") {
        self.baseURL = baseURL
        self.accessToken = accessToken
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder
    }

    func checkConnection() async throws -> String {
        let response: OpenAPIEnvelope = try await get("openapi.json")
        return response.info.version.map { "OpenHands \($0)" } ?? (response.info.title ?? "OpenHands is reachable")
    }

    func searchConversations(pageID: String? = nil) async throws -> ConversationPage {
        var query = [
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "include_sub_conversations", value: "false")
        ]
        if let pageID { query.append(URLQueryItem(name: "page_id", value: pageID)) }
        return try await get("api/v1/app-conversations/search", query: query)
    }

    func createConversation(prompt: String, repository: String?, branch: String?) async throws -> StartTask {
        let initialMessage = SendMessagePayload(
            role: "user",
            content: [MessageContentPayload(type: "text", text: prompt)],
            run: true
        )
        let payload = StartConversationPayload(
            initialMessage: initialMessage,
            selectedRepository: nonEmpty(repository),
            selectedBranch: nonEmpty(branch)
        )
        return try await post("api/v1/app-conversations", body: payload)
    }

    func fetchStartTask(id: String) async throws -> StartTask? {
        let tasks: [StartTask?] = try await get("api/v1/app-conversations/start-tasks", query: [
            URLQueryItem(name: "ids", value: id)
        ])
        return tasks.first ?? nil
    }

    func fetchConversation(id: String) async throws -> ConversationSummary? {
        let conversations: [ConversationSummary?] = try await get("api/v1/app-conversations", query: [
            URLQueryItem(name: "ids", value: id)
        ])
        return conversations.first ?? nil
    }

    func sendMessage(conversationID: String, text: String) async throws {
        let payload = SendMessagePayload(
            role: "user",
            content: [MessageContentPayload(type: "text", text: text)],
            run: true
        )
        let response: SendMessageResponse = try await post("api/v1/app-conversations/\(conversationID)/send-message", body: payload)
        guard response.success else {
            let status = response.sandboxStatus ?? "unknown"
            throw APIError.messageNotAccepted(response.message ?? "OpenHands did not accept the message (sandbox status: \(status)).")
        }
    }

    func fetchMessages(conversationID: String) async throws -> [ChatMessage] {
        let page: EventPage = try await get("api/v1/conversation/\(conversationID)/events/search", query: [
            URLQueryItem(name: "kind__eq", value: "MessageEvent"),
            URLQueryItem(name: "sort_order", value: "TIMESTAMP_DESC"),
            URLQueryItem(name: "limit", value: "100")
        ])
        return Array(page.items.compactMap(ChatMessage.from).reversed())
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await perform(path, method: "GET", query: query, body: nil)
    }

    private func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        let data: Data
        do {
            data = try encoder.encode(body)
        } catch {
            throw APIError.encoding
        }
        return try await perform(path, method: "POST", query: [], body: data)
    }

    private func perform<Response: Decodable>(_ path: String, method: String, query: [URLQueryItem], body: Data?) async throws -> Response {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        guard components != nil else { throw APIError.invalidServerURL }
        let basePath = (components?.path ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components?.path = "/" + [basePath, endpointPath].filter { !$0.isEmpty }.joined(separator: "/")
        components?.queryItems = query.isEmpty ? nil : query
        components?.fragment = nil
        guard let url = components?.url else { throw APIError.invalidServerURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if path.hasPrefix("api/v1/"), !accessToken.isEmpty {
            request.setValue(accessToken, forHTTPHeaderField: "X-Access-Token")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await Self.urlSession.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.httpStatus(http.statusCode) }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.unreadableResponse
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct StartConversationPayload: Encodable {
    let initialMessage: SendMessagePayload
    let selectedRepository: String?
    let selectedBranch: String?
}

private struct SendMessagePayload: Encodable {
    let role: String
    let content: [MessageContentPayload]
    let run: Bool
}

private struct MessageContentPayload: Encodable {
    let type: String
    let text: String
}

private struct SendMessageResponse: Decodable {
    let success: Bool
    let sandboxStatus: String?
    let message: String?
}

private final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

enum APIError: LocalizedError {
    case invalidServerURL
    case invalidResponse
    case encoding
    case unreadableResponse
    case httpStatus(Int)
    case transport(String)
    case messageNotAccepted(String)
    case startTaskFailed(String)
    case startTaskTimedOut

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Enter an HTTPS server URL, or an HTTP Tailscale IPv4 address in the 100.64.0.0/10 range."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .encoding:
            return "SlawBot could not prepare the request."
        case .unreadableResponse:
            return "The server response could not be read. Confirm this is your OpenHands App Server."
        case .httpStatus(let code):
            return "OpenHands returned HTTP \(code). Check the server URL and optional access token."
        case .transport(let message):
            return "Could not reach OpenHands: \(message)"
        case .messageNotAccepted(let detail):
            return detail
        case .startTaskFailed(let detail):
            return detail.isEmpty ? "OpenHands could not start the conversation." : detail
        case .startTaskTimedOut:
            return "OpenHands is still preparing the workspace. Check the OpenHands web UI and try again."
        }
    }
}
