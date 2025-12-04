import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Top: Control Panel
            VStack(spacing: 20) {
                Text("ZEGO AI Agent")
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

            // Bottom: Chat Messages
            VStack(spacing: 0) {
                HStack {
                    Text("Conversation")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                if viewModel.messages.isEmpty {
                    Spacer()
                    Text("Start a conversation with AI")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            if let lastMessage = viewModel.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
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

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            Text(message.isUser ? "You" : "AI Agent")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(message.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(message.isUser ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

#Preview {
    ContentView()
}

