import Foundation

/// Recursively convert object keys to snake_case (for socket/REST payloads).
/// `NSNull` / nil becomes `""` — matching the web widget (`api.snakeKeys(null)`).
public func snakeKeys(_ input: Any?) -> Any {
    if input == nil || input is NSNull { return "" }
    if let arr = input as? [Any] { return arr.map { snakeKeys($0) } }
    if let dict = input as? [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in dict {
            if value is [String: Any] || value is [Any] {
                out[toSnake(key)] = snakeKeys(value)
            } else if value is NSNull {
                out[toSnake(key)] = ""
            } else {
                out[toSnake(key)] = value
            }
        }
        return out
    }
    return input as Any
}

/// Recursively convert object keys to camelCase (for parsing responses).
public func camelKeys(_ input: Any?) -> Any? {
    if input == nil || input is NSNull { return input }
    if let arr = input as? [Any] { return arr.map { camelKeys($0) as Any } }
    if let dict = input as? [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in dict {
            if value is [String: Any] || value is [Any] {
                out[toCamel(key)] = camelKeys(value) as Any
            } else {
                out[toCamel(key)] = value
            }
        }
        return out
    }
    return input
}

func toSnake(_ str: String) -> String {
    var s = str
        .replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1_$2", options: .regularExpression)
        .replacingOccurrences(of: "([A-Z]+)([A-Z][a-z])", with: "$1_$2", options: .regularExpression)
        .replacingOccurrences(of: "[\\s-]+", with: "_", options: .regularExpression)
    return s.lowercased()
}

func toCamel(_ str: String) -> String {
    var result = ""
    var upper = false
    for ch in str {
        if ch == "_" || ch == "-" {
            upper = true
        } else if upper {
            result.append(String(ch).uppercased())
            upper = false
        } else {
            result.append(ch)
        }
    }
    return result
}

/// Serialize a (possibly nested) object into `application/x-www-form-urlencoded`.
public func serialize(_ obj: [String: Any], prefix: String = "") -> String {
    var parts: [String] = []
    for (p, v) in obj {
        let k = prefix.isEmpty ? p : "\(prefix)[\(p)]"
        if let nested = v as? [String: Any] {
            parts.append(serialize(nested, prefix: k))
        } else {
            let value = "\(v)"
            let ek = k.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? k
            let ev = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            parts.append("\(ek)=\(ev)")
        }
    }
    return parts.joined(separator: "&")
}

public func guid() -> String {
    UUID().uuidString.lowercased()
}

public func isEmojiOnly(_ text: String?) -> Bool {
    guard let text, !text.isEmpty else { return false }
    var stripped = text
        .replacingOccurrences(of: "\u{FE0F}", with: "")
        .replacingOccurrences(of: "\u{200D}", with: "")
    stripped = stripped.unicodeScalars.filter { scalar in
        !(
            (0x1F300...0x1FAFF).contains(scalar.value)
            || (0x2600...0x27BF).contains(scalar.value)
            || (0x1F1E6...0x1F1FF).contains(scalar.value)
        )
    }.map { String($0) }.joined()
    return stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

public func formatBytes(_ bytes: Int?, decimals: Int = 2, strings: TeletypeStrings? = nil) -> String {
    let sizes = strings.map {
        [$0.Bt, $0.Kb, $0.Mb, $0.Gb, $0.Tb, $0.Pb, $0.Eb, $0.Zb, $0.Yb]
    } ?? ["BT", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]
    guard let bytes, bytes > 0 else { return "0 \(sizes[0])" }
    let k = 1024.0
    let i = min(Int(floor(log(Double(bytes)) / log(k))), sizes.count - 1)
    let value = Double(bytes) / pow(k, Double(i))
    let formatted = String(format: "%.\(max(0, decimals))f", value)
        .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    return "\(formatted) \(sizes[i])"
}

public func getExtension(_ nameOrUrl: String?) -> String {
    guard let nameOrUrl, !nameOrUrl.isEmpty else { return "" }
    let clean = nameOrUrl.split(separator: "?").first.map(String.init) ?? nameOrUrl
    let hashless = clean.split(separator: "#").first.map(String.init) ?? clean
    guard let idx = hashless.lastIndex(of: "."), idx != hashless.index(before: hashless.endIndex) else {
        return ""
    }
    return String(hashless[hashless.index(after: idx)...]).lowercased()
}

public func extractUrls(_ text: String) -> [String] {
    let re = try! NSRegularExpression(pattern: #"https?://[^\s]+"#)
    let ns = text as NSString
    let matches = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
    return matches.map { ns.substring(with: $0.range) }
}

func decodeJSON<T: Decodable>(_ value: Any?, as type: T.Type = T.self) -> T? {
    guard let value, !(value is NSNull) else { return nil }
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
       let decoded = try? JSONDecoder.teletype.decode(T.self, from: data)
    {
        return decoded
    }
    return nil
}

func encodeJSON(_ value: Encodable) -> Any? {
    guard let data = try? JSONEncoder.teletype.encode(AnyEncodable(value)) else { return nil }
    return try? JSONSerialization.jsonObject(with: data)
}

extension JSONDecoder {
    static let teletype: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()
}

extension JSONEncoder {
    static let teletype: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .useDefaultKeys
        return e
    }()
}

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

func jsonObject(from string: String) -> Any? {
    guard let data = string.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data)
}

func message(from raw: Any?) -> Message? {
    guard let camel = camelKeys(raw) else { return nil }
    if var msg = decodeJSON(camel, as: Message.self) {
        if msg.tempId.isEmpty { msg.tempId = guid() }
        return msg
    }
    // Fallback: loosely typed dict
    guard let dict = camel as? [String: Any] else { return nil }
    return messageFromDict(dict)
}

func messageFromDict(_ dict: [String: Any]) -> Message {
    var m = Message(tempId: stringVal(dict["tempId"]) ?? guid())
    m.id = stringVal(dict["id"])
    m.appealId = stringVal(dict["appealId"])
    m.message = stringVal(dict["message"])
    m.originalMessage = stringVal(dict["originalMessage"])
    m.attachment = stringVal(dict["attachment"])
    m.attachmentUrl = stringVal(dict["attachmentUrl"])
    m.attachmentPreviewUrl = stringVal(dict["attachmentPreviewUrl"])
    m.attachmentId = stringVal(dict["attachmentId"])
    m.isOwn = boolVal(dict["isOwn"])
    m.avatar = stringVal(dict["avatar"])
    m.date = decodeJSON(dict["date"], as: DateObject.self)
    if let type = stringVal(dict["messageType"]) {
        m.messageType = MessageType(rawValue: type)
    }
    m.emojiOnly = boolVal(dict["emojiOnly"])
    m.progress = intVal(dict["progress"])
    if let ft = stringVal(dict["formType"]) {
        m.formType = FormType(rawValue: ft)
    }
    m.serviceMessage = boolVal(dict["serviceMessage"])
    m.fromInvite = boolVal(dict["fromInvite"])
    m.errorMessage = stringVal(dict["errorMessage"])
    m.width = doubleVal(dict["width"])
    m.height = doubleVal(dict["height"])
    m.unread = boolVal(dict["unread"])
    m.seen = boolVal(dict["seen"])
    if let st = stringVal(dict["status"]) {
        m.status = MessageStatus(rawValue: st)
    }
    m.size = intVal(dict["size"])
    m.from = decodeJSON(dict["from"], as: MessageFrom.self)
    return m
}

func stringVal(_ v: Any?) -> String? {
    if let s = v as? String { return s }
    if let n = v as? NSNumber { return n.stringValue }
    return nil
}

func boolVal(_ v: Any?) -> Bool? {
    if let b = v as? Bool { return b }
    if let n = v as? NSNumber { return n.boolValue }
    return nil
}

func intVal(_ v: Any?) -> Int? {
    if let i = v as? Int { return i }
    if let n = v as? NSNumber { return n.intValue }
    return nil
}

func doubleVal(_ v: Any?) -> Double? {
    if let d = v as? Double { return d }
    if let n = v as? NSNumber { return n.doubleValue }
    return nil
}

func messageAsDict(_ message: Message) -> [String: Any] {
    guard let data = try? JSONEncoder.teletype.encode(message),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [:] }
    return obj
}
