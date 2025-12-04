import Foundation

/// API service for communicating with the backend server
class ApiService {
    static let shared = ApiService()
    private init() {}
    
    // MARK: - Response Models
    
    struct TokenResponse: Codable {
        let code: Int?
        let data: TokenData?
        let message: String?
    }
    
    struct TokenData: Codable {
        let token: String?
    }
    
    struct AgentResponse: Codable {
        let code: Int?
        let data: AgentData?
        let message: String?
    }
    
    struct AgentData: Codable {
        let agentInstanceId: String?
        let agentUserId: String?
        let agentStreamId: String?
    }
    
    struct StopResponse: Codable {
        let code: Int?
        let message: String?
    }
    
    // MARK: - API Methods
    
    /// Get authentication token from backend server
    func getToken(userId: String) async throws -> TokenResponse {
        let url = URL(string: "\(AppConfig.serverURL)/api/zego/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["userId": userId]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
    
    /// Start AI agent instance
    func startAgent(roomId: String, userId: String, userStreamId: String) async throws -> AgentResponse {
        let url = URL(string: "\(AppConfig.serverURL)/api/zego/start")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "roomId": roomId,
            "userId": userId,
            "userStreamId": userStreamId
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(AgentResponse.self, from: data)
    }
    
    /// Stop AI agent instance
    func stopAgent(agentInstanceId: String) async throws -> StopResponse {
        let url = URL(string: "\(AppConfig.serverURL)/api/zego/stop")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["agentInstanceId": agentInstanceId]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(StopResponse.self, from: data)
    }
}

