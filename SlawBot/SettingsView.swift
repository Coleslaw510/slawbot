import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var serverURL = ""
    @State private var accessToken = ""
    @State private var repository = ""
    @State private var branch = "main"
    @State private var isTesting = false
    @State private var connectionMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                SlawPalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Your server, your rules.")
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .foregroundStyle(SlawPalette.text)
                            Text("SlawBot connects directly to your self-hosted OpenHands server. Keep your iPhone on the same Tailscale network.")
                                .font(.system(size: 14))
                                .foregroundStyle(SlawPalette.muted)
                                .lineSpacing(4)
                        }

                        settingsField("OPENHANDS URL", hint: "http://100.x.y.z:3000") {
                            TextField("http://100.x.y.z:3000", text: $serverURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        Text("Use your VPS’s Tailscale IP and OpenHands port. HTTP is accepted only for Tailscale IPv4 addresses; HTTPS also works.")
                            .font(.system(size: 12))
                            .foregroundStyle(SlawPalette.muted)
                            .padding(.top, -16)

                        settingsField("ACCESS TOKEN · OPTIONAL", hint: "Stored only in iOS Keychain") {
                            SecureField("Access token", text: $accessToken)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            Text("DEFAULT REPOSITORY · OPTIONAL")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.35)
                                .foregroundStyle(SlawPalette.muted)
                            TextField("owner/repository", text: $repository)
                                .font(.system(size: 14, design: .monospaced))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(SlawPalette.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(SlawPalette.outline, lineWidth: 1))
                            TextField("Default branch", text: $branch)
                                .font(.system(size: 14, design: .monospaced))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(SlawPalette.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(SlawPalette.outline, lineWidth: 1))
                        }

                        Button { Task { await testConnection() } } label: {
                            HStack(spacing: 9) {
                                if isTesting { ProgressView().tint(SlawPalette.mint) }
                                else { Image(systemName: "antenna.radiowaves.left.and.right") }
                                Text(isTesting ? "Testing connection…" : "Test connection")
                            }
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(SlawPalette.mint)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(SlawPalette.mint.opacity(0.09), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(SlawPalette.mint.opacity(0.22), lineWidth: 1))
                        }
                        .disabled(isTesting)

                        if let connectionMessage {
                            Label(connectionMessage, systemImage: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(SlawPalette.mint)
                        }
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(SlawPalette.warning)
                                .lineLimit(4)
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock.shield.fill").foregroundStyle(SlawPalette.mint)
                            Text("The access token is stored in iOS Keychain. Server address and repository preferences stay on this iPhone. SlawBot has no telemetry or proxy; OpenHands may forward prompts to its configured model provider.")
                                .font(.system(size: 12))
                                .foregroundStyle(SlawPalette.muted)
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .background(SlawPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(SlawPalette.muted)
                }
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.7).foregroundStyle(SlawPalette.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(SlawPalette.mint)
                }
            }
            .toolbarBackground(SlawPalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .tint(SlawPalette.mint)
        .onAppear {
            serverURL = settings.serverURL
            accessToken = settings.accessToken
            repository = settings.defaultRepository
            branch = settings.defaultBranch
        }
    }

    private func settingsField<Content: View>(_ title: String, hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.35)
                    .foregroundStyle(SlawPalette.muted)
                Spacer()
                Text(hint)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SlawPalette.muted.opacity(0.8))
            }
            content()
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(SlawPalette.text)
                .padding(14)
                .background(SlawPalette.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(SlawPalette.outline, lineWidth: 1))
        }
    }

    private func save() {
        guard serverURL.isEmpty || ServerURLValidator.parse(serverURL) != nil else {
            errorMessage = "Enter an HTTPS URL or an HTTP Tailscale IPv4 URL in the 100.64.0.0/10 range."
            return
        }
        guard settings.save(serverURL: serverURL, repository: repository, branch: branch, accessToken: accessToken) else {
            errorMessage = "The access token could not be saved to Keychain."
            return
        }
        dismiss()
    }

    private func testConnection() async {
        connectionMessage = nil
        errorMessage = nil
        guard let url = ServerURLValidator.parse(serverURL) else {
            errorMessage = "Enter a valid HTTPS URL or HTTP Tailscale IPv4 URL first."
            return
        }
        isTesting = true
        defer { isTesting = false }
        do {
            let client = OpenHandsAPIClient(baseURL: url, accessToken: accessToken.trimmingCharacters(in: .whitespacesAndNewlines))
            connectionMessage = "Connected · \(try await client.checkConnection())"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
