import Foundation

/// Additional person (visitor) data attached to the conversation.
public struct AdditionalPersonInfo: Equatable, Sendable {
    public var name: String?
    public var email: String?
    public var avatar: String?
    public var phone: String?
    public var payload: [String: String]?

    public init(
        name: String? = nil,
        email: String? = nil,
        avatar: String? = nil,
        phone: String? = nil,
        payload: [String: String]? = nil
    ) {
        self.name = name
        self.email = email
        self.avatar = avatar
        self.phone = phone
        self.payload = payload
    }

    func asDictionary() -> [String: Any] {
        var out: [String: Any] = [:]
        if let name { out["name"] = name }
        if let email { out["email"] = email }
        if let avatar { out["avatar"] = avatar }
        if let phone { out["phone"] = phone }
        if let payload { out["payload"] = payload }
        return out
    }
}

public enum ConnectionState: String, Equatable, Sendable {
    case connected
    case disconnected
}

public struct DialogClosedPayload: Equatable, Sendable {
    public var status: Int
}

public struct DialogRatedPayload: Equatable, Sendable {
    public var id: String
    public var formValue: String
}

/// Public SDK events — native equivalents of the web `teletype.*` DOM events.
public enum TeletypeEvent {
    case ready
    case opened
    case closed
    case dialogStarted(Message)
    case appealStarted(Message)
    case messageSent(Message)
    case messageReceived(Message)
    case dialogClosed(DialogClosedPayload)
    case dialogRated(DialogRatedPayload)
    case channelClicked(ChannelMessenger)
    case messagesChanged([Message])
    case unreadCountChanged(Int)
    case operatorTyping(Bool)
    case connectionChanged(ConnectionState)
    case draftChanged(String)
    case openChanged(Bool)
    case config(WidgetConfigData)
    case localeChanged(String)
    case appearanceChanged
    case error(Error)
}

public enum TeletypeEventName: String, CaseIterable, Sendable {
    case ready
    case opened
    case closed
    case dialogStarted
    case appealStarted
    case messageSent
    case messageReceived
    case dialogClosed
    case dialogRated
    case channelClicked
    case messagesChanged
    case unreadCountChanged
    case operatorTyping
    case connectionChanged
    case draftChanged
    case openChanged
    case config
    case localeChanged
    case appearanceChanged
    case error
}
