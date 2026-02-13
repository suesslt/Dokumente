import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var showAPIKey = false
    @State private var isSaving = false
    @State private var showSaveConfirmation = false
    @State private var errorMessage: String?

    // iCloud-Status wird asynchron geprüft, damit der Main Thread nicht blockiert wird
    private enum ICloudStatus { case checking, available, unavailable }
    @State private var iCloudStatus: ICloudStatus = .checking

    private let keychainService = KeychainService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Der API-Key wird sicher im Keychain gespeichert und für die automatische Zusammenfassung von PDFs verwendet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack {
                            Group {
                                if showAPIKey {
                                    TextField("sk-ant-...", text: $apiKey)
                                        .font(.system(.body, design: .monospaced))
                                } else {
                                    SecureField("sk-ant-...", text: $apiKey)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                            Button {
                                showAPIKey.toggle()
                            } label: {
                                Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.top, 4)
                        }
                        
                        if showSaveConfirmation {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Gespeichert")
                                    .font(.subheadline)
                            }
                            .transition(.opacity)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Claude API Key")
                } footer: {
                    HStack(spacing: 12) {
                        Button {
                            saveAPIKey()
                        } label: {
                            Text("Speichern")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKey.isEmpty || isSaving)
                        
                        if keychainService.hasAPIKey {
                            Button {
                                deleteAPIKey()
                            } label: {
                                Text("Löschen")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                    .padding(.top, 8)
                }

                Section("Anleitung") {
                    VStack(alignment: .leading, spacing: 12) {
                        StepView(number: 1, text: "Besuche console.anthropic.com")
                        StepView(number: 2, text: "Erstelle einen Account oder melde dich an")
                        StepView(number: 3, text: "Navigiere zu 'API Keys'")
                        StepView(number: 4, text: "Erstelle einen neuen API-Key")
                        StepView(number: 5, text: "Kopiere den Key und füge ihn oben ein")
                    }
                    .padding(.vertical, 4)
                }

                Section("Cloud Storage") {
                    HStack {
                        Label("iCloud Drive", systemImage: "icloud")
                        
                        Spacer()
                        
                        switch iCloudStatus {
                        case .checking:
                            ProgressView()
                                .controlSize(.small)
                        case .available:
                            Label("Verbunden", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)
                        case .unavailable:
                            Label("Nicht verfügbar", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.subheadline)
                        }
                    }
                    
                    if iCloudStatus == .unavailable {
                        Text("Bitte melde dich unter Einstellungen → \(UIDevice.current.name.isEmpty ? "Apple ID" : "Apple-ID") → iCloud bei iCloud an und aktiviere iCloud Drive.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadAPIKey()
            }
            .task {
                // iCloud-Status asynchron auf Background-Thread prüfen
                let available = await CloudStorageService.shared.resolveICloudContainer()
                iCloudStatus = available ? .available : .unavailable
            }
        }
    }

    private func loadAPIKey() {
        if let key = try? keychainService.getAPIKey() {
            apiKey = key
        }
    }

    private func saveAPIKey() {
        isSaving = true
        errorMessage = nil

        do {
            try keychainService.saveAPIKey(apiKey)
            withAnimation {
                showSaveConfirmation = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSaveConfirmation = false
                }
            }
        } catch {
            errorMessage = "Fehler beim Speichern: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func deleteAPIKey() {
        do {
            try keychainService.deleteAPIKey()
            apiKey = ""
            errorMessage = nil
        } catch {
            errorMessage = "Fehler beim Löschen: \(error.localizedDescription)"
        }
    }
}

// MARK: - Step View

private struct StepView: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .leading)
            
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    SettingsView()
}
