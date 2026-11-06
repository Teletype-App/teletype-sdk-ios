import Foundation

/// A local file picked on the device.
public struct LocalFile: Equatable, Sendable {
    public var uri: String
    public var name: String
    public var type: String
    public var size: Int?
    public var width: Double?
    public var height: Double?
    /// Generated image cover for a video (not the video file itself).
    public var previewUri: String?

    public init(
        uri: String,
        name: String,
        type: String,
        size: Int? = nil,
        width: Double? = nil,
        height: Double? = nil,
        previewUri: String? = nil
    ) {
        self.uri = uri
        self.name = name
        self.type = type
        self.size = size
        self.width = width
        self.height = height
        self.previewUri = previewUri
    }
}

public typealias PickedAttachment = LocalFile

/// Result of a successful `POST widget-attachment/<channel_id>` upload.
public struct UploadedAttachment: Equatable, Sendable {
    public var attachment: String
    public var attachmentId: String
    public var attachmentUrl: String
    public var type: MessageType
    public var width: Double?
    public var height: Double?
    public var size: Int?

    public init(
        attachment: String,
        attachmentId: String,
        attachmentUrl: String,
        type: MessageType,
        width: Double? = nil,
        height: Double? = nil,
        size: Int? = nil
    ) {
        self.attachment = attachment
        self.attachmentId = attachmentId
        self.attachmentUrl = attachmentUrl
        self.type = type
        self.width = width
        self.height = height
        self.size = size
    }
}
