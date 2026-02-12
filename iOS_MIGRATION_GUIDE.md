# iOS Migration Guide

This document describes the changes made to convert your macOS PDF Manager app into a universal iOS/iPadOS app that can also run on Mac via "Designed for iPad".

## Changes Made

### 1. **PDFDocument.swift**
- Changed `import AppKit` to conditional imports using `#if canImport(UIKit)`
- Now supports both UIKit (iOS) and AppKit (macOS)

### 2. **DokumenteApp.swift**
- Wrapped `.commands` modifier with `#if os(macOS)` since commands are macOS-only
- Wrapped `.defaultSize` modifier with `#if os(macOS)` 
- Settings scene remains macOS-only

### 3. **ContentView.swift**
- Added Settings button in toolbar for iOS (placement: `.navigationBarLeading`)
- Settings are shown in a sheet on iOS instead of a separate window
- Maintained NavigationSplitView for multi-column layout (works great on iPad)

### 4. **SettingsView.swift**
- Wrapped in `NavigationStack` for iOS presentation
- Added "Fertig" (Done) button for iOS
- Added `.navigationBarTitleDisplayMode(.inline)` for iOS
- Frame width constraint only applies on macOS
- Changed text from "macOS Keychain" to just "Keychain" for platform neutrality

### 5. **PDFDetailView.swift**
- Replaced `HSplitView` (macOS-only) with adaptive layout:
  - **macOS**: Uses `HSplitView` for traditional split view
  - **iOS**: Uses `GeometryView` helper that adapts based on device:
    - **iPad landscape (>768pt)**: Side-by-side layout (PDF 65%, Summary 35%)
    - **iPhone/iPad portrait**: PDF fullscreen with summary overlay at bottom (40% height)
- Added `PDFKitView` with platform-specific implementations:
  - **macOS**: `NSViewRepresentable` 
  - **iOS**: `UIViewRepresentable`
- Both implementations share the same position persistence logic

### 6. **PDFManagerViewModel.swift**
- Changed `import AppKit` to conditional imports
- No functional changes needed - SwiftData and PDFKit work on both platforms

## Xcode Project Configuration

To complete the migration, you need to configure your Xcode project:

### Step 1: Update Target Platform

1. Select your project in the navigator
2. Select your app target
3. Go to "General" tab
4. Under "Supported Destinations":
   - Add **iPhone**
   - Add **iPad**
   - Keep **Mac (Designed for iPad)** if you want Mac support
   - Remove "Mac" if it was set to native macOS

### Step 2: Update Deployment Target

- Set **iOS Deployment Target** to iOS 17.0 or later (for SwiftData support)

### Step 3: Update Info.plist / Target Settings

Add required capabilities:
- **iCloud**: Already configured (CloudKit)
- **File Access**: Document types for PDF import

### Step 4: Supported Device Orientations (iOS)

Under "General" → "Deployment Info":
- **iPhone**: Portrait, Landscape Left, Landscape Right (recommended)
- **iPad**: All orientations (recommended for best UX)

### Step 5: App Icons

You'll need to add iOS app icons to your asset catalog:
- 1024×1024 for App Store
- Various sizes for iPhone and iPad

### Step 6: Update Entitlements (if needed)

The app uses:
- iCloud Drive (already configured)
- Keychain access (works on both platforms)

Ensure your entitlements file includes:
```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.$(CFBundleIdentifier)</string>
</array>
<key>com.apple.developer.ubiquity-container-identifiers</key>
<array>
    <string>iCloud.$(CFBundleIdentifier)</string>
</array>
```

## Testing Checklist

### On iPhone
- [ ] PDF import works via document picker
- [ ] PDF list displays correctly
- [ ] PDF viewer loads and displays documents
- [ ] Summary overlay appears at bottom when toggled
- [ ] Folder navigation works
- [ ] Settings sheet opens and saves API key
- [ ] Reading position persists across app restarts

### On iPad
- [ ] Three-column layout works in landscape
- [ ] Summary shows side-by-side in landscape (>768pt width)
- [ ] Layout adapts in portrait mode
- [ ] Split view dividers are draggable (in landscape)
- [ ] All iPhone tests apply

### On Mac (Designed for iPad)
- [ ] App runs and launches correctly
- [ ] Window can be resized
- [ ] Keyboard shortcuts work where applicable
- [ ] Menu bar commands work (Import, Delete All)
- [ ] Settings window opens via menu
- [ ] Touch Bar support (if applicable)

## Known Limitations

### Mac (Designed for iPad) vs Native macOS

When running as "Designed for iPad" on Mac, there are some differences from a native Mac app:

1. **Window Management**: Limited to iOS-style window management
2. **Menu Bar**: Basic menu bar, not as customizable as native macOS
3. **Keyboard Shortcuts**: Some macOS keyboard shortcuts won't work
4. **File System**: Limited to app sandbox, similar to iOS
5. **Performance**: Slightly lower than native macOS due to translation layer

### Benefits of "Designed for iPad"

1. **Single Codebase**: One app for iPhone, iPad, and Mac
2. **Automatic Updates**: Users get updates on all platforms simultaneously
3. **Unified UI**: Consistent experience across devices
4. **App Store**: One app listing for all platforms
5. **Development Speed**: Faster than maintaining separate Mac and iOS apps

## Optional: Native Mac App with Catalyst

If you want better Mac integration, consider Mac Catalyst instead of "Designed for iPad":

1. In Xcode, under target settings
2. Check "Mac" under "Supported Destinations"
3. Choose "Mac Catalyst" as the SDK
4. Catalyst provides:
   - Better Mac window management
   - More Mac-native UI elements
   - Better keyboard and menu support
   - Native macOS controls where appropriate

### Catalyst-specific code

You can use `#if targetEnvironment(macCatalyst)` to add Mac-specific behavior:

```swift
#if targetEnvironment(macCatalyst)
// Mac-specific code when running via Catalyst
#endif
```

## UI/UX Improvements for iOS

Consider these enhancements for better iOS experience:

### 1. Swipe Gestures
Add swipe-to-delete in PDF list:
```swift
.swipeActions(edge: .trailing) {
    Button(role: .destructive) {
        deleteDocument(document)
    } label: {
        Label("Löschen", systemImage: "trash")
    }
}
```

### 2. Context Menus
Add long-press context menus:
```swift
.contextMenu {
    Button {
        // Share PDF
    } label: {
        Label("Teilen", systemImage: "square.and.arrow.up")
    }
}
```

### 3. Share Sheet
Implement PDF sharing:
```swift
let activityVC = UIActivityViewController(
    activityItems: [pdfURL],
    applicationActivities: nil
)
```

### 4. Haptic Feedback
Add haptic feedback for interactions:
```swift
let impact = UIImpactFeedbackGenerator(style: .medium)
impact.impactOccurred()
```

### 5. Pull to Refresh
Add pull-to-refresh in PDF list:
```swift
.refreshable {
    await viewModel.loadDocuments()
}
```

## Cloud Storage Considerations

The app uses iCloud Drive, which works on both platforms. However:

1. **iOS**: Users expect iCloud to "just work"
2. **File Provider**: Consider using the Files app integration
3. **Offline Support**: Ensure PDFs are available offline
4. **Sync Indicator**: Show when syncing with iCloud

## Next Steps

1. **Test thoroughly** on all target devices
2. **Update screenshots** for App Store
3. **Update app description** to mention multi-platform support
4. **Consider iPad-specific features**: Split View, Slide Over, Picture in Picture
5. **Accessibility**: Test with VoiceOver on iOS
6. **Localization**: Ensure all strings are localized
7. **Performance**: Profile on iPhone (especially older models)

## Support

If you encounter issues:

1. Check that all files have conditional compilation working
2. Verify that PDFKit is available on both platforms (it is)
3. Test iCloud sync on both platforms
4. Check that SwiftData persistence works correctly

## Additional Resources

- [Apple's Human Interface Guidelines for iOS](https://developer.apple.com/design/human-interface-guidelines/ios)
- [Bringing Your iPad App to macOS](https://developer.apple.com/documentation/uikit/mac_catalyst)
- [SwiftUI on iOS Documentation](https://developer.apple.com/documentation/swiftui)
- [PDFKit Documentation](https://developer.apple.com/documentation/pdfkit)
