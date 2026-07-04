import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class FileIconCache {
    static let shared = FileIconCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 512
    }

    func icon(for entry: FileEntry) -> NSImage {
        let key = cacheKey(for: entry) as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let image: NSImage
        if entry.isDirectory {
            image = NSWorkspace.shared.icon(for: .folder)
        } else if !entry.fileExtension.isEmpty, let type = UTType(filenameExtension: entry.fileExtension) {
            image = NSWorkspace.shared.icon(for: type)
        } else {
            image = NSWorkspace.shared.icon(forFile: entry.path)
        }
        image.size = NSSize(width: 32, height: 32)
        cache.setObject(image, forKey: key)
        return image
    }

    func clear() {
        cache.removeAllObjects()
    }

    private func cacheKey(for entry: FileEntry) -> String {
        if entry.isDirectory { return "folder" }
        if !entry.fileExtension.isEmpty { return "ext:\(entry.fileExtension)" }
        return "file:\(entry.path)"
    }
}
