# TestFlight Upload

Upload a new build to TestFlight from the CLI.

## Single-step build + upload

```bash
cd "$(git rev-parse --show-toplevel)"

# Build archive (will fail at IPA export — expected)
flutter build ipa --release

# Clean previous export, then export + upload in one step
rm -rf build/ios/ipa
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/ipa \
  -exportOptionsPlist /dev/stdin \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.private_keys/AuthKey_38G5Q8T6NB.p8 \
  -authenticationKeyID 38G5Q8T6NB \
  -authenticationKeyIssuerID a0826f8e-47f1-480d-bae9-d07bf3cd322a \
  <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>manageAppVersionAndBuildNumber</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>4H96A7962Y</string>
</dict>
</plist>
PLIST
```

## Notes
- `manageAppVersionAndBuildNumber: true` lets App Store Connect auto-increment — no need to bump pubspec.yaml
- The inline plist via stdin avoids needing a separate ExportOptions.plist file
- No separate `altool` upload step needed — `destination: upload` handles it all
- Processing takes ~15-30 min before appearing in TestFlight
- The dSYM warning about objective_c.framework is cosmetic and harmless
- API key lives at `~/.private_keys/AuthKey_38G5Q8T6NB.p8`
