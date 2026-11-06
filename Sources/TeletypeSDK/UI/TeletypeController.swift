import Combine
import Foundation
import SwiftUI

/// Observable wrapper around `TeletypeClient` for SwiftUI hosts.
@MainActor
public final class TeletypeController: ObservableObject {
    @Published public private(set) var state: TeletypeState
    public let client: TeletypeClient

    private var tokens: [UUID] = []

    public init(client: TeletypeClient) {
        self.client = client
        self.state = client.state
        bind()
    }

    public convenience init(config: TeletypeConfig) {
        self.init(client: TeletypeClient(config))
    }

    private func bind() {
        let names: [TeletypeEventName] = [
            .ready, .opened, .closed, .openChanged, .messagesChanged,
            .unreadCountChanged, .operatorTyping, .connectionChanged,
            .draftChanged, .config, .localeChanged, .appearanceChanged,
            .messageReceived, .messageSent, .dialogRated, .error,
        ]
        for name in names {
            let token = client.on(name) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.state = self.client.state
                }
            }
            tokens.append(token)
        }
    }

    public func initialize() async {
        await client.`init`()
        state = client.state
    }

    public func destroy() {
        client.destroy()
    }
}
