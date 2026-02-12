import Foundation

/// Wiederverwendbare, gecachte DateFormatter-Instanzen für das gesamte Projekt.
extension DateFormatter {
    /// Parst das YYYYMMDD-Format, das Claude zurückgibt.
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale    = Locale(identifier: "en_US_POSIX")
        f.timeZone  = TimeZone(identifier: "UTC")
        return f
    }()

    /// Gibt das Datum in einem lesbaren Format aus, z. B. „14. Jan. 2025".
    static let displayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
