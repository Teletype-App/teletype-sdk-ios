import Foundation
import SocketIO

/// socket.io wrapper. The Teletype backend runs socket.io **v2**.
final class SocketClient {
    private let url: URL
    private let debug: Bool
    private var extraConfig: [String: Any]
    private var manager: SocketManager?
    private var socket: SocketIOClient?

    init(url: String, options: [String: Any] = [:], debug: Bool = false) {
        let normalized = url.hasSuffix("/") ? String(url.dropLast()) : url
        self.url = URL(string: normalized) ?? URL(string: "https://websocket-widget.teletype.app")!
        self.debug = debug
        self.extraConfig = options
    }

    var connected: Bool { socket?.status == .connected }

    func ensureCreated() {
        guard manager == nil else { return }
        var config: SocketIOClientConfiguration = [
            .forceNew(true),
            .version(.two),
            .reconnects(true),
            .log(debug),
            .secure(true),
        ]
        if let forceNew = extraConfig["forceNew"] as? Bool {
            config.insert(.forceNew(forceNew))
        }
        manager = SocketManager(socketURL: url, config: config)
        socket = manager?.defaultSocket
    }

    func connect() {
        ensureCreated()
        if socket?.status != .connected {
            socket?.connect()
        }
    }

    func disconnect() {
        socket?.disconnect()
    }

    func on(_ event: String, callback: @escaping (Any?) -> Void) {
        socket?.on(event) { data, _ in
            callback(data.first)
        }
    }

    func onConnect(_ callback: @escaping () -> Void) {
        socket?.on(clientEvent: .connect) { _, _ in
            callback()
        }
    }

    func onDisconnect(_ callback: @escaping () -> Void) {
        socket?.on(clientEvent: .disconnect) { _, _ in
            callback()
        }
    }

    func off() {
        socket?.removeAllHandlers()
    }

    func emit(_ event: String, _ payload: Any? = nil) {
        if debug {
            print("[teletype][ws] ⬆ \(event)", payload ?? "(no payload)")
        }
        guard let socket else { return }
        guard let payload else {
            socket.emit(event)
            return
        }
        if let dict = payload as? [String: Any] {
            socket.emit(event, NSDictionary(dictionary: dict))
        } else if let data = payload as? any SocketData {
            socket.emit(event, data)
        } else {
            socket.emit(event, "\(payload)")
        }
    }
}
