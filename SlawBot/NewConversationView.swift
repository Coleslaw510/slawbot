import SwiftUI

struct NewConversationView: View {
    let onCreated: (ConversationSummary) -> Void
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var repository = ""
    @State private var branch = "main"
    @State private var isStarting = false
    @State private var progress = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                SlawPalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What should we build?")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(SlawPalette.text)
                            Text("SlawBot will start a new OpenHands workspace on your VPS.")
                                .font(.system(size: 14))
                                .foregroundStyle(SlawPalette.muted)
                                .lineSpacing(3)
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            fieldLabel("TASK")
                            TextField("Describe the task for your agent…", text: $prompt, axis: .vertical)
                                .font(.system(size: 15))
                                .foregroundStyle(SlawPalette.text)
                                .lineLimit(5...9)
                                .padding(14)
                                .background(SlawPalette.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(SlawPalette.outline, lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            fieldLabel("REPOSITORY · OPTIONAL")
                            TextField("owner/repository", text: $repository)
                                .font(.system(size: 14, design: .monospaced))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(SlawPalette.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(SlawPalette.outline, lineWidth: 1))
                            Text("Leave blank to use the default configured in OpenHands.")
                                .font(.system(size: 12))
                                .foregroundStyle(SlawPalette.muted)
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            fieldLabel("BRANCH")
                            TextField("main", text: $branch)
                                .font(.system(size: 14, design: .monospaced))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(SlawPalette.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(SlawPalette.outline, lineWidth: 1))
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(SlawPalette.danger)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(SlawPalette.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        if isStarting {
                            HStack(spacing: 11) {
                                ProgressView().tint(SlawPalette.mint)
                                Text(progress.isEmpty ? "Starting your workspace…" : progress)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(SlawPalette.muted)
                            }
                            .padding(.vertical, 4)
                        }

                        Button { Task { await startConversation() } } label: {
                            HStack {
                                Text(isStarting ? "Preparing workspace" : "Start conversation")
                                Spacer()
                                if isStarting {
                                    ProgressView().tint(SlawPalette.background)
                                } else {
                                    Image(systemName: "arrow.up.right")
                                }
                            }
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(SlawPalette.background)
                            .padding(.horizontal, 17)
                            .frame(height: 54)
                            .background(canStart ? SlawPalette.mint : SlawPalette.muted.opacity(0.35), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        }
                        .disabled(!canStart)
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundStyle(SlawPalette.muted).disabled(isStarting)
                }
                ToolbarItem(placement: .principal) {
                    Text("NEW TASK").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.7).foregroundStyle(SlawPalette.muted)
                }
            }
            .toolbarBackground(SlawPalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .tint(SlawPalette.mint)
        .onAppear {
            repository = settings.defaultRepository
            branch = settings.defaultBranch
        }
    }

    private var canStart: Bool {
        !isStarting && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && settings.isConfigured
    }

    private func fieldLabel(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(SlawPalette.muted)
    }

    private func startConversation() async {
        guard canStart else { return }
        isStarting = true
        errorMessage = nil
        progress = "Sending your task to OpenHands…"
        do {
            let client = try settings.makeClient()
            let task = try await client.createConversation(
                prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                repository: repository,
                branch: repository.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : branch
            )
            guard let taskID = task.id else { throw APIError.startTaskFailed("OpenHands did not return a startup task ID.") }

            for _ in 0..<180 {
                try await Task.sleep(for: .seconds(2))
                guard let latest = try await client.fetchStartTask(id: taskID) else { continue }
                progress = humanStatus(latest.status)
                if latest.status == "ERROR" {
                    throw APIError.startTaskFailed(latest.detail ?? "OpenHands could not start the workspace.")
                }
                if latest.status == "READY", let conversationID = latest.appConversationId {
                    let fallbackTitle = String(prompt.trimmingCharacters(in: .whitespacesAndNewlines).prefix(54))
                    let selectedRepository = repository.trimmingCharacters(in: .whitespacesAndNewlines)
                    let conversation = ConversationSummary(
                        id: conversationID,
                        title: fallbackTitle,
                        selectedRepository: selectedRepository.isEmpty ? nil : selectedRepository,
                        selectedBranch: selectedRepository.isEmpty ? nil : branch,
                        sandboxStatus: "RUNNING",
                        executionStatus: "running"
                    )
                    onCreated(conversation)
                    dismiss()
                    return
                }
            }
            throw APIError.startTaskTimedOut
        } catch {
            errorMessage = error.localizedDescription
            isStarting = false
            progress = ""
        }
    }

    private func humanStatus(_ status: String?) -> String {
        switch status {
        case "WORKING": return "Waking the OpenHands service…"
        case "WAITING_FOR_SANDBOX": return "Waiting for a workspace…"
        case "PREPARING_REPOSITORY": return "Preparing the repository…"
        case "RUNNING_SETUP_SCRIPT": return "Running the project setup…"
        case "SETTING_UP_GIT_HOOKS": return "Setting up Git…"
        case "SETTING_UP_SKILLS": return "Loading agent tools…"
        case "STARTING_CONVERSATION": return "Starting the agent…"
        case "READY": return "Opening your conversation…"
        case "ERROR": return "OpenHands reported an error"
        default: return "Preparing your workspace…"
        }
    }
}
