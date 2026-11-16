import Foundation

enum ServerURLValidator {
    static func parse(_ rawValue: String) -> URL? {
        let cleaned = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !cleaned.isEmpty,
              var components = URLComponents(string: cleaned),
              let schemeValue = components.scheme?.lowercased(),
              let hostValue = components.host?.lowercased(),
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              schemeValue == "https" || schemeValue == "http" else {
            return nil
        }

        if schemeValue == "http" && !isTailscaleIPv4(hostValue) {
            return nil
        }
        components.scheme = schemeValue
        return components.url
    }

    private static func isTailscaleIPv4(_ host: String) -> Bool {
        let octets = host.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets[0] == 100, (64...127).contains(octets[1]) else { return false }
        return octets.allSatisfy { (0...255).contains($0) }
    }
}
