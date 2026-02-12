import Foundation

enum CloudStorageError: Error {
    case iCloudNotAvailable
    case containerNotFound
    case fileOperationFailed(String)
    case fileNotFound
}

final class CloudStorageService {
    static let shared = CloudStorageService()

    // Replace with your actual iCloud container identifier
    private let containerIdentifier = "iCloud.com.yourcompany.PDFManager"
    private let documentsSubfolder = "PDFs"

    private init() {}

    // MARK: - iCloud Container Access

    var iCloudContainerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier)
    }

    var iCloudDocumentsURL: URL? {
        guard let containerURL = iCloudContainerURL else { return nil }
        return containerURL.appendingPathComponent("Documents").appendingPathComponent(documentsSubfolder)
    }

    var localCacheURL: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("PDFCache")
    }

    var isICloudAvailable: Bool {
        iCloudContainerURL != nil
    }

    // MARK: - Setup

    func setupDirectories() throws {
        // Create local cache directory
        try FileManager.default.createDirectory(
            at: localCacheURL,
            withIntermediateDirectories: true
        )

        // Create iCloud documents directory if available
        if let iCloudDocsURL = iCloudDocumentsURL {
            try FileManager.default.createDirectory(
                at: iCloudDocsURL,
                withIntermediateDirectories: true
            )
        }
    }

    // MARK: - File Operations

    func importPDF(from sourceURL: URL) async throws -> (cloudPath: String, localPath: String, fileSize: Int64) {
        let fileName = sourceURL.lastPathComponent
        let uniqueFileName = "\(UUID().uuidString)_\(fileName)"

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // Always save to local cache first
        let localDestination = localCacheURL.appendingPathComponent(uniqueFileName)
        try FileManager.default.copyItem(at: sourceURL, to: localDestination)

        // If iCloud is available, also copy to iCloud
        var cloudPath = uniqueFileName
        if let iCloudDocsURL = iCloudDocumentsURL {
            let cloudDestination = iCloudDocsURL.appendingPathComponent(uniqueFileName)
            try FileManager.default.copyItem(at: sourceURL, to: cloudDestination)
            cloudPath = uniqueFileName
        }

        return (cloudPath, localDestination.path, fileSize)
    }

    func getLocalURL(for cloudPath: String) -> URL? {
        // First check local cache
        let localURL = localCacheURL.appendingPathComponent(cloudPath)
        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }

        // If not in cache, check iCloud and download if needed
        if let iCloudDocsURL = iCloudDocumentsURL {
            let cloudURL = iCloudDocsURL.appendingPathComponent(cloudPath)
            if FileManager.default.fileExists(atPath: cloudURL.path) {
                // Copy to local cache for offline access
                try? FileManager.default.copyItem(at: cloudURL, to: localURL)
                return localURL
            }
        }

        return nil
    }

    func deletePDF(cloudPath: String) throws {
        // Delete from local cache
        let localURL = localCacheURL.appendingPathComponent(cloudPath)
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }

        // Delete from iCloud
        if let iCloudDocsURL = iCloudDocumentsURL {
            let cloudURL = iCloudDocsURL.appendingPathComponent(cloudPath)
            if FileManager.default.fileExists(atPath: cloudURL.path) {
                try FileManager.default.removeItem(at: cloudURL)
            }
        }
    }

    // MARK: - Sync Operations

    func syncFromICloud() async throws -> [String] {
        guard let iCloudDocsURL = iCloudDocumentsURL else {
            return []
        }

        let fileManager = FileManager.default

        // Start downloading any files that aren't downloaded yet
        try fileManager.startDownloadingUbiquitousItem(at: iCloudDocsURL)

        let contents = try fileManager.contentsOfDirectory(
            at: iCloudDocsURL,
            includingPropertiesForKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey],
            options: .skipsHiddenFiles
        )

        return contents
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .map { $0.lastPathComponent }
    }
}
