import Foundation

/// Application configuration for ZEGO AI Agent
///
/// IMPORTANT: Replace these values with your own credentials before running the app.
///
/// How to obtain:
/// 1. APP_ID: Log in to ZEGO Console (https://console.zego.im/), create a project,
///    and find the App ID in Project Settings.
/// 2. SERVER_URL: Deploy the Next.js backend to Vercel and use the deployment URL.
///
/// Note: APP_ID must match NEXT_PUBLIC_ZEGO_APP_ID in your backend's .env.local file.
struct AppConfig {
    // ZEGO App ID - Must match your backend configuration
    static let appID: UInt32 = 1234567890

    // Backend server URL (your Vercel deployment)
    // Example: "https://your-project.vercel.app"
    static let serverURL = "https://your-project.vercel.app"

    // Generate unique IDs for testing
    static func generateUserId() -> String {
        return "user\(Int(Date().timeIntervalSince1970) % 100000)"
    }

    static func generateRoomId() -> String {
        return "room\(Int(Date().timeIntervalSince1970) % 100000)"
    }
}

