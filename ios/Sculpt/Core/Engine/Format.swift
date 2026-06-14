import Foundation

// Ported from src/lib/format.ts. Swedish-friendly dates, comma decimals,
// time-of-day greeting.

enum Fmt {
    private static let swedish: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.dateFormat = "d MMMM"
        return f
    }()

    private static let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func parseISO(_ s: String) -> Date? {
        isoParser.date(from: s) ?? ISO8601DateFormatter().date(from: s)
            ?? {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = "yyyy-MM-dd"
                return f.date(from: String(s.prefix(10)))
            }()
    }

    /// "3 mars".
    static func day(_ iso: String) -> String {
        guard let d = parseISO(iso) else { return iso }
        return swedish.string(from: d)
    }

    static func day(_ date: Date) -> String { swedish.string(from: date) }

    static func range(_ start: String, _ end: String) -> String {
        "\(day(start)) – \(day(end))"
    }

    /// "40" or "12,5" — never trailing zeros, comma decimal.
    static func kg(_ value: Double?) -> String {
        guard let value else { return "—" }
        let rounded = (value * 100).rounded() / 100
        var s = String(format: "%g", rounded)
        s = s.replacingOccurrences(of: ".", with: ",")
        return s
    }

    static func greeting(_ name: String?) -> String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 5 ? "Good night"
            : h < 12 ? "Good morning"
            : h < 18 ? "Good afternoon" : "Good evening"
        if let name, !name.isEmpty { return "\(part), \(name)" }
        return part
    }

    /// Local date as YYYY-MM-DD.
    static func todayISO() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }
}
