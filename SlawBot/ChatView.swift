import SwiftUI

struct ChatView: View {
    let conversation: ConversationSummary
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ChatViewModel
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    init(conversation: ConversationSummary) {
        self.conversation = conversation
        _model = StateObject(wrappedValue: ChatViewModel(conversationID: conversation.id, isRunning: conversation.executionStatus?.lowercased() == "running"))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let error = model.errorMessage {
                errorBanner(error)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if model.messages.isEmpty && model.isLoading {
                            ProgressView("Loading conversation…")
                                .tint(SlawPalette.mint)
                                .foregroundStyle(SlawPalette.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 46)
                        } else if model.messages.isEmpty {
                            Text("Send a message to continue this conversation.")
                                .font(.system(size: 14))
                                .foregroundStyle(SlawPalette.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 44)
                        }

                        ForEach(model.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        if let pendingMessage = model.pendingMessage {
                            ChatBubble(message: pendingMessage)
                                .id(pendingMessage.id)
                        }

                        if model.isWaitingForReply {
                            workingIndicator.id("working-indicator")
                        }
                        Color.clear.frame(height: 1).id("chat-bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 18)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.24)) { proxy.scrollTo("chat-bottom", anchor: .bottom) }
                }
                .onChange(of: model.pendingMessage?.id) { _, messageID in
                    if messageID != nil { withAnimation(.easeOut(duration: 0.24)) { proxy.scrollTo("chat-bottom", anchor: .bottom) } }
                }
                .onChange(of: model.isWaitingForReply) { _, waiting in
                    if waiting { withAnimation(.easeOut(duration: 0.24)) { proxy.scrollTo("chat-bottom", anchor: .bottom) } }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SlawPalette.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await model.refresh(settings: settings)
            model.startPolling(settings: settings)
        }
        .onDisappear { model.stopPolling() }
        .tint(SlawPalette.mint)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SlawPalette.text)
                    .frame(width: 42, height: 42)
                    .background(SlawPalette.surface, in: Circle())
                    .overlay(Circle().stroke(SlawPalette.outline, lineWidth: 1))
            }
            .accessibilityLabel("Back to conversations")

            SlawMark(size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.displayTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(SlawPalette.text)
                    .lineLimit(1)
                Text(conversation.repositoryLabel ?? "OpenHands agent")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(SlawPalette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            StatusBadge(title: model.isWaitingForReply ? "Working" : "Ready", tint: model.isWaitingForReply ? SlawPalette.warning : SlawPalette.mint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(SlawPalette.background.opacity(0.96))
        .overlay(alignment: .bottom) { Rectangle().fill(SlawPalette.outline.opacity(0.7)).frame(height: 1) }
    }

    private var workingIndicator: some View {
        HStack(alignment: .center, spacing: 10) {
            SlawMark(size: 28)
            HStack(spacing: 5) {
                ForEach(0..<3) { _ in Circle().fill(SlawPalette.mint).frame(width: 5, height: 5) }
            }
            Text("SlawBot is working")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SlawPalette.muted)
            Spacer(minLength: 0)
        }
        .padding(.leading, 2)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message SlawBot…", text: $draft, axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(SlawPalette.text)
                .tint(SlawPalette.mint)
                .lineLimit(1...5)
                .fixedSize(horizontal: false, vertical: true)
                .focused($composerFocused)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .onSubmit { sendDraft() }
                .padding(.vertical, 13)
                .padding(.leading, 15)

            Button(action: sendDraft) {
                Image(systemName: model.isWaitingForReply ? "hourglass" : "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SlawPalette.background)
                    .frame(width: 42, height: 42)
                    .background(canSend ? SlawPalette.mint : SlawPalette.muted.opacity(0.35), in: Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("Send message")
            .padding(6)
        }
        .background(SlawPalette.elevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(SlawPalette.outline, lineWidth: 1))
        .padding(.horizontal, 13)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(SlawPalette.background.opacity(0.97).ignoresSafeArea(edges: .bottom))
    }

    private var canSend: Bool {
        !model.isWaitingForReply && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendDraft() {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !model.isWaitingForReply else { return }
        Task {
            if await model.send(message, settings: settings) {
                draft = ""
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(SlawPalette.warning)
            Text(message).font(.system(size: 12)).foregroundStyle(SlawPalette.text).lineLimit(3)
            Spacer(minLength: 0)
            Button { model.errorMessage = nil } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(SlawPalette.muted)
            }
        }
        .padding(12)
        .background(SlawPalette.warning.opacity(0.10))
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 46)
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(SlawPalette.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .background(SlawPalette.elevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(SlawPalette.outline, lineWidth: 1))
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                SlawMark(size: 28)
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(SlawPalette.text)
                    .textSelection(.enabled)
                    .lineSpacing(4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SlawPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(SlawPalette.outline, lineWidth: 1))
                Spacer(minLength: 8)
            }
        }
    }
}
