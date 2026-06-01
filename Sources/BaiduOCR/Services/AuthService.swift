import Foundation

actor AuthService {
    private let tokenURL = "https://aip.baidubce.com/oauth/2.0/token"
    private let cacheKey = "baidu_ocr_token_cache"
    private var cachedToken: TokenCache?
    private var isRefreshing = false

    func getToken(apiKey: String, secretKey: String) async throws -> String {
        // Check cached token
        if cachedToken == nil {
            if let data = UserDefaults.standard.data(forKey: cacheKey),
               let cache = try? JSONDecoder().decode(TokenCache.self, from: data) {
                cachedToken = cache
            }
        }
        if let cache = cachedToken, Date().timeIntervalSince1970 < cache.expiresAt - 60 {
            return cache.token
        }
        return try await refreshToken(apiKey: apiKey, secretKey: secretKey)
    }

    func invalidateCache() {
        cachedToken = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    private func refreshToken(apiKey: String, secretKey: String) async throws -> String {
        // Prevent concurrent refreshes
        if isRefreshing {
            throw AuthError.rateLimited
        }
        isRefreshing = true
        defer { isRefreshing = false }

        var components = URLComponents(string: tokenURL)!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_id", value: apiKey),
            URLQueryItem(name: "client_secret", value: secretKey)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.networkError
        }

        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)

        if let error = decoded.error {
            let desc = decoded.errorDescription ?? error
            throw AuthError.apiError("\(error): \(desc)")
        }

        guard let token = decoded.accessToken else {
            throw AuthError.invalidResponse
        }

        let expiresIn = TimeInterval(decoded.expiresIn ?? 2592000)
        let cache = TokenCache(
            token: token,
            expiresAt: Date().timeIntervalSince1970 + expiresIn
        )
        cachedToken = cache

        if let cacheData = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(cacheData, forKey: cacheKey)
        }

        return token
    }
}

enum AuthError: LocalizedError {
    case networkError
    case apiError(String)
    case invalidResponse
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .networkError: return "网络连接失败，请检查网络"
        case .apiError(let msg): return "认证失败: \(msg)"
        case .invalidResponse: return "服务器返回异常"
        case .rateLimited: return "正在刷新中，请稍后"
        }
    }
}
