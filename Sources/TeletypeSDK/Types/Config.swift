import Foundation

public struct Operator: Codable, Equatable, Sendable {
    public var name: String
    public var isOnline: Bool
    public var avatar: String
    public var id: String?
    public var messenger: String?
    public var avatarDefault: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        isOnline = (try? c.decode(Bool.self, forKey: .isOnline)) ?? false
        if let s = try? c.decode(String.self, forKey: .avatar) {
            avatar = s
        } else {
            avatar = ""
        }
        id = try? c.decode(String.self, forKey: .id)
        messenger = try? c.decode(String.self, forKey: .messenger)
        avatarDefault = try? c.decode(String.self, forKey: .avatarDefault)
    }

    public init(
        name: String,
        isOnline: Bool = false,
        avatar: String = "",
        id: String? = nil,
        messenger: String? = nil,
        avatarDefault: String? = nil
    ) {
        self.name = name
        self.isOnline = isOnline
        self.avatar = avatar
        self.id = id
        self.messenger = messenger
        self.avatarDefault = avatarDefault
    }

    public var stableId: String { id ?? name }
}

public struct ChannelMessenger: Codable, Equatable, Sendable {
    public var id: String?
    public var name: String
    public var desktopUrl: String?
    public var mobileUrl: String?

    public init(id: String? = nil, name: String, desktopUrl: String? = nil, mobileUrl: String? = nil) {
        self.id = id
        self.name = name
        self.desktopUrl = desktopUrl
        self.mobileUrl = mobileUrl
    }
}

public struct InvitationCondition: Codable, Equatable, Sendable {
    public var condition: String?
    public var conditionAction: String?
    public var target: String?
}

public struct InvitationRules: Codable, Equatable, Sendable {
    public var isEnabled: FlexibleBool?
}

public struct WorkRange: Codable, Equatable, Sendable {
    public var day: String?
    public var from: String?
    public var to: String?
}

public struct WidgetPro: Codable, Equatable, Sendable {
    public var paidTariff: Bool?
    public var paidLinkDisable: Bool?
}

public struct WidgetConfigData: Codable, Equatable, Sendable {
    public var name: String?
    public var projectName: String?
    public var projectId: String?
    public var language: String?
    public var backgroundColor: String?
    public var backgroundImage: String?
    public var position: String?
    public var enabledChat: Bool?
    public var soundEnabled: Bool?
    public var pro: WidgetPro?
    public var operators: [Operator]?
    public var channels: [ChannelMessenger]?
    public var rules: [InvitationRules]?
    public var workRange: [WorkRange]?
    public var timezone: String?
    public var showLink: Bool?
    public var buttonTextEnabled: Bool?

    public var resolvedName: String { name ?? "" }
    public var resolvedProjectId: String { projectId ?? "" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try? c.decode(String.self, forKey: .name)
        projectName = try? c.decode(String.self, forKey: .projectName)
        projectId = try? c.decode(String.self, forKey: .projectId)
        language = try? c.decode(String.self, forKey: .language)
        backgroundColor = try? c.decode(String.self, forKey: .backgroundColor)
        backgroundImage = try? c.decode(String.self, forKey: .backgroundImage)
        position = try? c.decode(String.self, forKey: .position)
        enabledChat = (try? c.decode(Bool.self, forKey: .enabledChat))
            ?? (try? c.decode(FlexibleBool.self, forKey: .enabledChat))?.value
        soundEnabled = (try? c.decode(Bool.self, forKey: .soundEnabled))
            ?? (try? c.decode(FlexibleBool.self, forKey: .soundEnabled))?.value
        pro = try? c.decode(WidgetPro.self, forKey: .pro)
        operators = try? c.decode([Operator].self, forKey: .operators)
        channels = try? c.decode([ChannelMessenger].self, forKey: .channels)
        rules = try? c.decode([InvitationRules].self, forKey: .rules)
        // Backend sometimes sends `work_range` / `holidays` as an empty string.
        workRange = try? c.decode([WorkRange].self, forKey: .workRange)
        timezone = try? c.decode(String.self, forKey: .timezone)
        showLink = (try? c.decode(Bool.self, forKey: .showLink))
            ?? (try? c.decode(FlexibleBool.self, forKey: .showLink))?.value
        buttonTextEnabled = (try? c.decode(Bool.self, forKey: .buttonTextEnabled))
            ?? (try? c.decode(FlexibleBool.self, forKey: .buttonTextEnabled))?.value
    }
}

public struct ApiEnvelope<T: Codable>: Codable {
    public var success: Bool?
    public var error: FlexibleError?
    public var data: T?
    public var datetime: String?
}

public typealias ConfigResponse = ApiEnvelope<WidgetConfigData>
public typealias HistoryResponse = ApiEnvelope<[Message]>

public struct UploadFileData: Codable {
    public var attachment: String?
    public var attachmentId: String?
    public var attachmentUrl: String?
}

public typealias UploadFileResponse = ApiEnvelope<UploadFileData>

/// Boolean that also accepts `"true"` / `1` from loosely typed JSON.
public struct FlexibleBool: Codable, Equatable, Sendable {
    public var value: Bool

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) {
            value = b
        } else if let i = try? c.decode(Int.self) {
            value = i != 0
        } else if let s = try? c.decode(String.self) {
            value = ["true", "1", "yes"].contains(s.lowercased())
        } else {
            value = false
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}

public enum FlexibleError: Codable, Equatable, Sendable {
    case list([String])
    case text(String)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let list = try? c.decode([String].self) {
            self = .list(list)
        } else if let text = try? c.decode(String.self) {
            self = .text(text)
        } else {
            self = .list([])
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .list(let list): try c.encode(list)
        case .text(let text): try c.encode(text)
        }
    }

    public var joined: String {
        switch self {
        case .list(let list): return list.joined(separator: ", ")
        case .text(let text): return text
        }
    }
}
