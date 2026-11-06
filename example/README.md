# Teletype SDK Example

Native SwiftUI demo for **teletype-sdk-ios**. Functionality matches the React Native examples in `teletype-mobile-sdk-react-native/example`.

## Run

```bash
cd example
xcodegen generate
open TeletypeSDKExample.xcodeproj
```

In Xcode, pick an iOS Simulator or a device, then Run.

On first launch paste a Teletype widget **external id** (or the whole install `<script>` snippet). The demo talks to the **dev** cluster (`teletypeapp.com`) by default — switch `mode` in `RootView.swift` for production.

## UI tests

UI tests connect to a real Teletype channel, so the channel id is not stored in the repo. Export a test channel's external id before running them (tests are skipped with a message when it is not set):

```bash
export TELETYPE_TEST_EXTERNAL_ID=<external id of a test channel>
xcodebuild test -project TeletypeSDKExample.xcodeproj -scheme TeletypeSDKExample \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## What it covers

- Setup screen + channel verification (REST + socket)
- Chat title, accent color, transcript background, launcher position/scale
- EN / RU language switch
- File attachments via the system document picker
- Clear chat cache (session + messages)
