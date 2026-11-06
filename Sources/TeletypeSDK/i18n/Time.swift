import Foundation

private let secMin = 60
private let secHour = 60 * 60
private let secDay = 60 * 60 * 24

private let units: [String: (minute: [String], hour: [String])] = [
    "en": (["minute", "minutes"], ["hour", "hours"]),
    "ru": (["минуту", "минуты", "минут"], ["час", "часа", "часов"]),
]

private let months: [String: [String]] = [
    "en": [
        "January", "February", "March", "April", "May", "June", "July",
        "August", "September", "October", "November", "December",
    ],
    "ru": [
        "января", "февраля", "марта", "апреля", "мая", "июня", "июля",
        "августа", "сентября", "октября", "ноября", "декабря",
    ],
]

private func morph(_ n: Int, _ forms: [String], language: String) -> String {
    if language == "ru" {
        let mod100 = abs(n) % 100
        let mod10 = mod100 % 10
        if (11...14).contains(mod100) { return forms[min(2, forms.count - 1)] }
        if mod10 == 1 { return forms[0] }
        if (2...4).contains(mod10) { return forms[min(1, forms.count - 1)] }
        return forms[min(2, forms.count - 1)]
    }
    return n == 1 ? forms[0] : forms[min(1, forms.count - 1)]
}

private func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

private func hhmm(_ date: Date) -> String {
    let c = Calendar.current
    return "\(pad(c.component(.hour, from: date))):\(pad(c.component(.minute, from: date)))"
}

/// Human-friendly relative timestamp, mirroring the Teletype web widget.
public func formatRelativeTime(
    _ iso: String?,
    language: String,
    strings: TeletypeStrings
) -> String {
    guard let iso, !iso.isEmpty else { return "" }
    let date: Date
    if let parsed = ISO8601DateFormatter.teletype.date(from: iso) {
        date = parsed
    } else {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        guard let parsed = f.date(from: iso) ?? parseFlexible(iso) else { return "" }
        date = parsed
    }

    let u = units[language] ?? units["en"]!
    let diffSec = max(0, Int(Date().timeIntervalSince(date)))

    if diffSec < secMin { return strings.timeJustNow }
    if diffSec < secHour {
        let n = diffSec / secMin
        return "\(n) \(morph(n, u.minute, language: language)) \(strings.timeAgo)"
    }
    if diffSec < secHour * 3 {
        let n = diffSec / secHour
        return "\(n) \(morph(n, u.hour, language: language)) \(strings.timeAgo)"
    }
    if diffSec < secDay { return hhmm(date) }
    if diffSec < secDay * 2 { return "\(strings.timeYesterday) \(hhmm(date))" }

    let m = months[language] ?? months["en"]!
    let day = Calendar.current.component(.day, from: date)
    let month = m[Calendar.current.component(.month, from: date) - 1]
    let year = Calendar.current.component(.year, from: date)
    if year == Calendar.current.component(.year, from: Date()) {
        return "\(day) \(month)"
    }
    return "\(day) \(month), \(year)"
}

private func parseFlexible(_ iso: String) -> Date? {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd HH:mm:ss"] {
        f.dateFormat = format
        if let d = f.date(from: iso) { return d }
    }
    return nil
}
