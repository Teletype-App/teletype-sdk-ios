/// Native Swift SDK for embedding the Teletype online chat into iOS apps.
///
/// Reuses the Teletype web widget's backend protocol (REST + socket.io v2) —
/// no WebView required.
///
/// ```swift
/// let client = TeletypeClient(TeletypeConfig(
///     teletypeExternalId: "YOUR_EXTERNAL_ID",
///     mode: .dev,
///     title: "Онлайн чат"
/// ))
/// await client.`init`()
///
/// let controller = TeletypeController(client: client)
/// ChatScreen(controller: controller, onAttachmentPress: { await AttachmentPicker.pick() })
/// ```

@_exported import Foundation
@_exported import SwiftUI
