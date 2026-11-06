import Foundation

public struct TeletypeStrings: Codable, Equatable, Sendable {
    public var headerTitleFallback: String
    public var headerReplyTime: String
    public var statusConnecting: String
    public var statusOnline: String
    public var statusOffline: String
    public var composerPlaceholder: String
    public var ratingTitle: String
    public var attachmentFallback: String
    public var messageSending: String
    public var messageDelivered: String
    public var messageSeen: String
    public var messageFailed: String
    public var timeJustNow: String
    public var timeAgo: String
    public var timeYesterday: String
    public var mediaSave: String
    public var mediaOpen: String
    public var mediaDownloading: String
    public var mediaSaved: String
    public var mediaDownloadError: String
    public var mediaCannotOpen: String
    public var mediaVideo: String
    public var mediaAudio: String
    public var mediaClose: String
    public var Bt: String
    public var Kb: String
    public var Mb: String
    public var Gb: String
    public var Tb: String
    public var Pb: String
    public var Eb: String
    public var Zb: String
    public var Yb: String
    public var send: String
    public var cancel: String
    public var sendImage: String
    public var sendVideo: String
    public var sendAudio: String
    public var sendFile: String
    public var attachPhoto: String
    public var attachVideo: String
    public var attachFile: String
    public var uploading: String
    public var fileSizeError: String
    public var fileFormatNotAllowed: String
    public var uploadFailed: String

    public static let fallback = TeletypeStrings(
        headerTitleFallback: "Chat",
        headerReplyTime: "Typically replies within an hour",
        statusConnecting: "Connecting…",
        statusOnline: "Online",
        statusOffline: "We will reply soon",
        composerPlaceholder: "Write here…",
        ratingTitle: "Please rate this conversation",
        attachmentFallback: "Attachment",
        messageSending: "sending…",
        messageDelivered: "Delivered",
        messageSeen: "Seen",
        messageFailed: "failed · tap to retry",
        timeJustNow: "Just now",
        timeAgo: "ago",
        timeYesterday: "Yesterday",
        mediaSave: "Save to device",
        mediaOpen: "Open",
        mediaDownloading: "Downloading…",
        mediaSaved: "Saved to device",
        mediaDownloadError: "Couldn't download the file",
        mediaCannotOpen: "No app can open this file",
        mediaVideo: "Video",
        mediaAudio: "Audio",
        mediaClose: "Close",
        Bt: "BT", Kb: "KB", Mb: "MB", Gb: "GB", Tb: "TB",
        Pb: "PB", Eb: "EB", Zb: "ZB", Yb: "YB",
        send: "Send",
        cancel: "Cancel",
        sendImage: "Send image",
        sendVideo: "Send video",
        sendAudio: "Send audio",
        sendFile: "Send file",
        attachPhoto: "Photo",
        attachVideo: "Video",
        attachFile: "File",
        uploading: "Loading",
        fileSizeError: "File is too large (max 20 MB)",
        fileFormatNotAllowed: "This file type is not allowed",
        uploadFailed: "Couldn't upload the file"
    )
}

public let DEFAULT_LOCALE = "en"

public typealias TeletypeTranslations = [String: PartialTeletypeStrings]

/// Sparse override table — missing keys fall back to the built-in locale, then English.
public struct PartialTeletypeStrings: Equatable, Sendable {
    public var values: [String: String]

    public init(_ values: [String: String] = [:]) {
        self.values = values
    }

    public subscript(key: String) -> String? {
        values[key]
    }
}

enum BuiltinLocales {
    static let en: TeletypeStrings = loadStrings(named: "en") ?? .fallback
    static let ru: TeletypeStrings = loadStrings(named: "ru") ?? .fallback

    static func table(for language: String) -> TeletypeStrings? {
        switch language {
        case "en": return en
        case "ru": return ru
        default: return nil
        }
    }
}

private func loadStrings(named name: String) -> TeletypeStrings? {
    let bundle = Bundle.module
    let url =
        bundle.url(forResource: name, withExtension: "json", subdirectory: "i18n")
        ?? bundle.url(forResource: name, withExtension: "json")
    guard let url, let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(TeletypeStrings.self, from: data)
}

public func normalizeLanguage(_ locale: String?) -> String {
    guard let locale, !locale.isEmpty else { return DEFAULT_LOCALE }
    let lang = locale.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)?.lowercased()
    return (lang?.isEmpty == false ? lang! : DEFAULT_LOCALE)
}

public func getSystemLanguage() -> String {
    let langs = Locale.preferredLanguages
    if let first = langs.first {
        return normalizeLanguage(first)
    }
    return normalizeLanguage(Locale.current.identifier)
}

public func resolveStrings(
    locale: String? = nil,
    translations: TeletypeTranslations? = nil
) -> (language: String, strings: TeletypeStrings) {
    let language = normalizeLanguage(locale ?? getSystemLanguage())
    var strings = BuiltinLocales.en
    if let builtin = BuiltinLocales.table(for: language) {
        strings = builtin
    }
    if let custom = translations?[language] {
        strings = strings.merging(custom)
    }
    return (language, strings)
}

extension TeletypeStrings {
    func merging(_ partial: PartialTeletypeStrings) -> TeletypeStrings {
        var copy = self
        func apply(_ key: String, set: (inout TeletypeStrings, String) -> Void) {
            if let v = partial.values[key] { set(&copy, v) }
        }
        apply("headerTitleFallback") { $0.headerTitleFallback = $1 }
        apply("headerReplyTime") { $0.headerReplyTime = $1 }
        apply("statusConnecting") { $0.statusConnecting = $1 }
        apply("statusOnline") { $0.statusOnline = $1 }
        apply("statusOffline") { $0.statusOffline = $1 }
        apply("composerPlaceholder") { $0.composerPlaceholder = $1 }
        apply("ratingTitle") { $0.ratingTitle = $1 }
        apply("attachmentFallback") { $0.attachmentFallback = $1 }
        apply("messageSending") { $0.messageSending = $1 }
        apply("messageDelivered") { $0.messageDelivered = $1 }
        apply("messageSeen") { $0.messageSeen = $1 }
        apply("messageFailed") { $0.messageFailed = $1 }
        apply("timeJustNow") { $0.timeJustNow = $1 }
        apply("timeAgo") { $0.timeAgo = $1 }
        apply("timeYesterday") { $0.timeYesterday = $1 }
        apply("mediaSave") { $0.mediaSave = $1 }
        apply("mediaOpen") { $0.mediaOpen = $1 }
        apply("mediaDownloading") { $0.mediaDownloading = $1 }
        apply("mediaSaved") { $0.mediaSaved = $1 }
        apply("mediaDownloadError") { $0.mediaDownloadError = $1 }
        apply("mediaCannotOpen") { $0.mediaCannotOpen = $1 }
        apply("mediaVideo") { $0.mediaVideo = $1 }
        apply("mediaAudio") { $0.mediaAudio = $1 }
        apply("mediaClose") { $0.mediaClose = $1 }
        apply("Bt") { $0.Bt = $1 }
        apply("Kb") { $0.Kb = $1 }
        apply("Mb") { $0.Mb = $1 }
        apply("Gb") { $0.Gb = $1 }
        apply("Tb") { $0.Tb = $1 }
        apply("Pb") { $0.Pb = $1 }
        apply("Eb") { $0.Eb = $1 }
        apply("Zb") { $0.Zb = $1 }
        apply("Yb") { $0.Yb = $1 }
        apply("send") { $0.send = $1 }
        apply("cancel") { $0.cancel = $1 }
        apply("sendImage") { $0.sendImage = $1 }
        apply("sendVideo") { $0.sendVideo = $1 }
        apply("sendAudio") { $0.sendAudio = $1 }
        apply("sendFile") { $0.sendFile = $1 }
        apply("attachPhoto") { $0.attachPhoto = $1 }
        apply("attachVideo") { $0.attachVideo = $1 }
        apply("attachFile") { $0.attachFile = $1 }
        apply("uploading") { $0.uploading = $1 }
        apply("fileSizeError") { $0.fileSizeError = $1 }
        apply("fileFormatNotAllowed") { $0.fileFormatNotAllowed = $1 }
        apply("uploadFailed") { $0.uploadFailed = $1 }
        return copy
    }
}
