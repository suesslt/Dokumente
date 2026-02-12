import SwiftUI
import PDFKit

/// View 3: Zeigt ein PDF mit optionalen Zusatzinformationen an
struct PDFDetailView: View {
    let document: PDFDocument
    @ObservedObject var viewModel: PDFManagerViewModel
    
    @State private var showInfo = false
    @State private var pdfDocument: PDFDocument?
    
    var body: some View {
        ZStack {
            // PDF anzeigen
            if let url = viewModel.getLocalURL(for: document) {
                PDFKitView(url: url, document: document)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView {
                    Label("PDF nicht verfügbar", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Die Datei konnte nicht geladen werden")
                }
            }
            
            // Zusatzinformationen (optional einblendbar)
            if showInfo {
                InfoPanel(document: document, viewModel: viewModel, isShowing: $showInfo)
            }
        }
        .navigationTitle(document.title ?? document.fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInfo.toggle()
                } label: {
                    Image(systemName: showInfo ? "info.circle.fill" : "info.circle")
                }
            }
        }
    }
}

// MARK: - PDFKit View

private struct PDFKitView: UIViewRepresentable {
    let url: URL
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        // PDF laden
        if let pdfDocument = PDFKit.PDFDocument(url: url) {
            pdfView.document = pdfDocument
            
            // Letzte Seite wiederherstellen
            if let lastPage = document.lastPageIndex,
               lastPage < pdfDocument.pageCount,
               let page = pdfDocument.page(at: lastPage) {
                pdfView.go(to: page)
            }
        }
        
        // Benachrichtigungen für Seitenwechsel
        NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: pdfView,
            queue: .main
        ) { _ in
            if let currentPage = pdfView.currentPage,
               let pageIndex = pdfView.document?.index(for: currentPage) {
                document.lastPageIndex = pageIndex
            }
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Updates werden automatisch von PDFKit gehandhabt
    }
}

// MARK: - Info Panel

private struct InfoPanel: View {
    let document: PDFDocument
    @ObservedObject var viewModel: PDFManagerViewModel
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Informationen")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        isShowing = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Titel
                        InfoRow(
                            label: "Titel",
                            value: document.title ?? document.fileName
                        )
                        
                        // Autor
                        if let author = document.author, !author.isEmpty {
                            InfoRow(label: "Autor", value: author)
                        }
                        
                        // Datum
                        if let dateCreated = document.dateCreated, !dateCreated.isEmpty {
                            InfoRow(label: "Erstellt", value: formatDate(dateCreated))
                        }
                        
                        // Seitenzahl
                        InfoRow(label: "Seiten", value: "\(document.pageCount)")
                        
                        // Dateigrösse
                        InfoRow(label: "Grösse", value: formatFileSize(document.fileSize))
                        
                        // Keywords
                        if let keywords = document.keywords, !keywords.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Schlüsselwörter")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(keywords.components(separatedBy: ";"), id: \.self) { keyword in
                                        Text(keyword.trimmingCharacters(in: .whitespaces))
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(.blue.opacity(0.1))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        
                        // Zusammenfassung
                        if let summary = document.summary, !summary.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Zusammenfassung")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Text(summary)
                                    .font(.body)
                            }
                        } else if document.summaryStatus == .processing {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Zusammenfassung wird erstellt...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else if document.summaryStatus == .failed {
                            Button {
                                viewModel.retryGenerateSummary(for: document)
                            } label: {
                                Label("Erneut versuchen", systemImage: "arrow.clockwise")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
            .shadow(radius: 20)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring, value: isShowing)
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Format: YYYYMMDD → DD.MM.YYYY
        guard dateString.count == 8,
              let year = Int(dateString.prefix(4)),
              let month = Int(dateString.dropFirst(4).prefix(2)),
              let day = Int(dateString.suffix(2)) else {
            return dateString
        }
        
        return String(format: "%02d.%02d.%d", day, month, year)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.body)
        }
    }
}

// MARK: - Flow Layout (für Keywords)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: width, height: y + lineHeight)
        }
    }
}

#Preview {
    NavigationStack {
        PDFDetailView(
            document: PDFDocument(
                fileName: "Example.pdf",
                cloudPath: "/example.pdf",
                summary: "Dies ist eine Beispielzusammenfassung",
                author: "Max Mustermann",
                title: "Beispiel-Dokument",
                pageCount: 42,
                fileSize: 1024000
            ),
            viewModel: PDFManagerViewModel()
        )
    }
}
