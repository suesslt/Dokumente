import Foundation
import SwiftData
import UIKit
import UniformTypeIdentifiers
import CoreTransferable

/// Status der KI-generierten Zusammenfassung eines PDF-Dokuments.
enum SummaryStatus: String, Codable {
    case pending     // Warten auf Verarbeitung
    case processing  // KI erstellt gerade die Zusammenfassung
    case completed   // Zusammenfassung erfolgreich erstellt
    case failed      // Fehler bei der Erstellung
}

/// SwiftData-Modell für ein importiertes PDF-Dokument.
///
/// Speichert alle Metadaten eines PDFs inklusive:
/// - Dateisystem-Informationen (Name, Pfad, Größe)
/// - KI-generierte Metadaten (Titel, Autor, Zusammenfassung, Keywords)
/// - Leseposition (zuletzt angezeigte Seite)
///
/// CloudKit-Anforderung: Alle nicht-optionalen Felder müssen einen `@Attribute(.default)`
/// besitzen, damit CoreData/CloudKit das Schema akzeptiert.
@Model
final class PDFDocument {
    // MARK: - Identifikation

    /// CloudKit erfordert einen Default-Wert für alle nicht-optionalen Attribute.
    @Attribute(.preserveValueOnDeletion)
    var id: UUID = UUID()

    @Attribute(.preserveValueOnDeletion)
    var fileName: String = ""

    // MARK: - Dateisystem

    /// Pfad in iCloud Drive
    var cloudPath: String = ""

    /// Pfad im lokalen Cache (falls vorhanden)
    var localCachePath: String?

    /// Zeitpunkt des Imports
    var importDate: Date = Date()

    /// Dateigröße in Bytes
    var fileSize: Int64 = 0

    /// SHA-256 Hash des Dateiinhalts für Duplikat-Erkennung
    var contentHash: String?

    // MARK: - PDF-Eigenschaften

    /// Anzahl der Seiten im PDF
    var pageCount: Int = 0

    /// JPEG-Thumbnail der ersten Seite (extern gespeichert, nicht in der SQLite-Zeile).
    /// Wird einmalig beim Import generiert und via CloudKit auf alle Geräte synchronisiert.
    @Attribute(.externalStorage)
    var thumbnailData: Data?

    // MARK: - KI-generierte Metadaten

    /// Von KI extrahierter oder manuell bearbeiteter Titel
    var title: String?

    /// Von KI generierte Zusammenfassung des Inhalts
    var summary: String?

    /// Von KI extrahierter Autor
    var author: String?

    /// Von KI extrahierte Schlüsselwörter (Semikolon-getrennt)
    var keywords: String?

    /// Erstellungsdatum des Dokuments im Format YYYYMMDD (falls von KI erkannt)
    var dateCreated: String?

    /// Raw-Wert des SummaryStatus (für SwiftData-Kompatibilität)
    /// Default "pending" entspricht SummaryStatus.pending
    var summaryStatusRaw: String = SummaryStatus.pending.rawValue

    /// Status der Zusammenfassungs-Generierung
    var summaryStatus: SummaryStatus {
        get { SummaryStatus(rawValue: summaryStatusRaw) ?? .pending }
        set { summaryStatusRaw = newValue.rawValue }
    }

    // MARK: - Leseposition-Persistenz

    /// Zuletzt angezeigte Seite (0-basiert)
    /// Wird automatisch gespeichert beim Blättern und beim App-Neustart wiederhergestellt
    var lastPageIndex: Int?

    /// Reserviert für zukünftige Verwendung (derzeit nicht genutzt)
    /// Ursprünglich für vertikale Scroll-Position gedacht, wurde aber entfernt,
    /// da es zu unerwarteten Sprüngen zur letzten Seite führte
    var lastScrollPosition: Double?

    // MARK: - Ordner-Zugehörigkeit

    /// Ordner, in dem sich dieses PDF befindet (nil = Root-Ebene / "Alle PDFs")
    var folder: Folder?
    
    // MARK: - Initialisierung

    init(
        id: UUID = UUID(),
        fileName: String,
        cloudPath: String,
        localCachePath: String? = nil,
        importDate: Date = Date(),
        summary: String? = nil,
        author: String? = nil,
        title: String? = nil,
        summaryStatus: SummaryStatus = .pending,
        pageCount: Int = 0,
        fileSize: Int64 = 0,
        thumbnailData: Data? = nil,
        contentHash: String? = nil,
        dateCreated: String? = nil,
        keywords: String? = nil,
        lastPageIndex: Int? = nil,
        lastScrollPosition: Double? = nil,
        folder: Folder? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.cloudPath = cloudPath
        self.localCachePath = localCachePath
        self.importDate = importDate
        self.summary = summary
        self.author = author
        self.title = title
        self.summaryStatusRaw = summaryStatus.rawValue
        self.pageCount = pageCount
        self.fileSize = fileSize
        self.contentHash = contentHash
        self.thumbnailData = thumbnailData
        self.dateCreated = dateCreated
        self.keywords = keywords
        self.lastPageIndex = lastPageIndex
        self.lastScrollPosition = lastScrollPosition
        self.folder = folder
    }
}
// MARK: - Transferable Support (für Drag & Drop)

/// Sendable wrapper for transferring PDF documents
/// Uses the UUID instead of PersistentIdentifier to avoid main actor isolation issues
struct PDFDocumentTransferPayload: Sendable, Codable {
    let documentID: UUID
    
    nonisolated init(documentID: UUID) {
        self.documentID = documentID
    }
    
    // Explicitly provide nonisolated Codable implementations
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.documentID = try container.decode(UUID.self)
    }
    
    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(documentID)
    }
}

extension PDFDocumentTransferPayload: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .pdfDocument)
    }
}

extension PDFDocument {
    /// Custom UTType für PDF Document Models
    static let pdfDocumentType = UTType(exportedAs: "com.scrinium.pdfdocument")

    /// Creates a transferable payload from this document for use in Drag & Drop.
    /// Use this instead of making PDFDocument itself Transferable, because
    /// PersistentModels are not Sendable and cannot cross isolation boundaries.
    func transferPayload() -> PDFDocumentTransferPayload {
        PDFDocumentTransferPayload(documentID: self.id)
    }
}

extension UTType {
    static let pdfDocument = UTType(exportedAs: "com.suessli.dokumente")
}
