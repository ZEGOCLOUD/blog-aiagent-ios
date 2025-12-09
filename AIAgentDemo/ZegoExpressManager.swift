import Foundation
import ZegoExpressEngine

/// Manager class for ZEGO Express SDK operations
class ZegoExpressManager: NSObject {
    static let shared = ZegoExpressManager()

    // Callbacks
    var onRoomStateChanged: ((String, ZegoRoomStateChangedReason, Int32) -> Void)?
    var onRecvExperimentalAPI: ((String) -> Void)?

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
        onRecvExperimentalAPI?(content)
    }
}

