import SwiftUI
import SwiftData

@main
struct DokumenteApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PDFDocument.self,
            Folder.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none // Using manual iCloud file sync instead
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

extension Notification.Name {
    static let importPDF      = Notification.Name("importPDF")
    static let deleteAllPDFs  = Notification.Name("deleteAllPDFs")
}
