import Foundation
import ZegoExpressEngine

/// Subtitle message data model
struct SubtitleMessage {
    let cmd: Int           // 3=ASR(user), 4=LLM(AI)
    let text: String
    let messageId: String
    let endFlag: Bool
    let seqId: Int64
    let round: Int64
    let timestamp: Int64

    var isUserMessage: Bool { cmd == 3 }
    var isAgentMessage: Bool { cmd == 4 }
}

/// Manager class for ZEGO Express SDK operations
class ZegoExpressManager: NSObject {
    static let shared = ZegoExpressManager()

    // Callbacks
    var onRoomStateChanged: ((String, ZegoRoomStateChangedReason, Int32) -> Void)?
    var onSubtitleReceived: ((SubtitleMessage) -> Void)?

    private override init() {
        super.init()
    }

    /// Initialize ZEGO Express Engine with optimal settings for AI conversation
    func initEngine() {
        // Set engine config before creating engine
        let engineConfig = ZegoEngineConfig()
        engineConfig.advancedConfig = [
            "set_audio_volume_ducking_mode": "1",
            "enable_rnd_volume_adaptive": "true"
        ]
        ZegoExpressEngine.setEngineConfig(engineConfig)

        // Create engine profile
        let profile = ZegoEngineProfile()
        profile.appID = AppConfig.appID
        profile.scenario = .highQualityChatroom

        // Create engine
        ZegoExpressEngine.createEngine(with: profile, eventHandler: self)

        // Configure audio settings
        configureAudioSettings()

        print("[ZegoExpressManager] Engine initialized with appID=\(AppConfig.appID)")
    }

    private func configureAudioSettings() {
        let engine = ZegoExpressEngine.shared()

        // Enable 3A audio processing
        engine.enableAGC(true)
        engine.enableAEC(true)
        engine.setAECMode(.aiBalanced)  // AI echo cancellation
        engine.enableANS(true)
        engine.setANSMode(.medium)

        // Set audio device mode
        engine.setAudioDeviceMode(.general)
    }

    /// Login to a room with authentication token
    func loginRoom(roomId: String, userId: String, token: String, callback: @escaping (Int32) -> Void) {
        let user = ZegoUser(userID: userId)
        let config = ZegoRoomConfig()
        config.isUserStatusNotify = true
        config.token = token

        ZegoExpressEngine.shared().loginRoom(roomId, user: user, config: config) { errorCode, _ in
            callback(errorCode)
        }
    }

    /// Start publishing local audio stream
    func startPublishing(streamId: String) {
        ZegoExpressEngine.shared().startPublishingStream(streamId)
    }

    /// Start playing remote audio stream (AI agent's voice)
    func startPlaying(streamId: String) {
        ZegoExpressEngine.shared().startPlayingStream(streamId)
    }

    /// Stop playing remote stream
    func stopPlaying(streamId: String) {
        ZegoExpressEngine.shared().stopPlayingStream(streamId)
    }

    /// Logout from room and cleanup
    func logoutRoom(_ roomId: String) {
        ZegoExpressEngine.shared().stopPublishingStream()
        ZegoExpressEngine.shared().logoutRoom(roomId)
    }

    /// Destroy the engine instance
    func destroyEngine() {
        ZegoExpressEngine.destroy(nil)
    }

    /// Parse subtitle message from experimental API callback
    private func parseSubtitleMessage(_ content: String) -> SubtitleMessage? {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = json["method"] as? String,
              method == "liveroom.room.on_recive_room_channel_message",
              let params = json["params"] as? [String: Any],
              let msgContent = params["msg_content"] as? String,
              let msgData = msgContent.data(using: .utf8),
              let msgJson = try? JSONSerialization.jsonObject(with: msgData) as? [String: Any],
              let cmd = msgJson["Cmd"] as? Int,
              let dataDict = msgJson["Data"] as? [String: Any] else {
            return nil
        }

        return SubtitleMessage(
            cmd: cmd,
            text: dataDict["Text"] as? String ?? "",
            messageId: dataDict["MessageId"] as? String ?? "",
            endFlag: dataDict["EndFlag"] as? Bool ?? false,
            seqId: msgJson["SeqId"] as? Int64 ?? 0,
            round: msgJson["Round"] as? Int64 ?? 0,
            timestamp: msgJson["Timestamp"] as? Int64 ?? 0
        )
    }
}

// MARK: - ZegoEventHandler
extension ZegoExpressManager: ZegoEventHandler {
    func onRoomStateChanged(_ reason: ZegoRoomStateChangedReason, errorCode: Int32,
                           extendedData: [AnyHashable : Any], roomID: String) {
        print("[ZegoExpressManager] onRoomStateChanged: roomID=\(roomID), reason=\(reason), errorCode=\(errorCode)")
        onRoomStateChanged?(roomID, reason, errorCode)
    }

    func onPlayerStateUpdate(_ state: ZegoPlayerState, errorCode: Int32,
                            extendedData: [AnyHashable : Any]?, streamID: String) {
        print("[ZegoExpressManager] onPlayerStateUpdate: streamID=\(streamID), state=\(state), errorCode=\(errorCode)")
    }

    func onRecvExperimentalAPI(_ content: String) {
        print("[ZegoExpressManager] onRecvExperimentalAPI: \(content)")
        if let message = parseSubtitleMessage(content) {
            print("[ZegoExpressManager] Parsed subtitle: cmd=\(message.cmd), text=\(message.text)")
            onSubtitleReceived?(message)
        }
    }
}

