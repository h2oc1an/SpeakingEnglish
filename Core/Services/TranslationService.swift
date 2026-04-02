import Foundation

/// 翻译服务 - 使用 Bing Translator API 进行英译中
class TranslationService {
    static let shared = TranslationService()

    private var cache: [String: String] = [:]
    private var authToken: String?
    private var tokenExpiry: Date?
    private var isRefreshingToken = false
    private let session: URLSession

    private let authEndpoint = "https://edge.microsoft.com/translate/auth"
    private let translateEndpoint = "https://api-edge.cognitive.microsofttranslator.com/translate"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        refreshToken()
    }

    /// 刷新认证 Token
    func refreshToken() {
        guard !isRefreshingToken else { return }
        isRefreshingToken = true

        guard let url = URL(string: authEndpoint) else {
            isRefreshingToken = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            self?.isRefreshingToken = false
            guard let data = data, error == nil, let token = String(data: data, encoding: .utf8) else {
                return
            }
            self?.authToken = token
            self?.tokenExpiry = Date().addingTimeInterval(540)
        }
        task.resume()
    }

    /// 确保有有效 Token
    private func ensureTokenSync() -> String? {
        if let token = authToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }
        refreshToken()
        return nil
    }

    /// 翻译文本
    func translate(_ text: String) async throws -> String {
        // 检查缓存
        if let cached = cache[text] {
            return cached
        }

        // 等待 Token 准备好
        try await prepareToken()

        guard let token = authToken else {
            throw TranslationError.authenticationFailed
        }

        return try await performTranslate(text: text, token: token)
    }

    /// 准备 Token
    private func prepareToken() async throws {
        if let token = authToken, let expiry = tokenExpiry, Date() < expiry {
            return
        }

        // 刷新 Token
        refreshToken()

        // 等待 Token 刷新完成
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒

        if authToken == nil {
            throw TranslationError.authenticationFailed
        }
    }

    /// 执行翻译请求
    private func performTranslate(text: String, token: String) async throws -> String {
        guard let url = URL(string: translateEndpoint + "?api-version=3.0&to=zh-Hans") else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [["text": text]]
        request.httpBody = try? JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.networkError
        }

        if httpResponse.statusCode == 401 {
            // Token 过期，刷新并重试
            authToken = nil
            refreshToken()
            throw TranslationError.authenticationFailed
        }

        guard httpResponse.statusCode == 200 else {
            throw TranslationError.translationFailed
        }

        guard let translation = parseResponse(data) else {
            throw TranslationError.parseError
        }

        cache[text] = translation
        return translation
    }

    /// 解析响应
    private func parseResponse(_ data: Data) -> String? {
        guard let str = String(data: data, encoding: .utf8) else {
            return nil
        }

        // 提取 translations[0].text
        let pattern = "\"text\":\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: str, options: [], range: NSRange(str.startIndex..., in: str)),
              let range = Range(match.range(at: 1), in: str) else {
            return nil
        }

        return String(str[range])
    }

    /// 批量翻译
    func translateBatch(_ texts: [String]) async throws -> [String] {
        var results: [String] = []

        for text in texts {
            let translation = try await translate(text)
            results.append(translation)
        }

        return results
    }
}

enum TranslationError: LocalizedError {
    case authenticationFailed
    case invalidURL
    case networkError
    case translationFailed
    case parseError

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "翻译服务认证失败"
        case .invalidURL:
            return "翻译服务URL无效"
        case .networkError:
            return "网络错误"
        case .translationFailed:
            return "翻译失败"
        case .parseError:
            return "解析响应失败"
        }
    }
}
