# watchOS Complication Setup

All source files are ready. These Xcode steps add the watchOS targets.

## Step 1: Add Watch App Target

1. Open `Runner.xcworkspace` in Xcode
2. File → New → Target → watchOS → App
3. Settings:
   - Product Name: `BoardcastWatch`
   - Bundle Identifier: `com.boardcast.app.watch`
   - Language: Swift
   - **Uncheck** "Include Notification Scene"
   - **Uncheck** "Include Widget Extension" (we add it separately)
4. When prompted "Activate scheme?", click Activate
5. Delete the auto-generated `ContentView.swift` and `BoardcastWatchApp.swift` from the new target
6. Add our existing files:
   - Drag `ios/BoardcastWatch/BoardcastWatchApp.swift` into the BoardcastWatch group
   - Set target membership to **BoardcastWatch** only

## Step 2: Add Watch Widget Extension (Complications)

1. File → New → Target → watchOS → Widget Extension
2. Settings:
   - Product Name: `BoardcastWatchComplication`
   - Bundle Identifier: `com.boardcast.app.watch.complication`
   - Embed in: **BoardcastWatch**
3. Delete the auto-generated widget Swift file
4. Add our file:
   - Drag `ios/BoardcastWatchComplication/BoardcastWatchComplication.swift` into the extension group
   - Set target membership to **BoardcastWatchComplication** only

## Step 3: Add WatchConnectivity to iPhone Target

1. Select the **Runner** target
2. General → Frameworks → Add `WatchConnectivity.framework`
3. The `WatchConnectivityManager.swift` file should already be in the Runner group
   - If not, drag it in and set target membership to **Runner**
4. Verify `AppDelegate.swift` registers the plugin (already done in code)

## Step 4: Configure Signing

1. Select **BoardcastWatch** target → Signing & Capabilities
   - Team: Your Apple Developer team
   - Bundle ID: `com.boardcast.app.watch`
2. Select **BoardcastWatchComplication** target → Signing & Capabilities
   - Team: Same
   - Bundle ID: `com.boardcast.app.watch.complication`

## Step 5: Set Deployment Target

1. BoardcastWatch → General → Minimum Deployment: watchOS 10.0
2. BoardcastWatchComplication → same

## Step 6: Build & Test

```bash
# Build for watch simulator
xcodebuild -workspace Runner.xcworkspace \
  -scheme BoardcastWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build

# Or select BoardcastWatch scheme in Xcode and run on Watch simulator
```

## Data Flow

```
Flutter app
  → watch_service.dart (MethodChannel)
  → WatchConnectivityManager.swift (iPhone)
  → WCSession.transferCurrentComplicationUserInfo()
  → WatchAppDelegate (Watch receives)
  → UserDefaults
  → WatchComplicationProvider reads → WidgetKit renders complications
```

## Complication Families

| Family | What it shows |
|--------|--------------|
| Circular | Score gauge (the Lumy play) |
| Rectangular | Score + condition + location + wave/wind |
| Inline | "74 Good · 3.2ft" single line |
| Corner | Score number with gauge arc |
