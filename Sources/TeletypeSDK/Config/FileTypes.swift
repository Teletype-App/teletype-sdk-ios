import Foundation

public let imageMimeTypes: Set<String> = [
    "image/gif", "image/jpeg", "image/pjpeg", "image/png",
    "image/vnd.microsoft.icon", "image/vnd.wap.wbmp", "image/webp",
    "image/heic", "image/heif",
]

public let audioMimeTypes: Set<String> = [
    "audio/basic", "audio/L24", "audio/mp4", "audio/aac", "audio/mpeg",
    "audio/ogg", "audio/vorbis", "audio/x-ms-wma", "audio/x-ms-wax",
    "audio/vnd.rn-realaudio", "audio/vnd.wave", "audio/webm", "audio/mp3",
]

public let videoMimeTypes: Set<String> = [
    "video/mpeg", "video/mp4", "video/ogg", "video/quicktime", "video/webm",
    "video/x-ms-wmv", "video/x-flv", "video/3gpp", "video/3gpp2",
]

public let otherMimeTypes: Set<String> = [
    "video/3gp", "application/x-compressed", "audio/x-acc", "audio/ac3",
    "audio/x-aiff", "audio/aiff", "audio/x-au", "video/x-msvideo",
    "video/msvideo", "video/avi", "application/x-troff-msvideo",
    "image/bmp", "image/x-bmp", "image/x-bitmap", "image/x-xbitmap",
    "image/x-win-bitmap", "image/x-windows-bmp", "image/ms-bmp",
    "image/x-ms-bmp", "application/bmp", "application/x-bmp",
    "application/x-win-bitmap", "text/css", "text/x-comma-separated-values",
    "text/comma-separated-values", "application/vnd.msexcel",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/x-dvi", "message/rfc822", "video/x-f4v", "audio/x-flac",
    "application/x-gtar", "application/x-gzip", "text/html",
    "image/x-icon", "image/x-ico", "text/calendar", "application/java-archive",
    "application/x-java-application", "application/x-jar", "application/json",
    "text/json", "text/x-log", "audio/x-m4a", "audio/midi", "audio/mpg",
    "audio/mpeg3", "application/ogg", "application/pdf", "application/octet-stream",
    "image/x-png", "application/powerpoint", "application/vnd.ms-powerpoint",
    "application/vnd.ms-office", "application/msword",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "application/x-photoshop", "image/vnd.adobe.photoshop",
    "application/x-rar", "application/rar", "application/x-rar-compressed",
    "text/rtf", "text/richtext", "application/x-tar",
    "application/x-gzip-compressed", "text/plain", "text/x-vcard",
    "text/vtt", "audio/x-wav", "audio/wave", "audio/wav", "application/xhtml+xml",
    "application/excel", "application/msexcel", "application/x-msexcel",
    "application/x-ms-excel", "application/x-excel", "application/xls",
    "application/x-xls",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.ms-excel", "application/xml", "text/xml", "text/xsl",
    "application/x-compress", "application/x-zip", "application/zip",
    "application/x-zip-compressed", "application/s-compressed", "multipart/x-zip",
]

public let fileTypesList: Set<String> = otherMimeTypes
    .union(audioMimeTypes)
    .union(videoMimeTypes)
    .union(imageMimeTypes)

public let extensionFilesList: Set<String> = [
    ".jpeg", ".jpg", ".png", ".gif", ".pjpeg", ".svg", ".tif", ".tiff",
    ".wbmp", ".webp", ".heic", ".heif", ".au", ".mp4a", ".mpga", ".oga",
    ".wma", ".wax", ".weba", ".mpeg", ".mp4", ".ogv", ".qt", ".webm",
    ".wmv", ".flv", ".3gp", ".3g2", ".aif", ".avi", ".bmp", ".xbm",
    ".css", ".docx", ".dvi", ".eml", ".f4v", ".gtar", ".html", ".ico",
    ".ics", ".jar", ".json", ".kml", ".kmz", ".mid", ".movie", ".ogx",
    ".pdf", ".bin", ".ppt", ".doc", ".pptx", ".rar", ".rtx", ".tar",
    ".txt", ".vcf", ".wav", ".asf", ".xhtml", ".xlsx", ".xls", ".xml",
    ".zip", ".mov", ".m4v", ".m4a", ".aac", ".mp3", ".ogg", ".opus",
    ".amr", ".caf", ".flac", ".mkv",
]

private let imageExts: Set<String> = [
    "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "pjpeg",
]
private let videoExts: Set<String> = [
    "mp4", "mov", "m4v", "webm", "mkv", "avi", "3gp", "3g2", "ogv", "wmv", "flv",
]
private let audioExts: Set<String> = [
    "mp3", "m4a", "aac", "wav", "ogg", "oga", "flac", "opus", "amr", "caf",
    "mpga", "mp4a", "weba",
]

public func fileExtension(_ name: String) -> String {
    let base = name.split(separator: "?").first.map(String.init) ?? name
    let hashless = base.split(separator: "#").first.map(String.init) ?? base
    guard let idx = hashless.lastIndex(of: "."), idx != hashless.index(before: hashless.endIndex) else {
        return ""
    }
    return String(hashless[idx...]).lowercased()
}

public func isAllowedUploadFile(name: String?, type: String?) -> Bool {
    let mime = (type ?? "").lowercased()
    let ext = fileExtension(name ?? "")
    if !mime.isEmpty, fileTypesList.contains(mime) { return true }
    if !ext.isEmpty, extensionFilesList.contains(ext) { return true }
    return false
}

public func isAllowedUploadFile(_ file: LocalFile) -> Bool {
    isAllowedUploadFile(name: file.name, type: file.type)
}

public func messageTypeFromFile(name: String?, type: String?) -> MessageType {
    let mime = (type ?? "").lowercased()
    if imageMimeTypes.contains(mime) || mime.hasPrefix("image/") { return .image }
    if audioMimeTypes.contains(mime) || mime.hasPrefix("audio/") { return .audio }
    if videoMimeTypes.contains(mime) || mime.hasPrefix("video/") { return .video }
    let ext = fileExtension(name ?? "").replacingOccurrences(of: ".", with: "")
    if imageExts.contains(ext) { return .image }
    if videoExts.contains(ext) { return .video }
    if audioExts.contains(ext) { return .audio }
    return .attachment
}

public func messageTypeFromFile(_ file: LocalFile) -> MessageType {
    messageTypeFromFile(name: file.name, type: file.type)
}
