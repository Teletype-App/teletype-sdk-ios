import Foundation

final class TypedEventEmitter {
    private var listeners: [TeletypeEventName: [UUID: (TeletypeEvent) -> Void]] = [:]
    private let lock = NSLock()

    @discardableResult
    func on(_ name: TeletypeEventName, _ listener: @escaping (TeletypeEvent) -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        listeners[name, default: [:]][id] = listener
        lock.unlock()
        return id
    }

    func off(_ name: TeletypeEventName, id: UUID) {
        lock.lock()
        listeners[name]?[id] = nil
        lock.unlock()
    }

    func emit(_ event: TeletypeEvent) {
        let name: TeletypeEventName
        switch event {
        case .ready: name = .ready
        case .opened: name = .opened
        case .closed: name = .closed
        case .dialogStarted: name = .dialogStarted
        case .appealStarted: name = .appealStarted
        case .messageSent: name = .messageSent
        case .messageReceived: name = .messageReceived
        case .dialogClosed: name = .dialogClosed
        case .dialogRated: name = .dialogRated
        case .channelClicked: name = .channelClicked
        case .messagesChanged: name = .messagesChanged
        case .unreadCountChanged: name = .unreadCountChanged
        case .operatorTyping: name = .operatorTyping
        case .connectionChanged: name = .connectionChanged
        case .draftChanged: name = .draftChanged
        case .openChanged: name = .openChanged
        case .config: name = .config
        case .localeChanged: name = .localeChanged
        case .appearanceChanged: name = .appearanceChanged
        case .error: name = .error
        }
        lock.lock()
        let snapshot = listeners[name]?.values.map { $0 } ?? []
        lock.unlock()
        for listener in snapshot {
            listener(event)
        }
    }

    func removeAllListeners() {
        lock.lock()
        listeners = [:]
        lock.unlock()
    }
}
