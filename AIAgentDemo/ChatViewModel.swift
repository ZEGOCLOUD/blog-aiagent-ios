import Foundation
import AVFoundation

/// Display message model for UI
struct ChatMessage: Identifiable {
    let id: String
    var text: String
    let isUser: Bool
    var isComplete: Bool
    let seqId: Int64
}

/// ViewModel for managing chat state and RTC operations
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var statusText = "Disconnected"
    @Published var errorMessage: String?

    private var currentRoomId: String?
    private var currentUserId: String?
    private var userStreamId: String?
    private var agentInstanceId: String?
    private var agentStreamId: String?

    // Cache for LLM messages (incremental text)
    private var llmMessageCache: [String: String] = [:]

    init() {
        setupZegoManager()
    }

    private func setupZegoManager() {
        ZegoExpressManager.shared.initEngine()

        // Listen for room state changes
        ZegoExpressManager.shared.onRoomStateChanged = { [weak self] roomId, reason, errorCode in
            Task { @MainActor in
                switch reason {
                case .logined:
                    self?.statusText = "Connected"
                case .loginFailed:
                    self?.statusText = "Login failed: \(errorCode)"
                case .logout:
                    self?.statusText = "Disconnected"
                default:
                    break
                }
            }
        }

        // Listen for subtitle messages
        ZegoExpressManager.shared.onSubtitleReceived = { [weak self] message in
            Task { @MainActor in
                self?.handleSubtitleMessage(message)
            }
        }
    }

    private func handleSubtitleMessage(_ message: SubtitleMessage) {
        if message.isUserMessage {
            handleAsrMessage(message)
        } else if message.isAgentMessage {
            handleLlmMessage(message)
        }
    }

    /// Handle ASR message (user speech) - full text replacement
    private func handleAsrMessage(_ message: SubtitleMessage) {
        guard !message.text.isEmpty else { return }

        if let index = messages.firstIndex(where: { $0.id == message.messageId }) {
            messages[index].text = message.text
            messages[index].isComplete = message.endFlag
        } else {
            let chatMessage = ChatMessage(
                id: message.messageId,
                text: message.text,
                isUser: true,
                isComplete: message.endFlag,
                seqId: message.seqId
            )
            messages.append(chatMessage)
        }
    }

    /// Handle LLM message (AI response) - incremental text accumulation
    private func handleLlmMessage(_ message: SubtitleMessage) {
        // Accumulate text in cache
        let cachedText = llmMessageCache[message.messageId] ?? ""
        let newText = cachedText + message.text
        llmMessageCache[message.messageId] = newText

        if let index = messages.firstIndex(where: { $0.id == message.messageId }) {
            messages[index].text = newText
            messages[index].isComplete = message.endFlag
        } else {
            let chatMessage = ChatMessage(
                id: message.messageId,
                text: newText,
                isUser: false,
                isComplete: message.endFlag,
                seqId: message.seqId
            )
            messages.append(chatMessage)
        }

        // Clean up cache when complete
        if message.endFlag {
            llmMessageCache.removeValue(forKey: message.messageId)
        }
    }

    func startCall() async {
        // Request microphone permission
        let granted = await requestMicrophonePermission()
        guard granted else {
            errorMessage = "Microphone permission denied"
            return
        }

        isLoading = true
        statusText = "Connecting..."

        currentUserId = AppConfig.generateUserId()
        currentRoomId = AppConfig.generateRoomId()
        userStreamId = "\(currentUserId!)_stream"

        do {
            // Step 1: Get token
            let tokenResponse = try await ApiService.shared.getToken(userId: currentUserId!)
            guard tokenResponse.code == 0, let token = tokenResponse.data?.token else {
                throw NSError(domain: "", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "Failed to get token"])
            }

            // Step 2: Login room
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                ZegoExpressManager.shared.loginRoom(
                    roomId: currentRoomId!,
                    userId: currentUserId!,
                    token: token
                ) { errorCode in
                    if errorCode == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: NSError(domain: "", code: Int(errorCode),
                            userInfo: [NSLocalizedDescriptionKey: "Login failed: \(errorCode)"]))
                    }
                }
            }

            // Step 3: Start publishing
            ZegoExpressManager.shared.startPublishing(streamId: userStreamId!)

            // Step 4: Start AI agent
            let agentResponse = try await ApiService.shared.startAgent(
                roomId: currentRoomId!,
                userId: currentUserId!,
                userStreamId: userStreamId!
            )

            guard agentResponse.code == 0,
                  let data = agentResponse.data,
                  let instanceId = data.agentInstanceId,
                  let streamId = data.agentStreamId else {
                throw NSError(domain: "", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "Failed to start agent"])
            }

            agentInstanceId = instanceId
            agentStreamId = streamId

            // Step 5: Play agent stream
            ZegoExpressManager.shared.startPlaying(streamId: agentStreamId!)

            isConnected = true
            isLoading = false

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            statusText = "Error"
        }
    }

    func endCall() async {
        isLoading = true

        // Stop agent
        if let instanceId = agentInstanceId {
            try? await ApiService.shared.stopAgent(agentInstanceId: instanceId)
        }

        // Stop playing and logout
        if let streamId = agentStreamId {
            ZegoExpressManager.shared.stopPlaying(streamId: streamId)
        }
        if let roomId = currentRoomId {
            ZegoExpressManager.shared.logoutRoom(roomId)
        }

        // Reset state
        isConnected = false
        isLoading = false
        agentInstanceId = nil
        agentStreamId = nil
        userStreamId = nil
        statusText = "Disconnected"
    }

    private func requestMicrophonePermission() async -> Bool {
        let status = AVAudioSession.sharedInstance().recordPermission

        switch status {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    deinit {
        Task { @MainActor in
            if isConnected {
                await endCall()
            }
            ZegoExpressManager.shared.destroyEngine()
        }
    }
}

