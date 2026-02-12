# iOS UI-Optimierungen - Dokumentation

## Übersicht

Die App wurde vollständig für iOS optimiert mit nativer Touch-Navigation und gerätespezifischen Layouts.

## Navigation-Flow

### iPhone (Compact Size Class)

```
┌─────────────────┐
│  Ordner-Liste   │  ← Start
│                 │
│  • Alle PDFs    │
│  • Arbeit       │
│  • Privat       │
│  [+] Button     │
└─────────────────┘
        │
        │ Tap auf Ordner
        ↓
┌─────────────────┐
│   PDF-Liste     │
│                 │
│  📄 Dokument 1  │
│  📄 Dokument 2  │
│  📄 Dokument 3  │
│  [+] Button     │
└─────────────────┘
        │
        │ Tap auf PDF
        ↓
┌─────────────────┐
│  PDF-Viewer     │
│                 │
│  [PDF-Inhalt]   │
│                 │
│  ┃ Zusammenfas- │  ← Draggable Bottom Sheet
│  ┃ sung...      │
└─────────────────┘
```

### iPad (Regular Size Class)

```
┌────────┬────────────┬──────────────┐
│ Ordner │ PDF-Liste  │ PDF-Viewer   │
│        │            │              │
│ • Alle │ 📄 Doc 1   │ [PDF]        │
│ • Arb. │ 📄 Doc 2   │              │
│ • Priv.│ 📄 Doc 3   │ Zusammen-    │
│        │            │ fassung...   │
│ [+]    │    [+]     │              │
└────────┴────────────┴──────────────┘
```

## Neue Features

### 1. **Ordner-Liste (FolderListView.swift)**

#### Design
- ✅ Große Touch-Targets (44pt minimum)
- ✅ Farbige Ordner-Icons mit Hintergrund
- ✅ Dokumentanzahl unter jedem Ordner
- ✅ Chevron-Icons für Navigation
- ✅ "Alle PDFs" als Standard-Option
- ✅ Hierarchische Ordnerstruktur mit DisclosureGroup

#### Funktionen
- **[+] Button**: Neuen Ordner erstellen
- **Tap**: Ordner öffnen → Navigation zur PDF-Liste
- **Long Press → Kontextmenü**: Umbenennen, Löschen
- **Inline-Editing**: Direkt in der Liste umbenennen

#### Code-Beispiel
```swift
Button {
    selectedFolder = folder
    onFolderSelected(folder)
} label: {
    HStack(spacing: 16) {
        Image(systemName: "folder.fill")
            .font(.title2)
            .foregroundStyle(.orange)
            .frame(width: 44, height: 44)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        
        VStack(alignment: .leading) {
            Text(folder.name)
                .font(.headline)
            Text("\(folder.documents.count) Dokumente")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        
        Spacer()
        
        Image(systemName: "chevron.right")
    }
}
```

### 2. **PDF-Liste (PDFListViewiOS.swift)**

#### Design
- ✅ Große Thumbnails (60x80pt)
- ✅ Zweizeilige Titel
- ✅ Autor mit Icon
- ✅ Meta-Info: Seiten, Größe, Status
- ✅ Chevron für Navigation
- ✅ Swipe-Actions

#### Funktionen
- **[+] Button**: PDF importieren (in aktuellen Ordner)
- **Tap**: PDF öffnen → Navigation zur Detail-Ansicht
- **Swipe Left**: Löschen
- **Swipe Right**: Zusammenfassung neu erstellen
- **Suchleiste**: Durchsucht Titel, Autor, Zusammenfassung
- **Sort-Menu**: Nach Titel, Autor, Datum sortieren

#### Swipe Actions
```swift
.swipeActions(edge: .trailing) {
    Button(role: .destructive) {
        viewModel.deleteDocument(document)
    } label: {
        Label("Löschen", systemImage: "trash")
    }
}
.swipeActions(edge: .leading) {
    Button {
        viewModel.retryGenerateSummary(for: document)
    } label: {
        Label("Erneut", systemImage: "arrow.clockwise")
    }
    .tint(.blue)
}
```

### 3. **PDF-Viewer (PDFDetailView.swift)**

#### Design
- ✅ Vollbild PDF-Ansicht
- ✅ Draggable Bottom Sheet für Zusammenfassung
- ✅ Drag-Handle zum Verschieben
- ✅ Animierte Übergänge
- ✅ Material-Hintergrund

#### Funktionen
- **Bottom Sheet**: 
  - Drag Handle zum Verschieben
  - Mindesthöhe: 200pt
  - Maximale Höhe: 70% des Bildschirms
  - Smooth Spring-Animation
- **Toggle Button**: Zusammenfassung ein/ausblenden
- **Inline-Editing**: Titel und Zusammenfassung bearbeiten

#### Bottom Sheet Implementation
```swift
VStack(spacing: 0) {
    // Drag Handle
    Capsule()
        .fill(Color.secondary.opacity(0.3))
        .frame(width: 36, height: 5)
        .padding(.top, 8)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    let newHeight = summaryHeight - value.translation.height
                    summaryHeight = max(200, min(maxHeight, newHeight))
                }
        )
    
    summaryPanel
        .frame(height: summaryHeight + dragOffset)
}
.background(.regularMaterial)
.clipShape(RoundedRectangle(cornerRadius: 20))
.shadow(color: .black.opacity(0.2), radius: 20)
```

## Responsive Design

### Size Classes

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

var body: some View {
    Group {
        if horizontalSizeClass == .compact {
            // iPhone: Stack-basierte Navigation
            iPhoneLayout
        } else {
            // iPad: Split View
            iPadLayout
        }
    }
}
```

### iPhone Layout (Compact)
- NavigationStack mit path-basierter Navigation
- Full-Screen Views
- Bottom Sheet für Zusammenfassung
- Back-Buttons automatisch

### iPad Layout (Regular)
- NavigationSplitView mit 3 Spalten
- Side-by-Side Zusammenfassung
- Persistent Selection
- Multitasking-Support

## Touch-Optimierungen

### Minimum Touch Targets
- **Buttons**: 44x44pt (Apple HIG)
- **List Items**: Mindestens 60pt Höhe
- **Icons**: 24-28pt für bessere Erkennbarkeit

### Gestures
- ✅ Tap: Primäre Aktion (Öffnen)
- ✅ Swipe: Sekundäre Aktionen (Löschen, Aktualisieren)
- ✅ Long Press: Kontextmenü
- ✅ Drag: Bottom Sheet Position ändern

### Feedback
- ✅ Spring Animations (.spring(response: 0.3))
- ✅ Material Backgrounds
- ✅ Shadow Effects
- ✅ Color States (pressed, selected)

## Barrierefreiheit

### Dynamic Type Support
```swift
Text(folder.name)
    .font(.headline)  // Skaliert automatisch mit Systemeinstellungen
```

### VoiceOver Labels
```swift
Label("PDF importieren", systemImage: "plus")  // Automatisch VoiceOver-kompatibel
```

### Farb-Kontrast
- Status-Colors: .orange, .blue, .red, .gray
- Backgrounds: Mit opacity für besseren Kontrast
- Icons: Mit Hintergrund-Shapes

## Performance

### Lazy Loading
```swift
List {
    ForEach(documents) { document in
        // Lazy instantiation
    }
}
```

### Thumbnail Caching
```swift
@State private var thumbnail: UIImage?

.task {
    thumbnail = await PDFThumbnailCache.shared.thumbnail(for: fileURL)
}
```

### Throttled Updates
```swift
private let saveThrottleInterval: TimeInterval = 0.5
```

## Best Practices

### 1. Navigation
- ✅ Nutze NavigationStack für lineare Flows
- ✅ Nutze NavigationSplitView für hierarchische Daten
- ✅ Verwende @Binding für Selection State
- ✅ Implementiere onFolderSelected Callbacks

### 2. Lists
- ✅ Nutze .listStyle(.insetGrouped) für iOS
- ✅ Implementiere Swipe Actions
- ✅ Füge ContentUnavailableView hinzu
- ✅ Zeige Platzhalter während Loading

### 3. Sheets & Overlays
- ✅ Nutze .sheet() für modale Präsentation
- ✅ Nutze ZStack + .ignoresSafeArea() für Bottom Sheets
- ✅ Implementiere Drag Gestures für interaktive Sheets
- ✅ Füge Visual Feedback hinzu (Drag Handle)

### 4. Toolbar
- ✅ Nutze .topBarTrailing für primäre Aktionen
- ✅ Nutze .topBarLeading für sekundäre Aktionen
- ✅ Implementiere context-sensitive Toolbars
- ✅ Verstecke unnötige Buttons auf iPhone

## Migration von macOS

### Entfernt
- ❌ `HSplitView` → Ersetzt durch `NavigationStack` + `ZStack`
- ❌ `.help()` Modifier → iOS hat keine Tooltips
- ❌ `.onTapGesture(count: 2)` → Nutze Long Press oder Buttons
- ❌ Keyboard Shortcuts → iOS-spezifische Alternative

### Ersetzt
- ✅ `NSViewRepresentable` → `UIViewRepresentable`
- ✅ `NSImage` → `UIImage`
- ✅ `.frame(width:)` → Dynamic sizing mit GeometryReader
- ✅ Context Menus → Swipe Actions + Context Menus

## Testing Checklist

- [ ] iPhone SE (klein): Alle Buttons erreichbar?
- [ ] iPhone 15 Pro Max (groß): Layouts gut ausgenutzt?
- [ ] iPad (Portrait): Split View funktioniert?
- [ ] iPad (Landscape): Side-by-Side korrekt?
- [ ] Dark Mode: Alle Farben lesbar?
- [ ] Dynamic Type (groß): Kein Text abgeschnitten?
- [ ] VoiceOver: Alle Elemente beschriftet?
- [ ] Rotation: Smooth Transitions?

## Bekannte Einschränkungen

1. **Keine Drag & Drop zwischen Ordnern auf iPhone**
   - Workaround: Nutze Context Menu "In Ordner verschieben"

2. **Bottom Sheet nicht auf iPad im Portrait-Modus**
   - Grund: Genug Platz für Side-by-Side Layout

3. **Keine Keyboard Shortcuts**
   - Grund: iOS fokussiert auf Touch-Input

## Nächste Schritte

- [ ] Haptic Feedback bei wichtigen Aktionen
- [ ] Pull-to-Refresh in Listen
- [ ] Batch-Selection (Mehrere PDFs gleichzeitig löschen)
- [ ] Spotlight Integration
- [ ] Widgets für Quick Access
- [ ] ShareSheet Integration
- [ ] Files App Integration (Document Provider)

## Ressourcen

- [Apple HIG - iOS](https://developer.apple.com/design/human-interface-guidelines/ios)
- [Navigation in SwiftUI](https://developer.apple.com/documentation/swiftui/navigation)
- [List in SwiftUI](https://developer.apple.com/documentation/swiftui/list)
- [Size Classes](https://developer.apple.com/design/human-interface-guidelines/layout)
