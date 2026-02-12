import Foundation

extension DateFormatter {
    /// Date formatter for parsing dates in YYYYMMDD format (e.g., "20240115")
    /// Used to parse dates extracted by Claude from PDF documents
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    /// Date formatter for displaying dates in a user-friendly format
    /// Uses the user's locale and displays as "15. Januar 2024" (German) or equivalent
    static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}
