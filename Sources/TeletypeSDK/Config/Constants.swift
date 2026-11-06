import Foundation

/// WebSocket event names used by the Teletype backend (socket.io v2).
/// Kept byte-for-byte identical to the web widget.
public enum WsEvent {
    public static let connect = "connect"
    public static let disconnect = "disconnect"
    public static let initDataToPerson = "init data to person"
    public static let authPerson = "auth person"
    public static let messageFromClient = "message from client"
    public static let messageFromPerson = "web widget message from person"
    public static let authSuccess = "auth success"
    public static let operatorTyping = "operator typing"
    public static let received = "received"
    public static let seen = "seen"
    public static let personTyping = "person typing"
    public static let personStopTyping = "person stop typing"
    public static let operatorStopTyping = "operator stop typing"
    public static let operatorStatusChange = "operator status change"
    public static let personClickWidgetChannel = "person click widget channel"
    public static let personRateAppeal = "person rate appeal"
    public static let appealStatusChange = "appeal status change"
    public static let personOpenedWidget = "person opened widget"
    public static let setPersonData = "set person data"
    public static let setUserData = "set user data"
}

/// Appeal status reported by `appeal status change`. 2 === closed by operator.
public let APPEAL_STATUS_CLOSED = 2

public let INPUT_TYPING_TIMEOUT: TimeInterval = 60
public let OUTPUT_TYPING_TIMEOUT: TimeInterval = 10
public let RECEIVED_ACK_TIMEOUT: TimeInterval = 10
public let CONFIG_LIFETIME: TimeInterval = 60 * 10
public let MAX_UPLOAD_BYTES = 20 * 1024 * 1024

public let DEFAULT_PRIMARY_COLOR = "#0084ff"
public let DEFAULT_CHAT_TITLE = "Онлайн чат"

public enum StorageKeys {
    public static let personId = "person_id"
    public static let appealId = "appeal_id"
    public static let config = "config"
    public static let configSaveTime = "config-save-time"
    public static let popupState = "popup-state"
    public static let widgetInteracted = "widget-interacted"
    public static let pendingMessages = "pendingMessages"
}
