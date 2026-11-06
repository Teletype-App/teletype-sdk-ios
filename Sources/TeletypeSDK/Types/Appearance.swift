import Foundation

public typealias ChatBackground = String

public enum ChatBackgrounds {
    public static let white = "white"
    public static let doodle = "doodle"
    public static let circles = "circles"
    public static let scribbles = "scribbles"

    public static let all: [String] = [white, doodle, circles, scribbles]
    public static let picker: [String] = [doodle, circles, scribbles, white]
}

public let DEFAULT_CHAT_BACKGROUND = ChatBackgrounds.white

public func isChatBackground(_ value: String?) -> Bool {
    guard let value else { return false }
    return ChatBackgrounds.all.contains(value)
}

public enum ChatButtonPosition: String, Equatable, Hashable, Sendable {
    case left
    case right
}

public let CHAT_BUTTON_SCALES = [70, 80, 90, 100]
public typealias ChatButtonScale = Int
