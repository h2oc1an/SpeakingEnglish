import UIKit

/// 图片缓存服务 - 使用 NSCache 提供线程安全的内存缓存
/// 配合磁盘缓存实现二级缓存策略
actor ImageCacheService {
    static let shared = ImageCacheService()

    private let memoryCache = NSCache<NSString, UIImage>()
    private var diskCachePath: URL

    private init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100MB

        // 设置磁盘缓存路径
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCachePath = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCachePath, withIntermediateDirectories: true)
    }

    /// 获取图片 (优先内存缓存，其次磁盘缓存)
    func image(for path: String) -> UIImage? {
        let key = path as NSString

        // 1. 检查内存缓存
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        // 2. 检查磁盘缓存
        let fileName = cacheKey(for: path)
        let fileURL = diskCachePath.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // 存入内存缓存
            memoryCache.setObject(image, forKey: key, cost: data.count)
            return image
        }

        // 3. 从原始路径加载
        if let image = UIImage(contentsOfFile: path) {
            // 直接调用缓存方法（同一 actor 内）
            cacheImage(image, for: path)
            return image
        }

        return nil
    }

    /// 缓存图片
    func cacheImage(_ image: UIImage, for path: String) {
        let key = path as NSString

        // 存入内存缓存
        if let data = image.jpegData(compressionQuality: 0.8) {
            memoryCache.setObject(image, forKey: key, cost: data.count)

            // 存入磁盘缓存
            let fileName = cacheKey(for: path)
            let fileURL = diskCachePath.appendingPathComponent(fileName)
            try? data.write(to: fileURL)
        }
    }

    /// 清除所有缓存
    func clearCache() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCachePath)
        try? FileManager.default.createDirectory(at: diskCachePath, withIntermediateDirectories: true)
    }

    /// 生成缓存文件名
    private func cacheKey(for path: String) -> String {
        // 使用简单哈希避免特殊字符问题
        let hash = path.hashValue
        return "\(hash).jpg"
    }
}