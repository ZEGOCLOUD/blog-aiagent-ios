import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Top: Control Panel
            VStack(spacing: 20) {
                Text("ZEGOCLOUD AI Agent")
                    .font(.title)
                    .fontWeight(.semibold)

                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                        .animation(.easeInOut, value: viewModel.isConnected)

                    Text(viewModel.statusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Call button
                Button(action: {
                    Task {
                        if viewModel.isConnected {
                            await viewModel.endCall()
                        } else {
                            await viewModel.startCall()
                        }
                    }
                }) {
                    Text(buttonText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(buttonColor)
                        .cornerRadius(25)
                }
                .disabled(viewModel.isLoading)

                Text("Tap to start a voice conversation with AI")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color(.systemGroupedBackground))

            Divider()

            // Bottom: Chat Messages - 使用官方字幕组件
            VStack(spacing: 0) {
                HStack {
                    Text("Conversation")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                // 使用官方 ZegoAIAgentSubtitlesTableView
                SubtitlesTableViewWrapper(tableView: viewModel.subtitlesTableView)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
        .alert(isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var buttonText: String {
        if viewModel.isLoading {
            return "Processing..."
        }
        return viewModel.isConnected ? "End Call" : "Start AI Call"
    }

    private var buttonColor: Color {
        if viewModel.isLoading {
            return .gray
        }
        return viewModel.isConnected ? .red : .blue
    }
}

/// UIViewRepresentable 包装器，用于在 SwiftUI 中使用官方 ZegoAIAgentSubtitlesTableView
struct SubtitlesTableViewWrapper: UIViewRepresentable {
    let tableView: ZegoAIAgentSubtitlesTableView

    func makeUIView(context: Context) -> ZegoAIAgentSubtitlesTableView {
        return tableView
    }

    func updateUIView(_ uiView: ZegoAIAgentSubtitlesTableView, context: Context) {
        // TableView 会自动更新
    }
}

#Preview {
    ContentView()
}

