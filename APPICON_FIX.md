# App-Icon Fehler beheben

## Problem

```
error: The stickers icon set, app icon set, or icon stack named "AppIcon" did not have any applicable content.
```

Dieser Fehler tritt auf, weil Xcode ein AppIcon-Set in `Assets.xcassets` erwartet, aber keine Bilder darin findet.

## Lösung 1: App-Icon Requirement entfernen (Development)

**Für die Entwicklungsphase - Schnellste Lösung:**

1. Öffne Xcode
2. Wähle dein Projekt in der Navigator-Leiste
3. Wähle dein Target (z.B. "Dokumente")
4. Gehe zu **Build Settings** Tab
5. Suche nach "App Icon" in der Suchleiste
6. Finde **"Asset Catalog Compiler - Options"** → **"Asset Catalog App Icon Set Name"**
   - Alternativ suche direkt nach: `ASSETCATALOG_COMPILER_APPICON_NAME`
7. **Lösche den Wert** (sollte "AppIcon" sein) oder setze ihn auf leer
8. Build & Run

**Ergebnis:** Die App wird mit dem Standard-iOS-Icon gebaut (weißes Quadrat).

---

## Lösung 2: App-Icon hinzufügen (Production)

**Für die finale App - Professionelle Lösung:**

### Schritt 1: Icon erstellen

Erstelle ein **1024x1024 Pixel** PNG-Bild für dein App-Icon.

**Design-Tipps:**
- Keine Transparenz verwenden
- Keine abgerundeten Ecken (iOS macht das automatisch)
- Einfaches, erkennbares Design
- Hoher Kontrast
- Gut lesbar in kleinen Größen

**Schnelle Option:** Nutze einen Icon-Generator wie:
- SF Symbols App (kostenlos von Apple)
- Canva (Online)
- Figma (Online)

### Schritt 2: Icon in Xcode hinzufügen

1. Öffne **Assets.xcassets** in der Navigator-Leiste
2. Finde oder erstelle **"AppIcon"** im Asset Catalog
3. Wähle **"AppIcon"** aus
4. Im **Attributes Inspector** (rechts):
   - Setze **"Single Size"** auf aktiv (falls verfügbar)
   - Oder wähle die iOS-Versionen aus, die du unterstützen willst

5. **Ziehe dein 1024x1024 Icon** in das entsprechende Feld:
   - Bei "Single Size": Nur ein Feld
   - Bei klassischem Setup: "App Store iOS" Slot (1024x1024)

6. Xcode generiert automatisch alle benötigten Größen

### Schritt 3: Verifizieren

1. Build das Projekt
2. Der Fehler sollte verschwunden sein
3. Teste die App auf einem Simulator oder Gerät
4. Überprüfe das Icon auf dem Home-Screen

---

## Lösung 3: AppIcon-Set neu erstellen

**Falls das AppIcon-Set beschädigt ist:**

1. Öffne **Assets.xcassets**
2. **Rechtsklick** auf "AppIcon" → **Delete**
3. **Rechtsklick** im leeren Bereich → **App Icons & Launch Images** → **New iOS App Icon**
4. Folge **Schritt 2** von Lösung 2

---

## Temporäre Lösung: Asset Catalog deaktivieren

**Nicht empfohlen, aber funktioniert:**

1. Gehe zu **Build Settings**
2. Suche nach `ASSETCATALOG_COMPILER_APPICON_NAME`
3. Lösche den Wert komplett
4. **Oder** setze einen nicht-existierenden Namen (z.B. "NoIcon")

---

## Icon-Größen für iOS (Referenz)

Wenn du **nicht** "Single Size" verwendest, brauchst du diese Größen:

| Größe | Verwendung | Pixel (@1x) | Pixel (@2x) | Pixel (@3x) |
|-------|-----------|-------------|-------------|-------------|
| App Store | Submission | - | - | 1024x1024 |
| iPhone | iOS 14+ | 60x60 | 120x120 | 180x180 |
| iPad | iOS 14+ | 76x76 | 152x152 | - |
| iPad Pro | iOS 14+ | 83.5x83.5 | 167x167 | - |
| Notifications | iOS 14+ | 20x20 | 40x40 | 60x60 |
| Settings | iOS 14+ | 29x29 | 58x58 | 87x87 |
| Spotlight | iOS 14+ | 40x40 | 80x80 | 120x120 |

**Empfehlung:** Nutze "Single Size" mit nur 1024x1024, Xcode generiert den Rest!

---

## Schnell-Check nach der Lösung

```bash
# Im Terminal, im Projektverzeichnis:
xcodebuild clean build -scheme Dokumente -destination 'platform=iOS Simulator,name=iPhone 15'
```

Wenn kein Fehler erscheint: ✅ Problem gelöst!

---

## Weitere Ressourcen

- [Apple Human Interface Guidelines - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [SF Symbols App](https://developer.apple.com/sf-symbols/) - Kostenlose Icons von Apple
- [Icon Generator Tools](https://www.appicon.co/) - Online Icon Generator

---

## Support

Bei weiteren Problemen:
1. Clean Build Folder: **⌘ + Shift + K**
2. Derived Data löschen: **⌘ + Option + Shift + K**
3. Xcode neu starten
4. Projekt neu öffnen
