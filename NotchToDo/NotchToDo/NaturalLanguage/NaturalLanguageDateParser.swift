import Foundation

/// Result of natural language date/time parsing
struct ParsedDateTime {
    let date: Date?
    let time: Date?
    let originalText: String
    let confidence: Float
    let components: DateComponents?

    var combinedDateTime: Date? {
        guard let date = date else { return nil }

        // If we have a time component, combine date and time
        if let time = time {
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

            var combined = DateComponents()
            combined.year = dateComponents.year
            combined.month = dateComponents.month
            combined.day = dateComponents.day
            combined.hour = timeComponents.hour
            combined.minute = timeComponents.minute

            return calendar.date(from: combined)
        }

        return date
    }
}

/// Advanced natural language date and time parser
/// Handles relative dates, absolute dates, times, and compound expressions
class NaturalLanguageDateParser {

    private let calendar = Calendar.current
    private let dateDetector: NSDataDetector?

    // Relative date keywords
    private let relativeDateKeywords: [String: (Calendar, Date) -> Date?] = [
        "today": { calendar, ref in calendar.startOfDay(for: ref) },
        "tomorrow": { calendar, ref in calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: ref)) },
        "yesterday": { calendar, ref in calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: ref)) },
        "tonight": { calendar, ref in
            var components = calendar.dateComponents([.year, .month, .day], from: ref)
            components.hour = 20
            components.minute = 0
            return calendar.date(from: components)
        },
        "this morning": { calendar, ref in
            var components = calendar.dateComponents([.year, .month, .day], from: ref)
            components.hour = 9
            components.minute = 0
            return calendar.date(from: components)
        },
        "this afternoon": { calendar, ref in
            var components = calendar.dateComponents([.year, .month, .day], from: ref)
            components.hour = 14
            components.minute = 0
            return calendar.date(from: components)
        },
        "this evening": { calendar, ref in
            var components = calendar.dateComponents([.year, .month, .day], from: ref)
            components.hour = 18
            components.minute = 0
            return calendar.date(from: components)
        }
    ]

    // Weekday mappings
    private let weekdays: [String: Int] = [
        "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
        "thursday": 5, "friday": 6, "saturday": 7,
        "sun": 1, "mon": 2, "tue": 3, "wed": 4,
        "thu": 5, "fri": 6, "sat": 7
    ]

    // Month mappings
    private let months: [String: Int] = [
        "january": 1, "february": 2, "march": 3, "april": 4,
        "may": 5, "june": 6, "july": 7, "august": 8,
        "september": 9, "october": 10, "november": 11, "december": 12,
        "jan": 1, "feb": 2, "mar": 3, "apr": 4,
        "jun": 6, "jul": 7, "aug": 8,
        "sep": 9, "oct": 10, "nov": 11, "dec": 12
    ]

    init() {
        self.dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    }

    /// Parse natural language date/time from text
    /// Examples:
    /// - "tomorrow" → Date(tomorrow at 00:00)
    /// - "next Friday at 3pm" → Date(next Friday at 15:00)
    /// - "in 3 days" → Date(3 days from now)
    /// - "Jan 15" → Date(Jan 15 current year)
    func parse(_ text: String, referenceDate: Date = Date()) -> ParsedDateTime? {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Try different parsing strategies in order of confidence

        // 1. Check for relative date keywords (highest confidence)
        if let relativeDate = parseRelativeDate(lowercased, referenceDate: referenceDate) {
            return relativeDate
        }

        // 2. Check for weekday references ("next Friday", "this Monday")
        if let weekdayDate = parseWeekdayReference(lowercased, referenceDate: referenceDate) {
            return weekdayDate
        }

        // 3. Check for "in X days/weeks/months" patterns
        if let intervalDate = parseIntervalPattern(lowercased, referenceDate: referenceDate) {
            return intervalDate
        }

        // 4. Check for absolute dates using NSDataDetector
        if let detectedDate = parseWithDataDetector(text, referenceDate: referenceDate) {
            return detectedDate
        }

        // 5. Check for month + day patterns ("Jan 15", "January 15th")
        if let monthDayDate = parseMonthDayPattern(lowercased, referenceDate: referenceDate) {
            return monthDayDate
        }

        // 6. Check for time-only patterns ("at 3pm", "at 15:00")
        if let timeOnly = parseTimeOnly(lowercased, referenceDate: referenceDate) {
            return timeOnly
        }

        return nil
    }

    // MARK: - Parsing Strategies

    private func parseRelativeDate(_ text: String, referenceDate: Date) -> ParsedDateTime? {
        for (keyword, dateFunc) in relativeDateKeywords {
            if text.contains(keyword) {
                if let date = dateFunc(calendar, referenceDate) {
                    // Check if there's also a time component
                    let timeComponent = extractTime(from: text, referenceDate: referenceDate)
                    return ParsedDateTime(
                        date: date,
                        time: timeComponent,
                        originalText: text,
                        confidence: 0.95,
                        components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                    )
                }
            }
        }
        return nil
    }

    private func parseWeekdayReference(_ text: String, referenceDate: Date) -> ParsedDateTime? {
        for (weekdayName, weekdayNum) in weekdays {
            if text.contains(weekdayName) {
                let isNext = text.contains("next")
                let isThis = text.contains("this")

                guard let targetDate = findNextWeekday(weekdayNum, from: referenceDate, preferNext: isNext) else {
                    continue
                }

                let timeComponent = extractTime(from: text, referenceDate: targetDate)

                return ParsedDateTime(
                    date: targetDate,
                    time: timeComponent,
                    originalText: text,
                    confidence: 0.90,
                    components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
                )
            }
        }
        return nil
    }

    private func parseIntervalPattern(_ text: String, referenceDate: Date) -> ParsedDateTime? {
        // Patterns like "in 3 days", "in 2 weeks", "in 1 month"
        let pattern = #"in\s+(\d+)\s+(day|days|week|weeks|month|months|hour|hours)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numberRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text) else {
            return nil
        }

        let numberStr = String(text[numberRange])
        let unitStr = String(text[unitRange])

        guard let number = Int(numberStr) else { return nil }

        var component: Calendar.Component
        switch unitStr {
        case "day", "days":
            component = .day
        case "week", "weeks":
            component = .weekOfYear
        case "month", "months":
            component = .month
        case "hour", "hours":
            component = .hour
        default:
            return nil
        }

        guard let targetDate = calendar.date(byAdding: component, value: number, to: referenceDate) else {
            return nil
        }

        return ParsedDateTime(
            date: targetDate,
            time: nil,
            originalText: text,
            confidence: 0.85,
            components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
        )
    }

    private func parseWithDataDetector(_ text: String, referenceDate: Date) -> ParsedDateTime? {
        guard let detector = dateDetector else { return nil }

        let nsText = text as NSString
        let matches = detector.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            if let date = match.date {
                return ParsedDateTime(
                    date: date,
                    time: nil,
                    originalText: nsText.substring(with: match.range),
                    confidence: 0.80,
                    components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                )
            }
        }

        return nil
    }

    private func parseMonthDayPattern(_ text: String, referenceDate: Date) -> ParsedDateTime? {
        // Pattern: "jan 15", "january 15th", "15 jan", etc.
        for (monthName, monthNum) in months {
            if text.contains(monthName) {
                // Look for a day number near the month name
                let pattern = #"(\d+)(?:st|nd|rd|th)?"#
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                      let dayRange = Range(match.range(at: 1), in: text) else {
                    continue
                }

                let dayStr = String(text[dayRange])
                guard let day = Int(dayStr), day >= 1, day <= 31 else { continue }

                var components = calendar.dateComponents([.year], from: referenceDate)
                components.month = monthNum
                components.day = day
                components.hour = 0
                components.minute = 0

                guard let targetDate = calendar.date(from: components) else { continue }

                // If the date is in the past, assume next year
                let finalDate: Date
                if targetDate < referenceDate {
                    components.year = (components.year ?? 0) + 1
                    finalDate = calendar.date(from: components) ?? targetDate
                } else {
                    finalDate = targetDate
                }

                let timeComponent = extractTime(from: text, referenceDate: finalDate)

                return ParsedDateTime(
                    date: finalDate,
                    time: timeComponent,
                    originalText: text,
                    confidence: 0.85,
                    components: components
                )
            }
        }
        return nil
    }

    private func parseTimeOnly(_ text: String, referenceDate: Date) -> ParsedDateTime? {
        guard let time = extractTime(from: text, referenceDate: referenceDate) else {
            return nil
        }

        return ParsedDateTime(
            date: calendar.startOfDay(for: referenceDate),
            time: time,
            originalText: text,
            confidence: 0.75,
            components: calendar.dateComponents([.hour, .minute], from: time)
        )
    }

    // MARK: - Helper Functions

    private func extractTime(from text: String, referenceDate: Date) -> Date? {
        // Patterns for time extraction
        // "at 3pm", "at 15:00", "3:30pm", "at 3 pm"

        // 12-hour format with am/pm
        let pattern12Hour = #"(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#
        if let regex = try? NSRegularExpression(pattern: pattern12Hour, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let hourRange = Range(match.range(at: 1), in: text) {

            let hourStr = String(text[hourRange])
            guard var hour = Int(hourStr) else { return nil }

            var minute = 0
            if match.range(at: 2).location != NSNotFound,
               let minuteRange = Range(match.range(at: 2), in: text) {
                let minuteStr = String(text[minuteRange])
                minute = Int(minuteStr) ?? 0
            }

            if match.range(at: 3).location != NSNotFound,
               let ampmRange = Range(match.range(at: 3), in: text) {
                let ampm = String(text[ampmRange]).lowercased()
                if ampm == "pm" && hour < 12 {
                    hour += 12
                } else if ampm == "am" && hour == 12 {
                    hour = 0
                }
            }

            var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
            components.hour = hour
            components.minute = minute

            return calendar.date(from: components)
        }

        // 24-hour format
        let pattern24Hour = #"(?:at\s+)?(\d{1,2}):(\d{2})"#
        if let regex = try? NSRegularExpression(pattern: pattern24Hour),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let hourRange = Range(match.range(at: 1), in: text),
           let minuteRange = Range(match.range(at: 2), in: text) {

            let hourStr = String(text[hourRange])
            let minuteStr = String(text[minuteRange])

            guard let hour = Int(hourStr), let minute = Int(minuteStr) else { return nil }
            guard hour >= 0 && hour < 24 && minute >= 0 && minute < 60 else { return nil }

            var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
            components.hour = hour
            components.minute = minute

            return calendar.date(from: components)
        }

        return nil
    }

    private func findNextWeekday(_ targetWeekday: Int, from referenceDate: Date, preferNext: Bool) -> Date? {
        let currentWeekday = calendar.component(.weekday, from: referenceDate)

        var daysToAdd = targetWeekday - currentWeekday

        if daysToAdd < 0 || (daysToAdd == 0 && preferNext) {
            daysToAdd += 7
        }

        if daysToAdd == 0 {
            return calendar.startOfDay(for: referenceDate)
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: referenceDate))
    }
}
