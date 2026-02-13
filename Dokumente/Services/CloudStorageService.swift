import Foundation

// MARK: - Fehlertypen

enum CloudStorageError: Error, LocalizedError {
    case iCloudNotAvailable
    case containerNotFound
    case fileOperationFailed(String)
    case fileNotFound
    case downloadTimeout

    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud ist nicht verfügbar. Bitte melde dich in den Einstellungen bei iCloud an."
        case .containerNotFound:
            return "iCloud-Container konnte nicht gefunden werden."
        case .fileOperationFailed(let reason):
            return "Dateioperaton fehlgeschlagen: \(reason)"
        case .fileNotFound:
            return "Datei wurde nicht gefunden."
        case .downloadTimeout:
            return "Download von iCloud hat zu lange gedauert. Bitte überprüfe deine Internetverbindung."
        }
    }
}

// MARK: - CloudStorageService

/// Verwaltet PDF-Dateien in iCloud Drive.
///
/// Architektur:
/// - **Metadaten** (Titel, Autor, Zusammenfassung etc.) werden über SwiftData + CloudKit synchronisiert.
/// - **PDF-Binärdaten** werden in iCloud Drive gespeichert und automatisch auf alle Geräte übertragen.
/// - Ein **lokaler Cache** sorgt für Offline-Zugriff ohne erneuten Download.
///
/// Als `actor` implementiert, um thread-sicheren Zugriff auf `_cachedContainerURL` zu garantieren.
///
/// ⚠️ Wichtig: Die `containerIdentifier` muss mit dem iCloud-Container in der
///    Xcode-Projekteinstellung unter „Signing & Capabilities → iCloud → Containers" übereinstimmen.
actor CloudStorageService {
    static let shared = CloudStorageService()

    /// Muss mit dem iCloud-Container in Xcode übereinstimmen.
    /// Format: "iCloud.<deine-Bundle-ID>"
    private let containerIdentifier = "iCloud.com.suessli.dokumente"

    /// Unterordner im iCloud Documents-Verzeichnis
    private let documentsSubfolder = "PDFs"

    private init() {}

    // MARK: - iCloud Container-URLs

    /// Gecachte Container-URL — wird durch `resolveICloudContainer()` befüllt.
    private var _cachedContainerURL: URL?

    var iCloudContainerURL: URL? { _cachedContainerURL }

    /// Zielordner für PDFs in iCloud Drive.
    ///
    /// ⚠️ Wichtig: Für nicht-Document-Based Apps muss der Pfad **ohne** `Documents/`-Präfix
    /// direkt unter dem Container-Root liegen. Nur so erkennt iCloud die Dateien als
    /// synchronisierbar. Der `Documents/`-Unterordner ist ausschließlich für
    /// Document-Based Apps (UIDocumentBrowserViewController) reserviert.
    ///
    /// Korrekt:   .../iCloud~com~suessli~dokumente/PDFs/
    /// Falsch:    .../iCloud~com~suessli~dokumente/Documents/PDFs/
    var iCloudDocumentsURL: URL? {
        _cachedContainerURL?
            .appendingPathComponent(documentsSubfolder)
    }

    var localCacheURL: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("PDFCache")
    }

    var isICloudAvailable: Bool { _cachedContainerURL != nil }

    // MARK: - iCloud Container auflösen

    /// Initialisiert den iCloud-Ubiquity-Container auf einem **Background-Thread**.
    ///
    /// `FileManager.url(forUbiquityContainerIdentifier:)` darf laut Apple-Dokumentation
    /// **niemals** auf dem Main Thread aufgerufen werden — der erste Aufruf blockiert,
    /// bis der iCloud-Daemon antwortet.
    ///
    /// Wichtig: Diese Methode nutzt `nonisolated` + `Task.detached`, um den blockierenden
    /// Aufruf sicher außerhalb des Actors auszuführen, ohne eine Actor-Reentrancy-Falle
    /// oder einen Deadlock zu riskieren.
    ///
    /// - Returns: `true` wenn iCloud verfügbar ist, sonst `false`.
    @discardableResult
    func resolveICloudContainer() async -> Bool {
        // Bereits aufgelöst? Gecachten Wert sofort zurückgeben.
        if _cachedContainerURL != nil {
            print("☁️ CloudStorageService: Container bereits gecacht → \(_cachedContainerURL!.path)")
            return true
        }

        // `url(forUbiquityContainerIdentifier:)` blockiert beim ersten Aufruf und darf
        // NICHT auf dem Main Thread oder direkt im Actor-Kontext laufen.
        // Task.detached führt den Closure auf einem echten Background-Thread aus.
        let resolvedURL: URL? = await Task.detached(priority: .userInitiated) {
            print("☁️ CloudStorageService: Suche iCloud-Container '\(self.containerIdentifier)' im Hintergrund…")
            let url = FileManager.default.url(
                forUbiquityContainerIdentifier: self.containerIdentifier
            )
            if let url {
                print("☁️ CloudStorageService: Container gefunden → \(url.path)")
            } else {
                print("⚠️ CloudStorageService: Container NICHT gefunden. Mögliche Ursachen:")
                print("   1. Kein iCloud-Account auf dem Gerät angemeldet")
                print("   2. iCloud Drive in den Einstellungen deaktiviert")
                print("   3. Container-ID '\(self.containerIdentifier)' stimmt nicht mit Xcode überein")
                print("   4. Fehlende iCloud-Entitlements im App-Profil")
                print("   5. Simulatorbeschränkung (bevorzuge echtes Gerät zum Testen)")
            }
            return url
        }.value

        _cachedContainerURL = resolvedURL
        return resolvedURL != nil
    }

    // MARK: - Verzeichnis-Setup

    /// Initialisiert den iCloud-Container und legt alle nötigen Verzeichnisse an.
    /// Muss beim App-Start aufgerufen werden, **bevor** andere Dateioperationen stattfinden.
    func setupDirectories() async throws {
        print("☁️ CloudStorageService: setupDirectories() gestartet")

        // Lokalen Cache-Ordner anlegen (funktioniert immer, unabhängig von iCloud)
        try FileManager.default.createDirectory(at: localCacheURL, withIntermediateDirectories: true)
        print("📁 CloudStorageService: Lokaler Cache-Ordner: \(localCacheURL.path)")

        let available = await resolveICloudContainer()
        print("☁️ CloudStorageService: iCloud verfügbar nach resolveICloudContainer: \(available)")

        if let iCloudDocsURL = iCloudDocumentsURL {
            do {
                try FileManager.default.createDirectory(at: iCloudDocsURL, withIntermediateDirectories: true)
                print("📁 CloudStorageService: iCloud-Ordner angelegt: \(iCloudDocsURL.path)")
            } catch {
                print("⚠️ CloudStorageService: Konnte iCloud-Ordner nicht anlegen: \(error)")
                throw error
            }
        } else {
            print("ℹ️ CloudStorageService: Kein iCloud-Ordner angelegt (iCloud nicht verfügbar)")
        }
    }

    // MARK: - PDF importieren

    /// Importiert eine PDF-Datei aus einer externen URL.
    ///
    /// 1. Datei wird immer in den lokalen Cache kopiert (für Offline-Zugriff).
    /// 2. Falls iCloud verfügbar ist, wird die Datei zusätzlich in iCloud Drive gespeichert.
    ///
    /// - Parameter sourceURL: Sicherheitsbezogene URL der Quelldatei (z.B. aus dem Dokumenten-Picker)
    /// - Returns: Tupel aus Cloud-Pfad (relativer Dateiname), lokalem Cache-Pfad und Dateigröße
    func importPDF(from sourceURL: URL) async throws -> (cloudPath: String, localPath: String, fileSize: Int64) {
        let fileName = sourceURL.lastPathComponent
        let uniqueFileName = "\(UUID().uuidString)_\(fileName)"

        print("📥 CloudStorageService: Importiere '\(fileName)' als '\(uniqueFileName)'")

        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        print("📥 CloudStorageService: Dateigröße: \(fileSize) Bytes")

        // Immer zuerst in lokalen Cache kopieren
        let localDestination = localCacheURL.appendingPathComponent(uniqueFileName)
        try FileManager.default.copyItem(at: sourceURL, to: localDestination)
        print("✅ CloudStorageService: In lokalem Cache gespeichert: \(localDestination.path)")

        // Parallel in iCloud Drive speichern (falls verfügbar)
        if let iCloudDocsURL = iCloudDocumentsURL {
            let cloudDestination = iCloudDocsURL.appendingPathComponent(uniqueFileName)
            // Kopiere aus dem lokalen Cache (nicht erneut von der Security-Scoped URL)
            try FileManager.default.copyItem(at: localDestination, to: cloudDestination)
            print("✅ CloudStorageService: In iCloud Drive gespeichert: \(cloudDestination.path)")
        } else {
            print("ℹ️ CloudStorageService: iCloud nicht verfügbar — nur lokal gespeichert")
        }

        return (uniqueFileName, localDestination.path, fileSize)
    }

    // MARK: - Lokale URL ermitteln

    /// Gibt die lokale URL einer PDF-Datei zurück.
    ///
    /// Reihenfolge:
    /// 1. Lokaler Cache → sofort verfügbar
    /// 2. iCloud Drive → wird in Cache kopiert und zurückgegeben
    /// 3. nil → Datei nicht gefunden
    func getLocalURL(for cloudPath: String) -> URL? {
        let localURL = localCacheURL.appendingPathComponent(cloudPath)

        if FileManager.default.fileExists(atPath: localURL.path) {
            print("📂 CloudStorageService: getLocalURL – Cache-Treffer für '\(cloudPath)'")
            return localURL
        }

        guard let iCloudDocsURL = iCloudDocumentsURL else {
            print("⚠️ CloudStorageService: getLocalURL – iCloud nicht verfügbar, kein Fallback für '\(cloudPath)'")
            return nil
        }

        let cloudURL = iCloudDocsURL.appendingPathComponent(cloudPath)

        guard FileManager.default.fileExists(atPath: cloudURL.path) else {
            print("⚠️ CloudStorageService: getLocalURL – Datei weder im Cache noch in iCloud: '\(cloudPath)'")
            return nil
        }

        // In Cache kopieren und dort zurückgeben
        do {
            try FileManager.default.copyItem(at: cloudURL, to: localURL)
            print("✅ CloudStorageService: getLocalURL – Aus iCloud in Cache kopiert: '\(cloudPath)'")
        } catch {
            print("⚠️ CloudStorageService: getLocalURL – Konnte nicht in Cache kopieren: \(error)")
        }
        return localURL
    }

    // MARK: - PDF aus iCloud herunterladen

    /// Lädt eine PDF-Datei aus iCloud herunter und wartet, bis sie vollständig verfügbar ist.
    ///
    /// Wird benötigt, wenn ein Gerät die Datei noch nicht heruntergeladen hat
    /// (iCloud speichert Dateien als „evicted" Platzhalter).
    ///
    /// - Parameters:
    ///   - cloudPath: Relativer Dateiname (wie in `PDFDocument.cloudPath` gespeichert)
    ///   - timeout: Maximale Wartezeit in Sekunden (Standard: 60 Sekunden)
    /// - Returns: Lokale URL der heruntergeladenen Datei
    func downloadFromICloud(cloudPath: String, timeout: TimeInterval = 60) async throws -> URL {
        // Schon im Cache? Direkt zurückgeben.
        let localURL = localCacheURL.appendingPathComponent(cloudPath)
        if FileManager.default.fileExists(atPath: localURL.path) {
            print("📂 CloudStorageService: downloadFromICloud – Cache-Treffer für '\(cloudPath)'")
            return localURL
        }

        guard let iCloudDocsURL = iCloudDocumentsURL else {
            print("❌ CloudStorageService: downloadFromICloud – iCloud nicht verfügbar (Container nil)")
            throw CloudStorageError.iCloudNotAvailable
        }

        let cloudURL = iCloudDocsURL.appendingPathComponent(cloudPath)

        guard FileManager.default.fileExists(atPath: cloudURL.path) else {
            print("❌ CloudStorageService: downloadFromICloud – Datei nicht in iCloud gefunden: '\(cloudPath)'")
            throw CloudStorageError.fileNotFound
        }

        print("⬇️ CloudStorageService: Starte Download von iCloud für '\(cloudPath)'…")

        // Download starten
        try FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)

        // Warten bis vollständig heruntergeladen (polling mit Timeout)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let resourceValues = try cloudURL.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemIsDownloadingKey
            ])

            let status = resourceValues.ubiquitousItemDownloadingStatus
            print("⬇️ CloudStorageService: Download-Status '\(cloudPath)': \(String(describing: status?.rawValue))")

            if status == .current {
                // Vollständig heruntergeladen – in Cache kopieren
                try? FileManager.default.copyItem(at: cloudURL, to: localURL)
                print("✅ CloudStorageService: Download abgeschlossen und in Cache kopiert: '\(cloudPath)'")
                return localURL
            }

            // 500ms warten, dann erneut prüfen
            try await Task.sleep(for: .milliseconds(500))
        }

        print("❌ CloudStorageService: Download Timeout für '\(cloudPath)' nach \(timeout)s")
        throw CloudStorageError.downloadTimeout
    }

    // MARK: - PDF löschen

    /// Löscht eine PDF-Datei aus dem lokalen Cache und aus iCloud Drive.
    func deletePDF(cloudPath: String) throws {
        let localURL = localCacheURL.appendingPathComponent(cloudPath)
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
            print("🗑️ CloudStorageService: Aus lokalem Cache gelöscht: '\(cloudPath)'")
        }

        if let iCloudDocsURL = iCloudDocumentsURL {
            let cloudURL = iCloudDocsURL.appendingPathComponent(cloudPath)
            if FileManager.default.fileExists(atPath: cloudURL.path) {
                try FileManager.default.removeItem(at: cloudURL)
                print("🗑️ CloudStorageService: Aus iCloud Drive gelöscht: '\(cloudPath)'")
            }
        } else {
            print("ℹ️ CloudStorageService: deletePDF – iCloud nicht verfügbar, nur lokale Löschung")
        }
    }

    // MARK: - iCloud-Sync

    /// Gibt alle PDF-Dateinamen zurück, die in iCloud Drive gespeichert sind.
    /// Startet den Download für noch nicht heruntergeladene Dateien.
    func syncFromICloud() async throws -> [String] {
        guard let iCloudDocsURL = iCloudDocumentsURL else {
            print("ℹ️ CloudStorageService: syncFromICloud – iCloud nicht verfügbar")
            return []
        }

        let fileManager = FileManager.default
        try? fileManager.startDownloadingUbiquitousItem(at: iCloudDocsURL)

        let contents = try fileManager.contentsOfDirectory(
            at: iCloudDocsURL,
            includingPropertiesForKeys: [
                .isUbiquitousItemKey,
                .ubiquitousItemDownloadingStatusKey
            ],
            options: .skipsHiddenFiles
        )

        let pdfFiles = contents
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .map { $0.lastPathComponent }

        print("☁️ CloudStorageService: syncFromICloud – \(pdfFiles.count) PDF(s) in iCloud gefunden")
        return pdfFiles
    }

    // MARK: - Cache-Wiederherstellung nach Neuinstallation

    /// Stellt fehlende Cache-Einträge wieder her, indem Dateien von iCloud heruntergeladen werden.
    ///
    /// Nützlich nach einer Neuinstallation der App, wenn der lokale Cache leer ist,
    /// die Dateien aber noch in iCloud vorhanden sind.
    ///
    /// - Parameter cloudPaths: Liste aller `cloudPath`-Werte aus der SwiftData-Datenbank
    func restoreCacheFromICloud(cloudPaths: [String]) async {
        print("🔄 CloudStorageService: Starte Cache-Wiederherstellung für \(cloudPaths.count) Datei(en)…")
        var restoredCount = 0
        var failedCount = 0

        for path in cloudPaths {
            let localURL = localCacheURL.appendingPathComponent(path)
            guard !FileManager.default.fileExists(atPath: localURL.path) else {
                print("✅ CloudStorageService: '\(path)' bereits im Cache vorhanden")
                continue
            }

            do {
                _ = try await downloadFromICloud(cloudPath: path)
                restoredCount += 1
            } catch {
                failedCount += 1
                print("⚠️ CloudStorageService: Konnte '\(path)' nicht wiederherstellen: \(error)")
            }
        }

        print("🔄 CloudStorageService: Cache-Wiederherstellung abgeschlossen – \(restoredCount) wiederhergestellt, \(failedCount) fehlgeschlagen")
    }
}
