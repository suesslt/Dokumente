import SwiftUI
import SwiftData

@main
struct DokumenteApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PDFDocument.self,
            Folder.self
        ])

        // Stufe 1: Versuche mit CloudKit-Sync (nur auf echten Geräten).
        // Im Simulator ist kein echtes iCloud-Konto verfügbar → CloudKit überspringen.
        // Voraussetzung: Alle Modell-Attribute müssen einen Default-Wert haben (CloudKit-Anforderung).
        #if !targetEnvironment(simulator)
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            print("✅ DokumenteApp: SwiftData mit CloudKit-Sync gestartet")
            return container
        }
        #endif

        // Stufe 2: CloudKit-Sync fehlgeschlagen (oder Simulator).
        // Versuche lokale Datenbank ohne Sync, aber mit Migration der bestehenden Daten.
        #if targetEnvironment(simulator)
        print("ℹ️ DokumenteApp: Simulator erkannt – starte ohne iCloud-Sync (lokale Datenbank).")
        #else
        print("⚠️ DokumenteApp: CloudKit nicht verfügbar, starte ohne iCloud-Sync.")
        print("   Mögliche Ursachen: Fehlende Entitlements, kein iCloud-Account, falscher Container")
        #endif
        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            print("✅ DokumenteApp: SwiftData lokal (ohne CloudKit) gestartet")
            return container
        }

        // Stufe 3: Migration fehlgeschlagen — bestehende Datenbank löschen und neu anlegen.
        // Tritt auf, wenn das Schema inkompatibel mit der alten DB ist und keine Migration möglich ist.
        print("⚠️ DokumenteApp: Migration fehlgeschlagen — lösche alte Datenbank und starte neu.")
        let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
        let relatedFiles = [storeURL,
                            storeURL.appendingPathExtension("shm"),
                            storeURL.appendingPathExtension("wal")]
        for file in relatedFiles {
            try? FileManager.default.removeItem(at: file)
        }
        let freshLocalConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        if let container = try? ModelContainer(for: schema, configurations: [freshLocalConfig]) {
            print("✅ DokumenteApp: Neue lokale Datenbank angelegt (Daten wurden zurückgesetzt)")
            return container
        }

        // Stufe 4: Absoluter Notfall-Fallback — In-Memory (keine Persistenz).
        print("❌ DokumenteApp: Alle Datenbankversuche fehlgeschlagen, starte im In-Memory-Modus.")
        let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [memoryConfig])
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
