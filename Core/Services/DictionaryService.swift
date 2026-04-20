import Foundation

/// DictionaryService - 使用 Bing Translator API 进行英汉翻译
/// 参考 VideoCaptioner 的 bing_translator.py 实现
class DictionaryService {
    static let shared = DictionaryService()

    // 线程安全的有界缓存 (NSCache 自动处理线程安全 and LRU 淘汰)
    private let cache = NSCache<NSString, NSString>()
    private var authToken: String?
    private var tokenExpiry: Date?
    private var isRefreshingToken = false
    private let session: URLSession

    private let authEndpoint = "https://edge.microsoft.com/translate/auth"
    private let translateEndpoint = "https://api-edge.cognitive.microsofttranslator.com/translate"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
        // 限制缓存大小
        cache.countLimit = 500
        cache.totalCostLimit = 5 * 1024 * 1024 // 5MB
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
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            self?.isRefreshingToken = false
            guard let data = data, error == nil, let token = String(data: data, encoding: .utf8) else {
                return
            }
            self?.authToken = token
            self?.tokenExpiry = Date().addingTimeInterval(540) // 9分钟后过期
        }
        task.resume()
    }

    /// 确保有有效 Token
    private func ensureToken(completion: @escaping (String?) -> Void) {
        print("DictionaryService: ensureToken called, current token: \(authToken == nil ? "nil" : "exists"), expiry: \(tokenExpiry == nil ? "nil" : "valid")")

        if let token = authToken, let expiry = tokenExpiry, Date() < expiry {
            print("DictionaryService: Using cached token")
            completion(token)
            return
        }

        // Token 无效，刷新
        print("DictionaryService: Refreshing token...")
        refreshToken()

        // 等待一段时间后重试
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            print("DictionaryService: After wait, token: \(self?.authToken == nil ? "nil" : "exists")")
            if let token = self?.authToken {
                completion(token)
            } else {
                completion(nil)
            }
        }
    }

    func lookup(_ word: String, completion: @escaping (String?) -> Void) {
        let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)

        guard !cleanWord.isEmpty, cleanWord.count >= 2 else {
            completion(nil)
            return
        }

        // Check cache first (NSCache is thread-safe)
        if let cached = cache.object(forKey: cleanWord as NSString) {
            completion(cached as String)
            return
        }

        // 确保有 Token
        ensureToken { [weak self] token in
            guard let self = self, let token = token else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self.translate(word: cleanWord, token: token, completion: completion)
        }
    }

    private func translate(word: String, token: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: translateEndpoint + "?api-version=3.0&to=zh-Hans") else {
            print("DictionaryService: Invalid URL")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [["text": word]]
        request.httpBody = try? JSONEncoder().encode(body)

        print("DictionaryService: Translating '\(word)' with token: \(token.prefix(20))...")

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("DictionaryService: Error - \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let data = data else {
                print("DictionaryService: No data received")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            print("DictionaryService: Received data: \(String(data: data, encoding: .utf8)?.prefix(100) ?? "nil")")

            if let translation = self?.parseBingResponse(data) {
                self?.cache.setObject(translation as NSString, forKey: word as NSString)
                DispatchQueue.main.async {
                    completion(translation)
                }
            } else {
                print("DictionaryService: Failed to parse response")
                self?.refreshToken()
                DispatchQueue.main.async { completion(nil) }
            }
        }
        task.resume()
    }

    /// 解析 Bing Translator API 响应
    /// 响应格式: [{"detectedLanguage":{"language":"en","score":0.99},"translations":[{"text":"真的","to":"zh-Hans"}]}]
    private func parseBingResponse(_ data: Data) -> String? {
        guard let str = String(data: data, encoding: .utf8) else {
            return nil
        }

        // 提取 translations[0].text
        let patterns = [
            "\"translations\":\\[\\{\"text\":\"([^\"]+)\"",
            "\"text\":\"([^\"]+)\".*?zh-Hans"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: str, options: [], range: NSRange(str.startIndex..., in: str)),
               let range = Range(match.range(at: 1), in: str) {
                return String(str[range])
            }
        }

        return nil
    }

    func hasDefinition(for word: String) -> Bool {
        return cache.object(forKey: word.lowercased() as NSString) != nil
    }

    func getCachedDefinition(_ word: String) -> String? {
        return cache.object(forKey: word.lowercased() as NSString) as String?
    }
}

// MARK: - Bing API Models

struct BingTranslationResponse: Codable {
    let translations: [BingTranslation]
}

struct BingTranslation: Codable {
    let text: String
    let to: String?
}
