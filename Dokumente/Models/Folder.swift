import Foundation
import SwiftData

/// SwiftData-Modell für hierarchische Ordnerstruktur.
///
/// Ordner können:
/// - PDFs enthalten
/// - Unterordner enthalten (hierarchische Struktur)
/// - Umbenannt, verschoben und gelöscht werden
@Model
final class Folder: Hashable {
    // MARK: - Identifikation
    
    var id: UUID
    var name: String
    
    // MARK: - Hierarchie
    
    /// Parent-Ordner (nil = Root-Ebene)
    var parent: Folder?
    
    /// Unterordner
    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    var subfolders: [Folder]
    
    /// PDFs in diesem Ordner
    @Relationship(deleteRule: .nullify, inverse: \PDFDocument.folder)
    var documents: [PDFDocument]
    
    // MARK: - Metadaten
    
    /// Erstellungsdatum
    var createdDate: Date
    
    /// Sortierreihenfolge (für manuelle Sortierung)
    var sortOrder: Int
    
    // MARK: - Computed Properties
    
    /// Gibt alle Parent-Ordner zurück (für Breadcrumb-Navigation)
    var breadcrumbs: [Folder] {
        var path: [Folder] = []
        var current: Folder? = self
        
        while let folder = current {
            path.insert(folder, at: 0)
            current = folder.parent
        }
        
        return path
    }
    
    /// Prüft ob dieser Ordner ein Vorfahre des anderen Ordners ist
    func isAncestor(of folder: Folder) -> Bool {
        var current: Folder? = folder.parent
        
        while let parent = current {
            if parent.id == self.id {
                return true
            }
            current = parent.parent
        }
        
        return false
    }
    
    // MARK: - Initialisierung
    
    init(
        id: UUID = UUID(),
        name: String,
        parent: Folder? = nil,
        createdDate: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.parent = parent
        self.subfolders = []
        self.documents = []
        self.createdDate = createdDate
        self.sortOrder = sortOrder
    }
    
    // MARK: - Hashable Conformance
    
    static func == (lhs: Folder, rhs: Folder) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
