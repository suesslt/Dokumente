import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// View 2: Zeigt alle PDFs in einem Ordner (oder "Alle PDFs").
/// Die Dokumentauswahl wird über ein Binding nach oben propagiert,
/// damit die Detail-Spalte im NavigationSplitView aktualisiert wird.
struct PDFListView: View {
    @ObservedObject var viewModel: PDFManagerViewModel
    let folder: Folder?

    /// Binding auf das aktuell geöffnete Dokument (Detail-Spalte).
    @Binding var selectedDocument: PDFDocument?

    @State private var searchText = ""
    @State private var showFileImporter = false
    
    // Gefilterte Dokumente basierend auf Ordner und Suchtext
    private var filteredDocuments: [PDFDocument] {
        let documents = viewModel.documents.filter { doc in
            // Filtere nach Ordner
            if let folder = folder {
                return doc.folder?.id == folder.id
            } else {
                return doc.folder == nil
            }
        }
        
        // Filtere nach Suchtext
        if searchText.isEmpty {
            return documents
        } else {
            return documents.filter { doc in
                let title = doc.title ?? doc.fileName
                return title.localizedCaseInsensitiveContains(searchText) ||
                       (doc.author?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        Group {
            if filteredDocuments.isEmpty {
                emptyState
            } else {
                documentList
            }
        }
        .navigationTitle(folder?.name ?? "Alle PDFs")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "PDFs durchsuchen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFileImporter = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }
    
    // MARK: - Document List

    private var documentList: some View {
        List {
            ForEach(filteredDocuments) { document in
                Button {
                    selectedDocument = document
                } label: {
                    DocumentRow(document: document)
                }
                .listRowBackground(
                    selectedDocument?.id == document.id ? Color.accentColor.opacity(0.15) : Color.clear
                )
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
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("Keine PDFs", systemImage: "doc.text")
        } description: {
            if searchText.isEmpty {
                Text("Importiere dein erstes PDF")
            } else {
                Text("Keine Ergebnisse für \"\(searchText)\"")
            }
        } actions: {
            if searchText.isEmpty {
                Button {
                    showFileImporter = true
                } label: {
                    Text("PDF importieren")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - File Import
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                Task {
                    await viewModel.importPDF(from: url, toFolder: folder)
                }
            }
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Document Row

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
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("\(document.pageCount) Seiten")
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

// MARK: - Document Thumbnail

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
        PDFListView(
            viewModel: PDFManagerViewModel(),
            folder: nil,
            selectedDocument: .constant(nil)
        )
    }
    .modelContainer(for: [PDFDocument.self, Folder.self], inMemory: true)
}
