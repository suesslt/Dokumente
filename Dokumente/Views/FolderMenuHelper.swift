import SwiftUI
import SwiftData

/// Hilfsfunktionen für Ordner-Operationen
struct FolderMenuHelper {
    @Environment(\.modelContext) private var modelContext
    
    /// Erstellt ein Menü zum Verschieben eines PDFs in einen Ordner
    @ViewBuilder
    static func makeMoveToFolderMenu(
        for document: PDFDocument,
        allFolders: [Folder],
        currentFolder: Folder?,
        modelContext: ModelContext
    ) -> some View {
        Menu {
            // "Keine Ordner" Option
            Button {
                document.folder = nil
                try? modelContext.save()
            } label: {
                Label(
                    currentFolder == nil ? "✓ Keine Ordner" : "Keine Ordner",
                    systemImage: "folder"
                )
            }
            
            Divider()
            
            // Root-Ordner
            ForEach(allFolders.filter { $0.parent == nil }, id: \.id) { folder in
                FolderMenuItem(
                    folder: folder,
                    document: document,
                    currentFolder: currentFolder,
                    level: 0,
                    modelContext: modelContext
                )
            }
        } label: {
            Label("In Ordner verschieben", systemImage: "folder")
        }
    }
}

/// Rekursive Menü-Item für Ordner-Hierarchie
private struct FolderMenuItem: View {
    let folder: Folder
    let document: PDFDocument
    let currentFolder: Folder?
    let level: Int
    let modelContext: ModelContext
    
    var body: some View {
        if folder.subfolders.isEmpty {
            // Leaf-Ordner - einfacher Button
            Button {
                moveDocument()
            } label: {
                Label(
                    isSelected ? "✓ \(folder.name)" : folder.name,
                    systemImage: "folder"
                )
            }
        } else {
            // Ordner mit Unterordnern - Menü
            Menu {
                // Dieser Ordner selbst
                Button {
                    moveDocument()
                } label: {
                    Label(
                        isSelected ? "✓ \(folder.name)" : folder.name,
                        systemImage: "folder"
                    )
                }
                
                Divider()
                
                // Unterordner
                ForEach(folder.subfolders.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { subfolder in
                    FolderMenuItem(
                        folder: subfolder,
                        document: document,
                        currentFolder: currentFolder,
                        level: level + 1,
                        modelContext: modelContext
                    )
                }
            } label: {
                Label(folder.name, systemImage: "folder")
            }
        }
    }
    
    private var isSelected: Bool {
        currentFolder?.id == folder.id
    }
    
    private func moveDocument() {
        document.folder = folder
        try? modelContext.save()
    }
}
