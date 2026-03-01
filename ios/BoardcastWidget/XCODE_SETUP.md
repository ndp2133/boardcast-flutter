# WidgetKit Extension — Xcode Setup

The widget extension target, source files, entitlements, build configs, font references, and embed phase have all been added to `project.pbxproj` programmatically. The widget compiles (`BUILD SUCCEEDED`).

## Remaining Manual Steps

### 1. Configure Signing (required before device/TestFlight builds)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **BoardcastWidgetExtension** target → Signing & Capabilities
3. Set Team to your Apple Developer team
4. Enable "Automatically manage signing"
5. Do the same for the **Runner** target if not already done

### 2. Register App Group in Apple Developer Portal

1. Go to developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → App Groups
2. Register: `group.com.boardcast.boardcastFlutter`
3. Add this App Group to both:
   - `com.boardcast.boardcastFlutter` (main app)
   - `com.boardcast.boardcastFlutter.BoardcastWidget` (widget extension)

### 3. Install Real Fonts

The font files at `fonts/DMMono-Regular.ttf` and `fonts/DMMono-Medium.ttf` are currently 0-byte placeholders. Download the real files:
1. Get DM Mono from https://fonts.google.com/specimen/DM+Mono
2. Replace the empty files with the real .ttf files
3. The widget falls back to system monospace font if DM Mono isn't available

### 4. Install Pod Dependencies (for full app build)

```bash
cd ios && pod install
```

This is needed for the Runner target (Flutter plugins), not the widget itself.

## Verify

```bash
# Widget-only build (no signing needed for simulator)
xcodebuild -target BoardcastWidgetExtension \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO

# Full app build (needs signing + pods)
flutter build ios --debug
```

## Troubleshooting

- **Widget shows placeholder**: Open the Boardcast app first so it fetches conditions and writes to shared UserDefaults
- **Font not rendering**: Verify the .ttf files aren't 0 bytes; widget falls back to system mono
- **App Group mismatch**: Both targets must use exactly `group.com.boardcast.boardcastFlutter`
- **Widget not updating**: Check that `HomeWidget.updateWidget(iOSName: 'BoardcastWidget')` is called after data write
- **Signing error**: Set development team in Xcode for both Runner and BoardcastWidgetExtension targets
