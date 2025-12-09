import Foundation
import AVFoundation

/// ViewModel for managing chat state and RTC operations
@MainActor
class ChatViewModel: NSObject, ObservableObject, ZegoAIAgentSubtitlesEventHandler {
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var statusText = "Disconnected"
    @Published var errorMessage: String?

    /// 官方字幕 TableView 组件
    let subtitlesTableView: ZegoAIAgentSubtitlesTableView

    private var currentRoomId: String?
    private var currentUserId: String?
    private var userStreamId: String?
    private var agentInstanceId: String?
    private var agentStreamId: String?

    override init() {
        // 初始化官方字幕 TableView
        subtitlesTableView = ZegoAIAgentSubtitlesTableView(frame: .zero, style: .plain)
        super.init()
        setupZegoManager()
    }

    private func setupZegoManager() {
        ZegoExpressManager.shared.initEngine()

        // 注册字幕事件处理器
        ZegoAIAgentSubtitlesMessageDispatcher.sharedInstance().register(self)

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

        // 使用官方字幕消息分发器处理消息
        ZegoExpressManager.shared.onRecvExperimentalAPI = { content in
            ZegoAIAgentSubtitlesMessageDispatcher.sharedInstance().handleExpressExperimentalAPIContent(content)
        }
    }

    // MARK: - ZegoAIAgentSubtitlesEventHandler

    nonisolated func onRecvChatStateChange(_ state: ZegoAIAgentSessionState) {
        // 处理聊天状态变化
    }

    nonisolated func onRecvAsrChatMsg(_ message: ZegoAIAgentAudioSubtitlesMessage) {
        // 在主线程更新 UI
        DispatchQueue.main.async { [weak self] in
            self?.subtitlesTableView.handleRecvAsrMessage(message)
        }
    }

    nonisolated func onRecvLLMChatMsg(_ message: ZegoAIAgentAudioSubtitlesMessage) {
        // 在主线程更新 UI
        DispatchQueue.main.async { [weak self] in
            self?.subtitlesTableView.handleRecvLLMMessage(message)
        }
    }

    nonisolated func onExpressExperimentalAPIContent(_ content: String) {
        // 原始内容回调，可用于调试
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
        // 注销字幕事件处理器
        ZegoAIAgentSubtitlesMessageDispatcher.sharedInstance().unregisterEventHandler(self)
        Task { @MainActor in
            if isConnected {
                await endCall()
            }
            ZegoExpressManager.shared.destroyEngine()
        }
    }
}

