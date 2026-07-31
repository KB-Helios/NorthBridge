import Foundation
import Testing
@testable import Bolagscenter

struct NotificationDatePolicyTests {
    @Test
    func schedulesAtNineInTheMorningBeforeTarget() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let target = try #require(
            calendar.date(
                from: DateComponents(
                    year: 2027,
                    month: 2,
                    day: 10,
                    hour: 15
                )
            )
        )
        let now = try #require(
            calendar.date(
                from: DateComponents(
                    year: 2027,
                    month: 2,
                    day: 1,
                    hour: 8
                )
            )
        )

        let reminder = try #require(
            NotificationDatePolicy(calendar: calendar).reminderDate(
                targetDate: target,
                leadTimeDays: 3,
                now: now
            )
        )
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder
        )

        #expect(components.year == 2027)
        #expect(components.month == 2)
        #expect(components.day == 7)
        #expect(components.hour == 9)
        #expect(components.minute == 0)
    }

    @Test
    func doesNotScheduleReminderInThePast() {
        let now = Date(timeIntervalSince1970: 10_000)
        let result = NotificationDatePolicy(
            calendar: Calendar(identifier: .gregorian)
        ).reminderDate(
            targetDate: now.addingTimeInterval(-60),
            leadTimeDays: 0,
            now: now
        )

        #expect(result == nil)
    }
}
