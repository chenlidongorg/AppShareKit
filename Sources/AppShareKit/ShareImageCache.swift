import UIKit

final class ShareImageCache {
    static let shared = ShareImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let workQueue = DispatchQueue(label: "appsharekit.shareimage.prewarm", qos: .userInitiated)
    private let diskQueue = DispatchQueue(label: "appsharekit.shareimage.disk", qos: .utility)
    private let fileManager = FileManager()
    private let cacheDirectory: URL

    private init() {
        if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            cacheDirectory = caches.appendingPathComponent("AppShareKitShareCache", isDirectory: true)
        } else {
            cacheDirectory = fileManager.temporaryDirectory.appendingPathComponent("AppShareKitShareCache", isDirectory: true)
        }

        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    func prepareImage(for payload: AppSharePayload, completion: ((UIImage) -> Void)? = nil) {
        let key = payload.cacheIdentifier
        if let cached = memoryImage(forKey: key) {
            completion?(cached)
            return
        }

        workQueue.async { [weak self] in
            guard let self else { return }
            if let diskImage = self.diskImage(forKey: key) {
                self.memoryCache.setObject(diskImage, forKey: key as NSString)
                if let completion {
                    DispatchQueue.main.async {
                        completion(diskImage)
                    }
                }
                return
            }

            let composer = ShareImageComposer()
            let image = composer.composeImage(from: payload)
            self.store(image, forKey: key)
            if let completion {
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }

    func preparedImage(for payload: AppSharePayload) -> UIImage {
        let key = payload.cacheIdentifier
        if let cached = cachedImage(forKey: key) {
            return cached
        }
        let composer = ShareImageComposer()
        let image = composer.composeImage(from: payload)
        store(image, forKey: key)
        return image
    }

    func cachedImageIfAvailable(for payload: AppSharePayload) -> UIImage? {
        cachedImage(forKey: payload.cacheIdentifier)
    }

    private func cachedImage(forKey key: String) -> UIImage? {
        if let image = memoryImage(forKey: key) {
            return image
        }

        guard let image = diskImage(forKey: key) else { return nil }
        memoryCache.setObject(image, forKey: key as NSString)
        return image
    }

    private func memoryImage(forKey key: String) -> UIImage? {
        memoryCache.object(forKey: key as NSString)
    }

    private func diskImage(forKey key: String) -> UIImage? {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    private func store(_ image: UIImage, forKey key: String) {
        memoryCache.setObject(image, forKey: key as NSString)
        let destination = fileURL(for: key)
        diskQueue.async { [fileManager, destination, key, image] in
            guard let data = image.pngData() else { return }
            let directory = destination.deletingLastPathComponent()
            do {
                if !fileManager.fileExists(atPath: directory.path) {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                }
                try data.write(to: destination, options: .atomic)
            } catch {
                #if DEBUG
                print("AppShareKit.ShareImageCache: Failed to persist image with key \(key): \(error)")
                #endif
            }
        }
    }

    private func fileURL(for key: String) -> URL {
        cacheDirectory.appendingPathComponent("\(key).png", isDirectory: false)
    }
}
