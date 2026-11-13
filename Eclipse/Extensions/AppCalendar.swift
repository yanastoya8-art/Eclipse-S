import Foundation

enum AppCalendar {
    static var current: Calendar {
        gregorian(matching: .current)
    }

    static func gregorian(matching calendar: Calendar) -> Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.locale = calendar.locale
        gregorian.timeZone = calendar.timeZone
        gregorian.firstWeekday = calendar.firstWeekday
        gregorian.minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        return gregorian
    }

    static func dateFormatter(calendar: Calendar = current) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = gregorian(matching: calendar)
        return formatter
    }

    static func mediaYearRange(now: Date = Date(), calendar: Calendar = current) -> ClosedRange<Int> {
        1950...max(1950, gregorian(matching: calendar).component(.year, from: now))
    }

    /// Returns the next local 03:00 boundary for a daily background refresh.
    /// BGTaskScheduler treats this as a lower bound, not an exact execution time.
    static func nextDailyRefreshDate(
        after now: Date,
        hour: Int = 3,
        calendar: Calendar = current
    ) -> Date {
        let calendar = gregorian(matching: calendar)
        let todayAtRefreshTime = calendar.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: now
        ) ?? calendar.startOfDay(for: now).addingTimeInterval(TimeInterval(hour * 60 * 60))
        if todayAtRefreshTime > now {
            return todayAtRefreshTime
        }
        return calendar.date(byAdding: .day, value: 1, to: todayAtRefreshTime)
            ?? now.addingTimeInterval(24 * 60 * 60)
    }
}

/// Pure policy for the once-per-local-day schedule refresh.
enum DailyScheduleRefreshPolicy {
    static let retryInterval: TimeInterval = 2 * 60 * 60

    static func shouldRefresh(
        now: Date,
        lastSuccessfulRefresh: Date?,
        lastAttempt: Date?,
        calendar: Calendar = AppCalendar.current
    ) -> Bool {
        if let lastSuccessfulRefresh,
           calendar.isDate(lastSuccessfulRefresh, inSameDayAs: now) {
            return false
        }
        if let lastAttempt,
           now.timeIntervalSince(lastAttempt) < retryInterval {
            return false
        }
        return true
    }
}
