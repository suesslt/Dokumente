import SwiftUI
import SwiftData

/// View 1: Zeigt alle Ordner an (iOS Files App Style)
/// "Alle PDFs" ist immer zuoberst
struct FolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.sortOrder) private var allFolders: [Folder]
    
    @ObservedObject var viewModel: PDFManagerViewModel
    
    @State private var searchText = ""
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var editingFolder: Folder?
    @State private var editingName = ""
    
    // Zeige Ordner-Liste oder PDF-Suchergebnisse
    private var isSearching: Bool {
        !searchText.isEmpty
    }
    
    // Gefilterte PDFs über alle Ordner hinweg
    private var filteredDocuments: [PDFDocument] {
        if searchText.isEmpty {
            return []
        }
        
        return viewModel.documents.filter { doc in
            let title = doc.title ?? doc.fileName
            return title.localizedCaseInsensitiveContains(searchText) ||
                   (doc.author?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    // Berechne Anzahl PDFs pro Ordner
    private func documentCount(for folder: Folder?) -> Int {
        if let folder = folder {
            return folder.documents?.count ?? 0
        } else {
            // "Alle PDFs" = alle Dokumente ohne Ordner
            return viewModel.documents.filter { $0.folder == nil }.count
        }
    }
    
    var body: some View {
        Group {
            if isSearching {
                // Zeige gefilterte PDF-Liste beim Suchen
                pdfSearchResults
            } else {
                // Zeige normale Ordner-Liste
                folderList
            }
        }
        .searchable(text: $searchText, prompt: "PDFs durchsuchen")
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
    
    // MARK: - Folder List
    
    private var folderList: some View {
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
    }
    
    // MARK: - PDF Search Results
    
    private var pdfSearchResults: some View {
        Group {
            if filteredDocuments.isEmpty {
                emptySearchState
            } else {
                documentList
            }
        }
    }
    
    private var documentList: some View {
        List {
            ForEach(filteredDocuments) { document in
                NavigationLink {
                    PDFDetailView(document: document, viewModel: viewModel)
                } label: {
                    DocumentRow(document: document)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.deleteDocument(document)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var emptySearchState: some View {
        ContentUnavailableView {
            Label("Keine PDFs", systemImage: "doc.text")
        } description: {
            Text("Keine Ergebnisse für \"\(searchText)\"")
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
        for document in folder.documents ?? [] {
            document.folder = nil
        }
        
        modelContext.delete(folder)
        try? modelContext.save()
        viewModel.loadDocuments()
    }
}

// MARK: - Document Row (reused from PDFListView)

private struct DocumentRow: View {
    let document: PDFDocument
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            DocumentThumbnail(document: document)
                .frame(width: 44, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title ?? document.fileName)
                    .font(.body)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if let author = document.author, !author.isEmpty {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if document.pageCount > 0 {
                        if let author = document.author, !author.isEmpty {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("\(document.pageCount) Seiten")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Zeige Ordnername wenn PDF in Ordner ist
                    if let folder = document.folder {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.caption2)
                            Text(folder.name)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Status-Indikator
            if document.summaryStatus == .processing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Document Thumbnail (reused from PDFListView)

private struct DocumentThumbnail: View {
    let document: PDFDocument
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        guard let localPath = document.localCachePath else { return }
        let url = URL(fileURLWithPath: localPath)
        
        if let cached = await PDFThumbnailCache.shared.thumbnail(for: url) {
            thumbnail = cached
        }
    }
}

#Preview {
    NavigationStack {
        FolderView(viewModel: PDFManagerViewModel())
    }
    .modelContainer(for: [PDFDocument.self, Folder.self], inMemory: true)
}
