# Teletype iOS SDK

Native **Swift SDK** for embedding the [Teletype](https://teletype.app) online chat into iOS apps.

It reuses the same backend protocol as the Teletype **web widget** (`/widget`) — REST API + `socket.io` (v2) — but renders a **native SwiftUI** chat UI (no WebView). The public surface mirrors the web widget's `_teletypeWidget.*` API and the [React Native SDK](https://github.com/teletype/teletype-mobile-sdk-react-native).

> 🇷🇺 Документация на русском: [README_RUS.md](./README_RUS.md)

---

## Features

- Real-time messaging over `socket.io` v2 (typing indicators, seen/received receipts)
- Drop-in `ChatWidget` (floating button) and `ChatScreen` as a regular SwiftUI screen
- Headless core (`TeletypeClient`) for fully custom UIs
- Message history, offline pending queue, auto-reconnect
- Operator rating form, service/bot messages, attachments (image, video, audio, files)
- Unread badge, event system equivalent to the web `teletype.*` events
- Persisted session (person id + appeal id) via `UserDefaults`
- English and Russian UI strings; follows the device language by default

---

## Requirements

- iOS 16+
- Xcode 15+ (Swift 5.9+)
- Swift Package Manager

Xcode is required to build. The SDK pulls [Socket.IO-Client-Swift](https://github.com/socketio/socket.io-client-swift) automatically (configured for **socket.io protocol v2**).

---

## Installation

Add the package in Xcode: **File → Add Package Dependencies…** and point it at this repository. Or in `Package.swift`:

```swift
.package(path: "../teletype-sdk-ios")
// or
.package(url: "https://github.com/YOUR_ORG/teletype-sdk-ios.git", from: "0.1.0")
```

Then depend on the `TeletypeSDK` product.

---

## Quick start

```swift
import TeletypeSDK

let client = TeletypeClient(TeletypeConfig(
    teletypeExternalId: "YOUR_EXTERNAL_ID",
    mode: .dev,          // .dev → teletypeapp.com, .prod → teletype.app
    title: "Онлайн чат",
    primaryColor: "#0084ff"
))
await client.initialize()

let controller = TeletypeController(client: client)

struct Root: View {
    @ObservedObject var controller: TeletypeController

    var body: some View {
        if controller.state.opened {
            ChatScreen(
                controller: controller,
                onClose: { controller.client.hide() },
                onAttachmentPress: { await DocumentPicker.pick() }
            )
        } else {
            ZStack {
                YourApp()
                ChatWidget(controller: controller)
            }
        }
    }
}
```

`teletypeExternalId` is the widget external id — copy it from the channel's install snippet in the Teletype dashboard.

---

## Public API

| Method | Web equivalent | Description |
| --- | --- | --- |
| `client.show()` | `_teletypeWidget.show()` | Open the chat UI |
| `client.hide()` | `_teletypeWidget.hide()` | Close the chat UI |
| `client.toggle()` | — | Toggle the chat UI |
| `client.setMessage(text)` | `_teletypeWidget.setMessage()` | Prefill the composer |
| `client.setPersonData(info)` | `_teletypeWidget.setPersonData()` | Attach visitor data |
| `client.greetingMessages([...])` | `_teletypeWidget.greetingMessages()` | Inject bot greeting messages |
| `client.sendMessage(text)` | — | Send a message programmatically |
| `client.uploadAttachment(file)` | — | Upload a file without sending it |
| `client.sendAttachment(...)` | — | Send an already-uploaded attachment |
| `client.uploadFile(file)` | — | Upload + send an attachment |
| `client.rateAppeal(value, tempId?)` | — | Submit a conversation rating |
| `client.markSeen()` | — | Mark inbound messages as seen |
| `client.setTitle(text)` | — | Change the chat header title |
| `client.setPrimaryColor(color)` | — | Change the shared button + header color |
| `client.setLocale(code)` | — | Switch UI language at runtime |

Subscribe with `client.on(.messageReceived) { event in … }`.

---

## Clusters: `dev` vs `prod`

| `mode` | apiUrl | wsUrl |
| --- | --- | --- |
| `dev` | `https://api.teletypeapp.com/` | `https://websocket-widget.teletypeapp.com` |
| `prod` (default) | `https://api.teletype.app/` | `https://websocket-widget.teletype.app/` |

Override individual endpoints via `TeletypeConfig.environment`.

---

## Example app

A runnable demo lives under [`example/`](./example). It copies the React Native demo flow: paste an external id (or install snippet), appearance controls, language switcher, file picker, clear cache.

```bash
cd example
xcodegen generate
open TeletypeSDKExample.xcodeproj
```

Select a simulator or device and Run. The first launch asks for a Teletype channel id.

---

## Protocol notes

- **REST** (`{apiUrl}api/v1/…`): `widget/{id}/config`, `widget/ip`, `history/{id}/{appeal}/messages`, `POST widget-attachment/{channel_id}` (multipart `file` + `externalId`).
- **WebSocket** (socket.io v2, `{wsUrl}`): emits `web widget message from person`, `auth person`, `set person data`, `seen`, `person typing`, `person opened widget`, `person rate appeal`; listens for `init data to person`, `message from client`, `received`, `seen`, `operator typing`, `appeal status change`.

Payload keys are `snake_case` on the wire and normalized to `camelCase` when parsed.

---

## License

MIT
