import Foundation

// MARK: - 配置常量
private enum TranslationConfig {
    static let authEndpoint = "https://edge.microsoft.com/translate/auth"
    static let translateEndpoint = "https://api-edge.cognitive.microsofttranslator.com/translate"
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)"
    // Token 有效期 9 分钟（微软建议每 10 分钟刷新一次）
    static let tokenExpirySeconds: TimeInterval = 540
    // Token 刷新等待时间
    static let tokenRefreshWaitNanoseconds: UInt64 = 2_000_000_000
    // 最大重试次数
    static let maxRetryAttempts = 3
}

/// 翻译服务 - 使用 Bing Translator API
class TranslationService {
    static let shared = TranslationService()

    private var cache: [String: String] = [:]
    private var authToken: String?
    private var tokenExpiry: Date?
    private var isRefreshingToken = false
    private let session: URLSession

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

        guard let url = URL(string: TranslationConfig.authEndpoint) else {
            isRefreshingToken = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(TranslationConfig.userAgent, forHTTPHeaderField: "User-Agent")

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            self?.isRefreshingToken = false
            guard let data = data, error == nil, let token = String(data: data, encoding: .utf8) else {
                print("Token 刷新失败: \(error?.localizedDescription ?? "未知错误")")
                return
            }
            self?.authToken = token
            self?.tokenExpiry = Date().addingTimeInterval(TranslationConfig.tokenExpirySeconds)
        }
        task.resume()
    }

    /// 翻译文本
    func translate(_ text: String) async throws -> String {
        // 检查缓存
        if let cached = cache[text] {
            return cached
        }

        // 获取 Token，带重试
        let token = try await getTokenWithRetry()

        return try await performTranslate(text: text, token: token)
    }

    /// 获取 Token（带重试）
    private func getTokenWithRetry() async throws -> String {
        for attempt in 1...TranslationConfig.maxRetryAttempts {
            if let token = authToken, let expiry = tokenExpiry, Date() < expiry {
                return token
            }

            if attempt == 1 {
                refreshToken()
            }

            try await Task.sleep(nanoseconds: TranslationConfig.tokenRefreshWaitNanoseconds)

            if let token = authToken, let expiry = tokenExpiry, Date() < expiry {
                return token
            }
        }

        throw TranslationError.authenticationFailed
    }

    /// 执行翻译请求
    private func performTranslate(text: String, token: String) async throws -> String {
        guard let url = URL(string: TranslationConfig.translateEndpoint + "?api-version=3.0&to=zh-Hans") else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(TranslationConfig.userAgent, forHTTPHeaderField: "User-Agent")
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

    /// 批量翻译（并行）
    func translateBatch(_ texts: [String]) async throws -> [String] {
        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, text) in texts.enumerated() {
                group.addTask {
                    let translation = try await self.translate(text)
                    return (index, translation)
                }
            }

            var results = [String](repeating: "", count: texts.count)
            for try await (index, translation) in group {
                results[index] = translation
            }
            return results
        }
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
