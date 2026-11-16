import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var model = ConversationListViewModel()
    @State private var showingSettings = false
    @State private var showingNewConversation = false
    @State private var selectedConversation: ConversationSummary?

    var body: some View {
        NavigationStack {
            ZStack {
                SlawPalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        if !settings.isConfigured {
                            connectCard
                        } else {
                            if let error = model.errorMessage {
                                errorCard(error)
                            }
                            if model.conversations.isEmpty && model.isLoading {
                                loadingState
                            } else if model.conversations.isEmpty {
                                emptyState
                            } else {
                                conversationList
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
                .refreshable { await model.load(settings: settings) }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if settings.isConfigured {
                    newConversationButton
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatView(conversation: conversation)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingNewConversation) {
                NewConversationView { conversation in
                    selectedConversation = conversation
                    Task { await model.load(settings: settings) }
                }
            }
            .task(id: settings.revision) {
                await model.load(settings: settings)
            }
        }
        .tint(SlawPalette.mint)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 13) {
            SlawMark(size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text("SlawBot")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(SlawPalette.text)
                Text("YOUR OPENHANDS WORKSPACE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.7)
                    .foregroundStyle(SlawPalette.muted)
            }
            Spacer(minLength: 8)
            Button { showingSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SlawPalette.text)
                    .frame(width: 44, height: 44)
                    .background(SlawPalette.surface, in: Circle())
                    .overlay(Circle().stroke(SlawPalette.outline, lineWidth: 1))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.bottom, 5)
    }

    private var connectCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(SlawPalette.mint)
                    Spacer()
                    StatusBadge(title: "Private link", tint: SlawPalette.mint)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("Your agent, on your own server.")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(SlawPalette.text)
                    Text("Connect through Tailscale to your OpenHands instance. Messages go to your VPS first; OpenHands uses the model provider configured there.")
                        .font(.system(size: 15))
                        .foregroundStyle(SlawPalette.muted)
                        .lineSpacing(4)
                }
                Button { showingSettings = true } label: {
                    HStack {
                        Text("Connect OpenHands")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(SlawPalette.background)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(SlawPalette.mint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(.top, 8)
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView().tint(SlawPalette.mint)
            Text("Reaching your OpenHands server…")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SlawPalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 48)
    }

    private var emptyState: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle().fill(SlawPalette.elevated).frame(width: 86, height: 86)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(SlawPalette.mint)
            }
            Text("A clean slate.")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(SlawPalette.text)
            Text("Start a conversation with your OpenHands agent. Pick a repository, describe the task, and let it get to work.")
                .font(.system(size: 15))
                .foregroundStyle(SlawPalette.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 310)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 54)
    }

    private var conversationList: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("RECENT WORK")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.7)
                    .foregroundStyle(SlawPalette.muted)
                Spacer()
                if model.isConnected { StatusBadge(title: "Connected") }
                Button {
                    Task { await model.load(settings: settings) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SlawPalette.muted)
                        .frame(width: 34, height: 34)
                        .background(SlawPalette.surface, in: Circle())
                }
                .accessibilityLabel("Refresh conversations")
            }
            ForEach(model.conversations) { conversation in
                Button { selectedConversation = conversation } label: {
                    ConversationCard(conversation: conversation)
                }
                .buttonStyle(.plain)
            }
            if model.nextPageID != nil {
                Button {
                    Task { await model.loadMore(settings: settings) }
                } label: {
                    HStack(spacing: 8) {
                        if model.isLoading { ProgressView().tint(SlawPalette.mint) }
                        Text(model.isLoading ? "Loading…" : "Load older conversations")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(SlawPalette.mint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .disabled(model.isLoading)
            }
        }
        .padding(.top, 7)
    }

    private func errorCard(_ message: String) -> some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(SlawPalette.warning)
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection needs attention")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(SlawPalette.text)
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(SlawPalette.muted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var newConversationButton: some View {
        Button { showingNewConversation = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("New task")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Text("OPENHANDS")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .opacity(0.72)
            }
            .foregroundStyle(SlawPalette.background)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(LinearGradient(colors: [SlawPalette.mint, Color(hex: 0xB5F0D0)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

private struct ConversationCard: View {
    let conversation: ConversationSummary

    private var status: (String, Color) {
        switch conversation.sandboxStatus?.uppercased() {
        case "RUNNING": return ("RUNNING", SlawPalette.mint)
        case "STARTING": return ("STARTING", SlawPalette.warning)
        case "PAUSED": return ("PAUSED", SlawPalette.warning)
        case "ERROR", "MISSING": return ("CHECK", SlawPalette.danger)
        default: return ("OPEN", SlawPalette.muted)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous).fill(SlawPalette.elevated)
                Image(systemName: "terminal.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(SlawPalette.mint)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text(conversation.displayTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(SlawPalette.text)
                    .lineLimit(1)
                if let repository = conversation.repositoryLabel {
                    Text(repository)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(SlawPalette.muted)
                        .lineLimit(1)
                } else {
                    Text("OpenHands conversation")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SlawPalette.muted)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 8) {
                Circle().fill(status.1).frame(width: 7, height: 7)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(SlawPalette.muted.opacity(0.7))
            }
        }
        .padding(14)
        .background(SlawPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(SlawPalette.outline, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
