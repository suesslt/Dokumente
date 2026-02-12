# Dokumente

**Dokumente** ist eine intelligente PDF-Verwaltungsanwendung für iOS, die automatisch Zusammenfassungen, Metadaten und Schlüsselwörter aus Ihren Dokumenten extrahiert.

## Features

### 🤖 KI-gestützte Dokumentenanalyse
- Automatische Zusammenfassung mit Claude AI
- Extraktion von Autor, Titel und Erstellungsdatum
- Intelligente Schlüsselwörter-Generierung

### 📝 Bearbeitbare Metadaten
- Titel und Zusammenfassung können manuell bearbeitet werden
- Änderungen werden automatisch gespeichert

### ☁️ iCloud-Synchronisation
- Automatische Synchronisation über iCloud Drive
- Lokal gecachte Dateien für schnellen Zugriff

### 📁 Ordnerverwaltung
- Hierarchische Ordnerstruktur
- Drag & Drop zum Organisieren von PDFs
- Unbenennen und Löschen von Ordnern

### 🔍 Detaillierte Dokumentinformationen
- Dateiname, Seitenzahl, Dateigröße
- Erstellungs- und Importdatum
- Visuell ansprechende Tag-Darstellung

### 🎨 Moderne iOS-UI
- Native SwiftUI-Implementierung
- NavigationSplitView für iPad
- Adaptive Layouts für iPhone und iPad
- Responsive und performant

## Systemanforderungen

- iOS 17.0 oder neuer
- Xcode 15.0 oder neuer
- Claude API Key (für automatische Zusammenfassungen)

## Installation

1. Projekt in Xcode öffnen
2. Wähle ein iOS-Deployment-Ziel (iPhone oder iPad)
3. Claude API Key in den Einstellungen eingeben
4. Build & Run

## App-Icon

Für die Verwendung in einer veröffentlichten App:
1. Erstelle ein 1024x1024 App-Icon
2. Füge es zu `Assets.xcassets/AppIcon` hinzu

## Verwendung

### PDF importieren
- Tippe auf das "+" Symbol
- Wähle eine oder mehrere PDF-Dateien aus
- Die App erstellt automatisch eine Zusammenfassung

### Dokumente verwalten
- Wähle ein PDF aus der Liste, um Details anzuzeigen
- Bearbeite Titel und Zusammenfassung mit dem Stift-Symbol
- Organisiere PDFs in Ordnern per Drag & Drop
- Lösche Dokumente über das Kontextmenü

### API-Key konfigurieren
- Öffne die Einstellungen (Zahnrad-Symbol)
- Gib deinen Claude API Key ein
- Der Key wird sicher im iOS Keychain gespeichert

### Ordner erstellen
- Tippe auf "Neuer Ordner" in der Sidebar
- Benenne den Ordner
- Verschiebe PDFs per Drag & Drop oder über das Kontextmenü

## Technologie-Stack

- **Framework**: SwiftUI
- **Datenpersistenz**: SwiftData
- **Cloud-Sync**: iCloud Drive
- **PDF-Verarbeitung**: PDFKit
- **KI-Integration**: Claude API (Anthropic)
- **Sicherheit**: iOS Keychain

## Lizenz

[Lizenz hinzufügen]

## Autor

[Autor hinzufügen]
