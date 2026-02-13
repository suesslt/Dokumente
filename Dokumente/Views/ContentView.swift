import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Haupt-Einstiegspunkt der App.
/// Auf dem iPad wird ein dreispaltiges Layout (analog Apple Notes) verwendet:
///   Sidebar = FolderView · Content = PDFListView · Detail = PDFDetailView
/// Auf dem iPhone kollabiert NavigationSplitView automatisch zu einem NavigationStack.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PDFManagerViewModel()

    /// Aktuell gewählter Ordner (nil = "Alle PDFs").
    /// Ein optionales Optional: .none bedeutet "nichts selektiert", .some(nil) = "Alle PDFs".
    @State private var selectedFolder: Folder?? = .some(nil)

    /// Aktuell geöffnetes Dokument.
    @State private var selectedDocument: PDFDocument?

    @State private var showFileImporter = false
    @State private var showSettings = false
    @State private var showError = false
    @State private var errorMessage: String?

    /// Entpackter Wert von selectedFolder für die Content-Spalte.
    /// Solange kein Ordner ausgewählt ist, bleibt die mittlere Spalte leer.
    private var activeFolder: Folder?? { selectedFolder }

    var body: some View {
        NavigationSplitView {
            // MARK: Sidebar – Ordner-Übersicht
            FolderView(
                viewModel: viewModel,
                selectedFolder: $selectedFolder,
                selectedDocument: $selectedDocument
            )
            .navigationTitle("Dokumente")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(viewModel.isImporting)
                }
            }
        } content: {
            // MARK: Content – PDF-Liste des gewählten Ordners
            if let folder = activeFolder {
                PDFListView(
                    viewModel: viewModel,
                    folder: folder,
                    selectedDocument: $selectedDocument
                )
            } else {
                ContentUnavailableView(
                    "Kein Ordner gewählt",
                    systemImage: "folder",
                    description: Text("Wähle einen Ordner aus der Seitenleiste.")
                )
            }
        } detail: {
            // MARK: Detail – gewähltes Dokument
            if let document = selectedDocument {
                PDFDetailView(document: document, viewModel: viewModel)
            } else {
                ContentUnavailableView(
                    "Kein Dokument gewählt",
                    systemImage: "doc.text",
                    description: Text("Wähle ein PDF aus der Liste.")
                )
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .alert("Fehler", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
        .overlay {
            if viewModel.isImporting {
                ImportingOverlay()
            } else if viewModel.isSyncingFromCloud {
                SyncingOverlay()
            }
        }
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.loadDocuments()
            // Stellt fehlende PDF-Dateien aus iCloud wieder her (z.B. nach Neuinstallation)
            Task {
                await viewModel.restoreCacheIfNeeded()
            }
        }
        .onReceive(viewModel.$errorMessage) { message in
            if let message = message {
                errorMessage = message
                showError = true
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                Task {
                    // Importiere in den aktuell gewählten Ordner (nil = "Alle PDFs")
                    let folder: Folder? = selectedFolder ?? nil
                    await viewModel.importPDF(from: url, toFolder: folder)
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Importing Overlay

private struct ImportingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("PDF wird importiert...")
                    .font(.headline)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Syncing Overlay

private struct SyncingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("PDFs werden aus iCloud geladen…")
                    .font(.headline)
                Text("Bitte warte kurz.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PDFDocument.self, Folder.self], inMemory: true)
}
