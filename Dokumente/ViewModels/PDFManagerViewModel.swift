import Foundation
import SwiftData
import Combine
import PDFKit
import UIKit
import CommonCrypto

@MainActor
final class PDFManagerViewModel: ObservableObject {
    @Published var documents: [PDFDocument] = []
    @Published var selectedDocument: PDFDocument?
    @Published var isImporting = false
    @Published var errorMessage: String?
    @Published var showError = false

    private let cloudStorage = CloudStorageService.shared
    private let textExtractor = PDFTextExtractor.shared
    private let claudeAPI = ClaudeAPIService.shared

    var modelContext: ModelContext?

    init() {
        setupStorage()
    }

    private func setupStorage() {
        do {
            try cloudStorage.setupDirectories()
        } catch {
            showError(message: "Fehler beim Einrichten des Speichers: \(error.localizedDescription)")
        }
    }

    func loadDocuments() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<PDFDocument>(
            sortBy: [SortDescriptor(\.importDate, order: .reverse)]
        )

        do {
            documents = try context.fetch(descriptor)
        } catch {
            showError(message: "Fehler beim Laden der Dokumente: \(error.localizedDescription)")
        }
    }

    // MARK: - Duplikat-Erkennung

    /// Berechnet den SHA-256-Hash einer Datei blockweise (arbeitet auch bei großen PDFs effizient).
    private func computeSHA256(for url: URL) throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { fileHandle.closeFile() }

        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)

        let chunkSize = 64 * 1024   // 64 KB pro Durchlauf
        while true {
            let data = fileHandle.readData(ofLength: chunkSize)
            if data.isEmpty { break }
            data.withUnsafeBytes { ptr in
                _ = CC_SHA256_Update(&context, ptr.baseAddress, CC_LONG(data.count))
            }
        }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)

        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Gibt das bereits importierte Dokument zurück, dessen `contentHash` mit dem
    /// eben berechneten Hash übereinstimmt – oder `nil`, wenn kein Duplikat existiert.
    private func findDuplicate(hash: String) throws -> PDFDocument? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<PDFDocument>(
            predicate: #Predicate<PDFDocument> { $0.contentHash == hash }
        )
        return try context.fetch(descriptor).first
    }

    func importPDF(from url: URL, toFolder folder: Folder? = nil) async {
        isImporting = true

        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                throw CloudStorageError.fileOperationFailed("Keine Berechtigung für Dateizugriff")
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // --- Duplikat-Prüfung (vor dem Kopieren) ---
            let hash = try computeSHA256(for: url)
            if let existing = try findDuplicate(hash: hash) {
                let name = existing.title ?? existing.fileName
                showError(message: "Diese Datei wurde bereits importiert als \"\(name)\".")
                isImporting = false
                return
            }

            // Import file to cloud storage
            let (cloudPath, localPath, fileSize) = try await cloudStorage.importPDF(from: url)

            // Extract page count
            let pageCount = textExtractor.getPageCount(from: URL(fileURLWithPath: localPath)) ?? 0

            // Create document model with folder assignment
            let document = PDFDocument(
                fileName: url.lastPathComponent,
                cloudPath: cloudPath,
                localCachePath: localPath,
                summaryStatus: .pending,
                pageCount: pageCount,
                fileSize: fileSize,
                contentHash: hash,
                folder: folder
            )

            // Save to SwiftData
            modelContext?.insert(document)
            try modelContext?.save()

            // Reload documents
            loadDocuments()

            // Start summary generation in background
            Task {
                await generateSummary(for: document)
            }

        } catch {
            showError(message: "Import fehlgeschlagen: \(error.localizedDescription)")
        }

        isImporting = false
    }

    func generateSummary(for document: PDFDocument) async {
        guard let localPath = document.localCachePath ?? cloudStorage.getLocalURL(for: document.cloudPath)?.path else {
            document.summaryStatus = .failed
            try? modelContext?.save()
            return
        }

        document.summaryStatus = .processing
        try? modelContext?.save()
        loadDocuments()

        do {
            // Extract text from PDF
            let result = try textExtractor.extractText(from: URL(fileURLWithPath: localPath))

            // Einzelner Claude-Aufruf: Summary, Author und Title gleichzeitig
            let metadata = try await claudeAPI.extractDocumentMetadata(from: result.text)

            document.summary = metadata.summary
            document.author  = metadata.author
            document.title   = metadata.title
            document.keywords = metadata.keywords
            document.dateCreated = metadata.dateCreated
            document.summaryStatus = .completed
            document.pageCount = result.pageCount
            try? modelContext?.save()

        } catch ClaudeAPIError.noAPIKey {
            document.summaryStatus = .failed
            document.summary = "Bitte API-Key in Einstellungen eingeben"
            try? modelContext?.save()
        } catch {
            document.summaryStatus = .failed
            document.summary = "Fehler: \(error.localizedDescription)"
            try? modelContext?.save()
        }

        loadDocuments()
    }

    func retryGenerateSummary(for document: PDFDocument) {
        Task {
            await generateSummary(for: document)
        }
    }

    func deleteDocument(_ document: PDFDocument) {
        do {
            // Thumbnail aus dem Cache entfernen, falls vorhanden
            if let localPath = document.localCachePath {
                Task { await PDFThumbnailCache.shared.evict(for: URL(fileURLWithPath: localPath)) }
            }

            try cloudStorage.deletePDF(cloudPath: document.cloudPath)
            modelContext?.delete(document)
            try modelContext?.save()
            loadDocuments()

            if selectedDocument?.id == document.id {
                selectedDocument = nil
            }
        } catch {
            showError(message: "Löschen fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func getLocalURL(for document: PDFDocument) -> URL? {
        if let localPath = document.localCachePath {
            return URL(fileURLWithPath: localPath)
        }
        return cloudStorage.getLocalURL(for: document.cloudPath)
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
