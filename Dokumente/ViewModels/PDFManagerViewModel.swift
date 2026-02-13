import Foundation
import SwiftData
import Combine
import PDFKit
import UIKit
import CommonCrypto
import CoreData

@MainActor
final class PDFManagerViewModel: ObservableObject {
    @Published var documents: [PDFDocument] = []
    @Published var selectedDocument: PDFDocument?
    @Published var isImporting = false
    @Published var errorMessage: String?
    @Published var showError = false

    /// Zeigt den Fortschritt beim Wiederherstellen des iCloud-Caches an.
    @Published var isSyncingFromCloud = false

    private let cloudStorage = CloudStorageService.shared
    private let textExtractor = PDFTextExtractor.shared
    private let claudeAPI = ClaudeAPIService.shared

    var modelContext: ModelContext? {
        didSet { subscribeToCloudKitSync() }
    }

    /// Speichert die NotificationCenter-Subscription für CloudKit-Import-Events.
    private var cloudKitSyncObserver: AnyCancellable?

    init() {
        Task {
            await setupStorage()
        }
    }

    private func setupStorage() async {
        do {
            try await cloudStorage.setupDirectories()
        } catch {
            showError(message: "Fehler beim Einrichten des Speichers: \(error.localizedDescription)")
        }
    }

    // MARK: - CloudKit-Sync-Listener

    /// Abonniert die `NSPersistentCloudKitContainer`-Benachrichtigung, die gefeuert wird,
    /// sobald CloudKit neue Daten auf dieses Gerät importiert hat.
    ///
    /// Damit werden neu synchronisierte Dokumente (z. B. auf Gerät B nach Import auf Gerät A)
    /// sofort in der UI sichtbar und fehlende PDF-Dateien automatisch heruntergeladen.
    private func subscribeToCloudKitSync() {
        guard cloudKitSyncObserver == nil else { return }

        cloudKitSyncObserver = NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else { return }

                // Nur auf abgeschlossene Import-Events reagieren (nicht auf Export oder Setup)
                guard event.type == .import, event.endDate != nil else { return }

                if let error = event.error {
                    print("⚠️ CloudKit-Sync: Import-Event mit Fehler: \(error)")
                    return
                }

                print("☁️ CloudKit-Sync: Import-Event abgeschlossen — lade Dokumente neu")
                self.loadDocuments()

                Task {
                    await self.restoreCacheIfNeeded()
                }
            }
    }

    // MARK: - Dokumente laden

    func loadDocuments() {
        guard let context = modelContext else {
            print("⚠️ PDFManagerViewModel: loadDocuments() – kein ModelContext gesetzt")
            return
        }

        let descriptor = FetchDescriptor<PDFDocument>(
            sortBy: [SortDescriptor(\.importDate, order: .reverse)]
        )

        do {
            documents = try context.fetch(descriptor)
            print("📋 PDFManagerViewModel: \(documents.count) Dokument(e) geladen")
        } catch {
            showError(message: "Fehler beim Laden der Dokumente: \(error.localizedDescription)")
        }
    }

    // MARK: - iCloud-Cache-Wiederherstellung

    /// Stellt den lokalen Cache nach einer Neuinstallation oder einem CloudKit-Sync wieder her.
    ///
    /// SwiftData + CloudKit synchronisiert die Metadaten automatisch auf neue Geräte.
    /// Die PDF-Binärdaten müssen aber separat von iCloud Drive heruntergeladen werden.
    /// Diese Methode überprüft alle bekannten Dokumente und lädt fehlende Dateien herunter.
    ///
    /// Wird sowohl beim App-Start als auch nach jedem CloudKit-Import-Event aufgerufen.
    func restoreCacheIfNeeded() async {
        // Dokumente neu laden, damit auch frisch synchronisierte erfasst werden
        loadDocuments()

        guard !documents.isEmpty else {
            print("ℹ️ PDFManagerViewModel: restoreCacheIfNeeded() – keine Dokumente vorhanden")
            return
        }

        let missingDocs = documents.filter { doc in
            guard let localPath = doc.localCachePath else { return true }
            return !FileManager.default.fileExists(atPath: localPath)
        }

        guard !missingDocs.isEmpty else {
            print("✅ PDFManagerViewModel: restoreCacheIfNeeded() – alle \(documents.count) Datei(en) im Cache vorhanden")
            return
        }

        print("🔄 PDFManagerViewModel: \(missingDocs.count) von \(documents.count) Datei(en) fehlen im Cache — starte Wiederherstellung")

        isSyncingFromCloud = true
        await cloudStorage.restoreCacheFromICloud(cloudPaths: missingDocs.map(\.cloudPath))

        // Lokale Pfade in der Datenbank aktualisieren
        for document in missingDocs {
            if let restoredURL = await cloudStorage.getLocalURL(for: document.cloudPath) {
                document.localCachePath = restoredURL.path
                print("✅ PDFManagerViewModel: Lokaler Pfad aktualisiert für '\(document.fileName)'")
            } else {
                print("⚠️ PDFManagerViewModel: Kein lokaler Pfad gefunden für '\(document.fileName)'")
            }
        }
        try? modelContext?.save()
        loadDocuments()

        isSyncingFromCloud = false
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

    // MARK: - PDF importieren

    func importPDF(from url: URL, toFolder folder: Folder? = nil) async {
        isImporting = true

        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw CloudStorageError.fileOperationFailed("Keine Berechtigung für Dateizugriff")
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // Duplikat-Prüfung vor dem Kopieren
            let hash = try computeSHA256(for: url)
            if let existing = try findDuplicate(hash: hash) {
                let name = existing.title ?? existing.fileName
                showError(message: "Diese Datei wurde bereits importiert als \"\(name)\".")
                isImporting = false
                return
            }

            // Datei in iCloud Drive und lokalem Cache speichern
            let (cloudPath, localPath, fileSize) = try await cloudStorage.importPDF(from: url)

            let pageCount = textExtractor.getPageCount(from: URL(fileURLWithPath: localPath)) ?? 0

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

            modelContext?.insert(document)
            try modelContext?.save()

            loadDocuments()

            Task {
                await generateSummary(for: document)
            }

        } catch {
            showError(message: "Import fehlgeschlagen: \(error.localizedDescription)")
        }

        isImporting = false
    }

    // MARK: - KI-Zusammenfassung

    func generateSummary(for document: PDFDocument) async {
        // Falls lokale Datei nicht vorhanden, zuerst von iCloud herunterladen
        let localPath: String
        if let cachedPath = document.localCachePath,
           FileManager.default.fileExists(atPath: cachedPath) {
            localPath = cachedPath
        } else {
            do {
                let downloadedURL = try await cloudStorage.downloadFromICloud(cloudPath: document.cloudPath)
                document.localCachePath = downloadedURL.path
                try? modelContext?.save()
                localPath = downloadedURL.path
            } catch {
                document.summaryStatus = .failed
                document.summary = "Datei konnte nicht von iCloud geladen werden: \(error.localizedDescription)"
                try? modelContext?.save()
                return
            }
        }

        document.summaryStatus = .processing
        try? modelContext?.save()
        loadDocuments()

        do {
            let result = try textExtractor.extractText(from: URL(fileURLWithPath: localPath))
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

    // MARK: - PDF löschen

    func deleteDocument(_ document: PDFDocument) {
        Task {
            if let localPath = document.localCachePath {
                await PDFThumbnailCache.shared.evict(for: URL(fileURLWithPath: localPath))
            }
            do {
                try await cloudStorage.deletePDF(cloudPath: document.cloudPath)
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
    }

    // MARK: - Lokale URL ermitteln

    /// Gibt die lokale URL eines Dokuments zurück, falls sie im Cache vorhanden ist.
    func getLocalURL(for document: PDFDocument) -> URL? {
        if let localPath = document.localCachePath,
           FileManager.default.fileExists(atPath: localPath) {
            return URL(fileURLWithPath: localPath)
        }
        // Kein synchroner Fallback mehr möglich da actor — für sofortigen Zugriff
        // nur den lokalen Cache nutzen; für iCloud-Download `getLocalURLDownloading` verwenden.
        return nil
    }

    /// Asynchrone Variante: Wartet auf den vollständigen iCloud-Download.
    func getLocalURLDownloading(for document: PDFDocument) async throws -> URL {
        if let localPath = document.localCachePath,
           FileManager.default.fileExists(atPath: localPath) {
            return URL(fileURLWithPath: localPath)
        }

        let url = try await cloudStorage.downloadFromICloud(cloudPath: document.cloudPath)
        document.localCachePath = url.path
        try? modelContext?.save()
        return url
    }

    // MARK: - Hilfsmethoden

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
