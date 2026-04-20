import SwiftUI

/// 带缓存的异步图片加载组件
struct CachedAsyncImage: View {
    let path: String?
    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        }
        .aspectRatio(16/9, contentMode: .fill)
        .clipped()
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        guard let path = path, !isLoading else { return }

        // 检查内存缓存
        if let cached = ImageCacheStorage.shared.get(path) {
            self.image = cached
            return
        }

        isLoading = true
        Task {
            // 异步加载
            if let loadedImage = UIImage(contentsOfFile: path) {
                // 存入缓存
                ImageCacheStorage.shared.set(loadedImage, for: path)
                await MainActor.run {
                    self.image = loadedImage
                }
            }
            isLoading = false
        }
    }
}

/// 线程安全的图片内存缓存 (使用 NSCache)
final class ImageCacheStorage {
    static let shared = ImageCacheStorage()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func get(_ path: String) -> UIImage? {
        return cache.object(forKey: path as NSString)
    }

    func set(_ image: UIImage, for path: String) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            cache.setObject(image, forKey: path as NSString, cost: data.count)
        }
    }

    func clear() {
        cache.removeAllObjects()
    }
}