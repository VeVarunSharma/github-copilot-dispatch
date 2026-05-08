import SwiftUI
import WatchKit

struct SessionDetailView: View {
    let sessionId: String

    @State private var session: SessionModel?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showSendMessage = false

    var body: some View {
        Group {
            if isLoading && session == nil {
                ProgressView()
                    .tint(GitHubColors.purple)
            } else if let session {
                ScrollView {
                    VStack(alignment: .leading, spacing: GitHubSpacing.sm) {
                        // Header: prompt + status
                        HStack {
                            Text(session.prompt)
                                .font(GitHubTypography.caption)
                                .foregroundStyle(GitHubColors.text)
                                .lineLimit(2)

                            Spacer()

                            StatusBadge(status: session.sessionStatus, showLabel: false)
                        }

                        Text(session.repo)
                            .font(GitHubTypography.caption)
                            .foregroundStyle(GitHubColors.textSubtle)

                        Divider().background(GitHubColors.border)

                        // Terminal output — combine message events into output
                        let terminalOutput = session.events
                            .filter {
                                $0.type == "message_delta" || $0.type == "message_complete"
                                    || $0.type == "tool_call" || $0.type == "error"
                            }
                            .map { event in
                                switch event.type {
                                case "tool_call": return "> \(event.content)"
                                case "error": return "✗ \(event.content)"
                                default: return event.content
                                }
                            }
                            .joined(separator: "\n")

                        if !terminalOutput.isEmpty {
                            TerminalText(text: terminalOutput)
                                .frame(maxHeight: 120)
                        }

                        // Timeline events (last 5)
                        ForEach(session.events.suffix(5)) { event in
                            TimelineEvent(
                                color: colorForEventType(event.type),
                                text: event.content,
                                timestamp: formatTimestamp(event.timestamp)
                            )
                        }

                        // Action buttons for active sessions
                        if session.sessionStatus == .working {
                            HStack(spacing: GitHubSpacing.sm) {
                                CopilotButton("Message", icon: "paperplane.fill", style: .secondary)
                                {
                                    showSendMessage = true
                                }

                                CopilotButton("Cancel", icon: "stop.circle", style: .danger) {
                                    Task { await cancelSession() }
                                }
                            }
                        }

                        // PR link
                        if session.pullRequestUrl != nil {
                            HStack {
                                Image(systemName: "arrow.triangle.pull")
                                    .foregroundStyle(GitHubColors.green)
                                Text("PR opened")
                                    .font(GitHubTypography.caption)
                                    .foregroundStyle(GitHubColors.green)
                            }
                            .padding(GitHubSpacing.sm)
                            .background(GitHubColors.green.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(GitHubSpacing.sm)
                }
            } else if let error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(GitHubColors.red)
                    Text(error)
                        .font(GitHubTypography.caption)
                        .foregroundStyle(GitHubColors.textMuted)
                }
            }
        }
        .background(GitHubColors.background)
        .navigationTitle("Session")
        .sheet(isPresented: $showSendMessage) {
            SendMessageSheet(sessionId: sessionId, isPresented: $showSendMessage)
        }
        .task {
            await startPolling()
        }
    }

    // MARK: - Polling

    private func startPolling() async {
        while !Task.isCancelled {
            await loadSession()
            // Poll faster for active sessions
            let interval: UInt64 = (session?.sessionStatus == .working) ? 3 : 10
            try? await Task.sleep(for: .seconds(interval))
            // Stop polling at terminal states
            if let status = session?.sessionStatus,
                status == .completed || status == .failed || status == .stalled
            {
                break
            }
        }
    }

    private func loadSession() async {
        do {
            session = try await APIClient.shared.getSession(id: sessionId)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func cancelSession() async {
        do {
            _ = try await APIClient.shared.cancelSession(id: sessionId)
            WKInterfaceDevice.current().play(.failure)
            await loadSession()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func colorForEventType(_ type: String) -> Color {
        switch type {
        case "status_change": return GitHubColors.blue
        case "message_delta", "message_complete": return GitHubColors.text
        case "tool_call": return GitHubColors.purple
        case "tool_result": return GitHubColors.green
        case "error": return GitHubColors.red
        case "pr_opened": return GitHubColors.green
        default: return GitHubColors.textMuted
        }
    }

    private func formatTimestamp(_ iso: String) -> String {
        // Extract HH:mm:ss from ISO 8601 timestamp
        if let tIndex = iso.firstIndex(of: "T") {
            let timeStart = iso.index(after: tIndex)
            let timeStr = String(iso[timeStart...].prefix(8))
            return timeStr
        }
        return iso
    }
}

// MARK: - Send Message Sheet

struct SendMessageSheet: View {
    let sessionId: String
    @Binding var isPresented: Bool
    @State private var message = ""
    @State private var isSending = false

    var body: some View {
        VStack(spacing: GitHubSpacing.md) {
            Text("Send Message")
                .font(GitHubTypography.headline)
                .foregroundStyle(GitHubColors.text)

            TextField("Message...", text: $message)
                .textFieldStyle(.plain)
                .padding(GitHubSpacing.sm)
                .background(GitHubColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            CopilotButton("Send", icon: "paperplane.fill") {
                Task {
                    isSending = true
                    do {
                        _ = try await APIClient.shared.sendMessage(
                            sessionId: sessionId, message: message)
                        WKInterfaceDevice.current().play(.success)
                        isPresented = false
                    } catch {
                        // Error is non-fatal; user can retry
                    }
                    isSending = false
                }
            }
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(GitHubSpacing.sm)
        .background(GitHubColors.background)
    }
}
