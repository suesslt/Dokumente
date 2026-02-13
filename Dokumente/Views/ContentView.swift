import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Haupt-Einstiegspunkt der App
/// Nutzt NavigationStack für iPhone und iPad
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PDFManagerViewModel()
    
    @State private var showFileImporter = false
    @State private var showSettings = false
    @State private var showError = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            FolderView(viewModel: viewModel)
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
                    await viewModel.importPDF(from: url, toFolder: nil)
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
