import Foundation

public enum MessageType: String, Codable, Equatable, Sendable {
    case text
    case typing
    case attachment
    case image
    case gif
    case audio
    case video
}

public enum MessageStatus: String, Codable, Equatable, Sendable {
    case sending
    case sent
    case failed
}

public enum FormType: String, Codable, Equatable, Sendable {
    case rating
    case boolean
    case faq
    case input
    case contact
    case contactButtons
}

public enum ConversationRating: String, Codable, Equatable, Sendable, Hashable {
    case unsatisfactory = "10"
    case bad = "20"
    case satisfactory = "30"
    case good = "40"
    case excellent = "50"
}

public struct DateObject: Codable, Equatable, Sendable {
    public var date: String
    public var timezone: String

    public init(date: String, timezone: String = "UTC") {
        self.date = date
        self.timezone = timezone
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = (try? c.decode(String.self, forKey: .date)) ?? ""
        timezone = (try? c.decode(String.self, forKey: .timezone)) ?? "UTC"
    }

    public static func now() -> DateObject {
        DateObject(date: ISO8601DateFormatter.teletype.string(from: Date()), timezone: "UTC")
    }
}

public struct BotButton: Codable, Equatable, Sendable {
    public var label: String?
    public var value: String?
}

public struct ContactForm: Codable, Equatable, Sendable {
    public var method: String?
    public var value: String?
    public var valid: Bool?
    public var placeholder: String?
}

public struct MessageFrom: Codable, Equatable, Sendable {
    public var avatar: String?
    public var avatarDefault: String?
    public var id: String?
    public var isOnline: Bool?
    public var isOperator: Bool?
    public var messenger: String?
    public var name: String?
}

/// A single chat message. Mirrors the Teletype web widget payload shape.
public struct Message: Codable, Equatable, Sendable {
    public var id: String?
    public var tempId: String
    public var appealId: String?

    public var message: String?
    public var originalMessage: String?

    public var attachment: String?
    public var attachmentUrl: String?
    public var attachmentPreviewUrl: String?
    public var attachmentId: String?

    public var isOwn: Bool?
    public var date: DateObject?
    public var dateToDisplay: String?

    public var avatar: String?
    public var avatarDefault: String?

    public var messageType: MessageType?
    public var emojiOnly: Bool?
    public var progress: Int?

    public var isForm: Bool?
    public var formId: String?
    public var formType: FormType?
    public var ratingValue: ConversationRating?
    public var contactForm: ContactForm?

    public var `operator`: Operator?
    public var from: MessageFrom?

    public var fromInvite: Bool?
    public var serviceMessage: Bool?

    public var errorMessage: String?
    public var width: Double?
    public var height: Double?

    public var unread: Bool?
    public var seen: Bool?
    public var status: MessageStatus?
    public var size: Int?

    public init(
        id: String? = nil,
        tempId: String = UUID().uuidString.lowercased(),
        appealId: String? = nil,
        message: String? = nil,
        originalMessage: String? = nil,
        attachment: String? = nil,
        attachmentUrl: String? = nil,
        attachmentPreviewUrl: String? = nil,
        attachmentId: String? = nil,
        isOwn: Bool? = nil,
        date: DateObject? = nil,
        dateToDisplay: String? = nil,
        avatar: String? = nil,
        avatarDefault: String? = nil,
        messageType: MessageType? = nil,
        emojiOnly: Bool? = nil,
        progress: Int? = nil,
        isForm: Bool? = nil,
        formId: String? = nil,
        formType: FormType? = nil,
        ratingValue: ConversationRating? = nil,
        contactForm: ContactForm? = nil,
        operator: Operator? = nil,
        from: MessageFrom? = nil,
        fromInvite: Bool? = nil,
        serviceMessage: Bool? = nil,
        errorMessage: String? = nil,
        width: Double? = nil,
        height: Double? = nil,
        unread: Bool? = nil,
        seen: Bool? = nil,
        status: MessageStatus? = nil,
        size: Int? = nil
    ) {
        self.id = id
        self.tempId = tempId
        self.appealId = appealId
        self.message = message
        self.originalMessage = originalMessage
        self.attachment = attachment
        self.attachmentUrl = attachmentUrl
        self.attachmentPreviewUrl = attachmentPreviewUrl
        self.attachmentId = attachmentId
        self.isOwn = isOwn
        self.date = date
        self.dateToDisplay = dateToDisplay
        self.avatar = avatar
        self.avatarDefault = avatarDefault
        self.messageType = messageType
        self.emojiOnly = emojiOnly
        self.progress = progress
        self.isForm = isForm
        self.formId = formId
        self.formType = formType
        self.ratingValue = ratingValue
        self.contactForm = contactForm
        self.operator = `operator`
        self.from = from
        self.fromInvite = fromInvite
        self.serviceMessage = serviceMessage
        self.errorMessage = errorMessage
        self.width = width
        self.height = height
        self.unread = unread
        self.seen = seen
        self.status = status
        self.size = size
    }

    /// Stable identity for SwiftUI lists (server id when present, else tempId).
    public var listId: String { id ?? tempId }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        tempId = (try c.decodeIfPresent(String.self, forKey: .tempId)) ?? UUID().uuidString.lowercased()
        appealId = try c.decodeIfPresent(String.self, forKey: .appealId)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        originalMessage = try c.decodeIfPresent(String.self, forKey: .originalMessage)
        attachment = try c.decodeIfPresent(String.self, forKey: .attachment)
        attachmentUrl = try c.decodeIfPresent(String.self, forKey: .attachmentUrl)
        attachmentPreviewUrl = try c.decodeIfPresent(String.self, forKey: .attachmentPreviewUrl)
        attachmentId = try c.decodeIfPresent(String.self, forKey: .attachmentId)
        isOwn = try c.decodeIfPresent(Bool.self, forKey: .isOwn)
        date = try c.decodeIfPresent(DateObject.self, forKey: .date)
        dateToDisplay = try c.decodeIfPresent(String.self, forKey: .dateToDisplay)
        avatar = try c.decodeIfPresent(String.self, forKey: .avatar)
        avatarDefault = try c.decodeIfPresent(String.self, forKey: .avatarDefault)
        messageType = try c.decodeIfPresent(MessageType.self, forKey: .messageType)
        emojiOnly = try c.decodeIfPresent(Bool.self, forKey: .emojiOnly)
        progress = try c.decodeIfPresent(Int.self, forKey: .progress)
        isForm = try c.decodeIfPresent(Bool.self, forKey: .isForm)
        formId = try c.decodeIfPresent(String.self, forKey: .formId)
        formType = try c.decodeIfPresent(FormType.self, forKey: .formType)
        ratingValue = try c.decodeIfPresent(ConversationRating.self, forKey: .ratingValue)
        contactForm = try c.decodeIfPresent(ContactForm.self, forKey: .contactForm)
        `operator` = try c.decodeIfPresent(Operator.self, forKey: .operator)
        from = try c.decodeIfPresent(MessageFrom.self, forKey: .from)
        fromInvite = try c.decodeIfPresent(Bool.self, forKey: .fromInvite)
        serviceMessage = try c.decodeIfPresent(Bool.self, forKey: .serviceMessage)
        errorMessage = try c.decodeIfPresent(String.self, forKey: .errorMessage)
        width = try c.decodeIfPresent(Double.self, forKey: .width)
        height = try c.decodeIfPresent(Double.self, forKey: .height)
        unread = try c.decodeIfPresent(Bool.self, forKey: .unread)
        seen = try c.decodeIfPresent(Bool.self, forKey: .seen)
        status = try c.decodeIfPresent(MessageStatus.self, forKey: .status)
        size = try c.decodeIfPresent(Int.self, forKey: .size)
    }
}

extension ISO8601DateFormatter {
    static let teletype: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
