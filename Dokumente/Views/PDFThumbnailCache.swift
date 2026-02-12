import Foundation
import PDFKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Actor-based, in-memory thumbnail cache.
///
/// Thumbnails are generated once via ``PDFKit`` by rendering the first page
/// and are kept alive for the lifetime of the app (or until explicitly
/// evicted).  Duplicate in-flight requests for the same file are coalesced
/// automatically.
actor PDFThumbnailCache {

    // MARK: - Shared instance
    static let shared = PDFThumbnailCache()

    // MARK: - Storage
    
    #if canImport(UIKit)
    typealias PlatformImage = UIImage
    #else
    typealias PlatformImage = NSImage
    #endif

    /// Already-generated thumbnails, keyed by file-path string.
    private var cache: [String: PlatformImage] = [:]

    /// In-flight continuations – every caller waiting on the same key
    /// registers here and is resumed together when generation finishes.
    private var pending: [String: [CheckedContinuation<PlatformImage?, Never>]] = [:]

    // MARK: - Public API

    /// Returns a cached thumbnail or generates one on a background thread.
    /// Returns `nil` when the file does not exist or generation fails.
    func thumbnail(for fileURL: URL, size: CGSize = CGSize(width: 64, height: 64)) async -> PlatformImage? {
        let key = fileURL.path

        // 1. Already cached – return immediately.
        if let image = cache[key] { return image }

        // 2. Register a continuation.  If a generation is already running
        //    for this key we just append; otherwise we kick one off.
        let isFirst = pending[key] == nil

        return await withCheckedContinuation { (cont: CheckedContinuation<PlatformImage?, Never>) in
            pending[key, default: []].append(cont)

            guard isFirst else { return }   // generation already in flight

            Task.detached {
                let image = await Self.generate(fileURL: fileURL, size: size)
                await self.finish(key: key, image: image)
            }
        }
    }

    // MARK: - Eviction

    /// Evict a single entry (e.g. after the backing file is deleted).
    func evict(for fileURL: URL) {
        cache.removeValue(forKey: fileURL.path)
    }

    /// Evict everything.
    func evictAll() {
        cache.removeAll()
    }

    // MARK: - Private helpers (actor-isolated)

    /// Store the result, then resume *all* waiters for this key.
    private func finish(key: String, image: PlatformImage?) {
        if let image {
            cache[key] = image
        }
        let waiters = pending.removeValue(forKey: key) ?? []
        for cont in waiters {
            cont.resume(returning: image)
        }
    }

    // MARK: - Off-actor generation

    /// Runs entirely off the actor / main thread.
    /// Uses PDFKit to render the first page of the PDF into an image
    /// at the requested size.
    private nonisolated static func generate(fileURL: URL, size: CGSize) async -> PlatformImage? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        guard let document = PDFKit.PDFDocument(url: fileURL),
              let page = document.page(at: 0) else { return nil }

        // Scale the page down so it fits inside `size` while keeping its aspect ratio.
        let pageRect  = page.bounds(for: .mediaBox)   // points
        let scaleX    = size.width  / pageRect.width
        let scaleY    = size.height / pageRect.height
        let scale     = min(scaleX, scaleY)
        let thumbRect = CGRect(x: 0, y: 0,
                               width:  pageRect.width  * scale,
                               height: pageRect.height * scale)

        #if canImport(UIKit)
        // iOS/UIKit rendering
        let renderer = UIGraphicsImageRenderer(size: thumbRect.size)
        let image = renderer.image { context in
            // Fill with white background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: thumbRect.size))
            
            // Save state, scale, and draw
            context.cgContext.saveGState()
            context.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
        return image
        #else
        // macOS/AppKit rendering
        let image = NSImage(size: thumbRect.size)
        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }
        // Fill with white so the thumbnail always has a white background,
        // regardless of whether the app is in Dark Mode.
        context.setFillColor(CGColor.white)
        context.fill(CGRect(origin: .zero, size: thumbRect.size))

        // PDFPage.draw(with:to:) expects a CGContext, not a CGRect.
        // The context already has its origin at (0, 0) with the image's size,
        // so we simply scale it to map the page into the thumbnail dimensions.
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        image.unlockFocus()
        return image
        #endif
    }
}
