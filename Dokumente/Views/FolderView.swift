import SwiftUI
import SwiftData

/// View 1: Zeigt alle Ordner an (iOS Files App Style)
/// "Alle PDFs" ist immer zuoberst
struct FolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.sortOrder) private var allFolders: [Folder]
    
    @ObservedObject var viewModel: PDFManagerViewModel
    
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var editingFolder: Folder?
    @State private var editingName = ""
    
    // Berechne Anzahl PDFs pro Ordner
    private func documentCount(for folder: Folder?) -> Int {
        if let folder = folder {
            return folder.documents.count
        } else {
            // "Alle PDFs" = alle Dokumente ohne Ordner
            return viewModel.documents.filter { $0.folder == nil }.count
        }
    }
    
    var body: some View {
        List {
            // "Alle PDFs" - immer zuoberst
            NavigationLink {
                PDFListView(viewModel: viewModel, folder: nil)
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 32)
                    
                    Text("Alle PDFs")
                        .font(.body)
                    
                    Spacer()
                    
                    Text("\(documentCount(for: nil))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Alle Ordner
            ForEach(allFolders) { folder in
                NavigationLink {
                    PDFListView(viewModel: viewModel, folder: folder)
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .frame(width: 32)
                        
                        Text(folder.name)
                            .font(.body)
                        
                        Spacer()
                        
                        Text("\(documentCount(for: folder))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
               //         Image(systemName: "chevron.right")
                 //           .font(.caption)
                   //         .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteFolder(folder)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                    
                    Button {
                        editingFolder = folder
                        editingName = folder.name
                    } label: {
                        Label("Umbenennen", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewFolderAlert = true
                } label: {
                    Label("Neuer Ordner", systemImage: "folder.badge.plus")
                }
            }
        }
        .alert("Neuer Ordner", isPresented: $showNewFolderAlert) {
            TextField("Ordnername", text: $newFolderName)
            Button("Erstellen") {
                createFolder()
            }
            Button("Abbrechen", role: .cancel) {
                newFolderName = ""
            }
        }
        .alert("Ordner umbenennen", isPresented: Binding(
            get: { editingFolder != nil },
            set: { if !$0 { editingFolder = nil; editingName = "" } }
        )) {
            TextField("Neuer Name", text: $editingName)
            Button("Speichern") {
                renameFolder()
            }
            Button("Abbrechen", role: .cancel) {
                editingFolder = nil
                editingName = ""
            }
        }
    }
    
    // MARK: - Actions
    
    private func createFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty else {
            newFolderName = ""
            return
        }
        
        let folder = Folder(
            name: newFolderName,
            sortOrder: allFolders.count
        )
        
        modelContext.insert(folder)
        try? modelContext.save()
        
        newFolderName = ""
    }
    
    private func renameFolder() {
        guard let folder = editingFolder,
              !editingName.trimmingCharacters(in: .whitespaces).isEmpty else {
            editingFolder = nil
            editingName = ""
            return
        }
        
        folder.name = editingName
        try? modelContext.save()
        
        editingFolder = nil
        editingName = ""
    }
    
    private func deleteFolder(_ folder: Folder) {
        // Verschiebe alle PDFs aus diesem Ordner zu "Alle PDFs"
        for document in folder.documents {
            document.folder = nil
        }
        
        modelContext.delete(folder)
        try? modelContext.save()
        viewModel.loadDocuments()
    }
}

#Preview {
    NavigationStack {
        FolderView(viewModel: PDFManagerViewModel())
    }
    .modelContainer(for: [PDFDocument.self, Folder.self], inMemory: true)
}
