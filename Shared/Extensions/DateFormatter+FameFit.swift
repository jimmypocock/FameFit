//
//  DateFormatter+FameFit.swift
//  FameFit
//
//  Date formatting extensions with proper timezone handling
//

import Foundation

extension DateFormatter {
    
    // MARK: - Shared Formatters (for performance)
    
    static let workoutDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = .current
        return formatter
    }()
    
    static let workoutTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return formatter
    }()
    
    static let workoutDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return formatter
    }()
    
    static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    
    // MARK: - Custom Formatters
    
    static func workoutFormatter(dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.timeZone = .current
        formatter.doesRelativeDateFormatting = true
        return formatter
    }
    
    static func utcFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter
    }
}

// MARK: - Date Extension for Formatting

extension Date {
    
    /// Formats the date for workout display (respects user's timezone)
    var workoutDisplayDate: String {
        DateFormatter.workoutDateFormatter.string(from: self)
    }
    
    /// Formats the time for workout display (respects user's timezone)
    var workoutDisplayTime: String {
        DateFormatter.workoutTimeFormatter.string(from: self)
    }
    
    /// Formats the date and time for workout display (respects user's timezone)
    var workoutDisplayDateTime: String {
        DateFormatter.workoutDateTimeFormatter.string(from: self)
    }
    
    /// Returns a relative date string (e.g., "2 hours ago", "yesterday")
    var relativeDisplayString: String {
        DateFormatter.relativeDateFormatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Checks if this date is today in the user's timezone
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Checks if this date is yesterday in the user's timezone
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// Returns time components for display
    func timeComponents(in timeZone: TimeZone = .current) -> (hour: Int, minute: Int) {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0, components.minute ?? 0)
    }
}

// MARK: - Timezone Helpers

extension TimeZone {
    /// Returns a user-friendly display name for the timezone
    var displayName: String {
        let name = self.identifier.replacingOccurrences(of: "_", with: " ")
        if let abbreviation = self.abbreviation() {
            return "\(name) (\(abbreviation))"
        }
        return name
    }
    
    /// Returns offset from UTC in hours
    var hoursFromUTC: Double {
        Double(self.secondsFromGMT()) / 3600.0
    }
}