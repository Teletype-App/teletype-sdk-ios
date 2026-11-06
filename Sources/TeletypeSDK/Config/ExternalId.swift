import Foundation

private let idPattern = try! NSRegularExpression(
    pattern: "^[A-Za-z0-9][A-Za-z0-9_-]{15,127}$"
)
private let snippetHint = try! NSRegularExpression(
    pattern: "<\\s*script|teletypeExternalId|widget\\.teletype(?:app)?\\.com",
    options: .caseInsensitive
)

/// Pull the channel id out of a dashboard `<script>` snippet, or return a
/// bare id unchanged. Returns `""` when the input looks like markup / prose.
public func extractTeletypeExternalId(_ input: String) -> String {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "" }

    if let match = trimmed.range(
        of: #"teletypeExternalId\s*=\s*["']([^"']+)["']"#,
        options: .regularExpression
    ) {
        let matched = String(trimmed[match])
        if let inner = matched.split(separator: "=").last {
            let id = inner
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !id.isEmpty { return id }
        }
    }

    let ns = trimmed as NSString
    let full = NSRange(location: 0, length: ns.length)
    if snippetHint.firstMatch(in: trimmed, range: full) != nil
        || trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
    {
        return ""
    }
    return trimmed
}

/// Minimal shape check for a Teletype external id: 16–128 URL-safe characters
/// with at least one letter and one digit.
public func isTeletypeExternalId(_ id: String) -> Bool {
    let ns = id as NSString
    let full = NSRange(location: 0, length: ns.length)
    guard idPattern.firstMatch(in: id, range: full) != nil else { return false }
    let hasLetter = id.rangeOfCharacter(from: .letters) != nil
    let hasDigit = id.rangeOfCharacter(from: .decimalDigits) != nil
    return hasLetter && hasDigit
}
