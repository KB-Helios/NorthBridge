import Foundation
import Testing
@testable import Bolagscenter

struct DeadlineRuleEngineTests {
    @Test
    func generatesVersionedDeadlinesFromFinancialYearEnd() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let financialYearEnd = try #require(
            calendar.date(
                from: DateComponents(year: 2026, month: 12, day: 31)
            )
        )

        let drafts = try DeadlineRuleEngine(calendar: calendar).generate(
            financialYearEnd: financialYearEnd
        )

        #expect(drafts.count == 2)
        let meeting = try #require(
            drafts.first {
                $0.ruleIdentifier == "se.ab.annual-general-meeting"
            }
        )
        let filing = try #require(
            drafts.first {
                $0.ruleIdentifier == "se.ab.annual-report-filing"
            }
        )
        #expect(
            calendar.dateComponents(
                [.year, .month, .day],
                from: meeting.dueAt
            ) == DateComponents(year: 2027, month: 6, day: 30)
        )
        #expect(
            calendar.dateComponents(
                [.year, .month, .day],
                from: filing.dueAt
            ) == DateComponents(year: 2027, month: 7, day: 31)
        )
        #expect(meeting.ruleVersion == "2026.1")
        #expect(meeting.sourceURL.scheme == "https")
    }

    @Test
    func skipsAnExistingRuleForTheSameDueDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let financialYearEnd = try #require(
            calendar.date(
                from: DateComponents(year: 2026, month: 12, day: 31)
            )
        )
        let existingDueAt = try #require(
            calendar.date(
                from: DateComponents(year: 2027, month: 6, day: 30)
            )
        )
        let key = DeadlineRuleEngine.ruleKey(
            identifier: "se.ab.annual-general-meeting",
            dueAt: existingDueAt,
            calendar: calendar
        )

        let drafts = try DeadlineRuleEngine(calendar: calendar).generate(
            financialYearEnd: financialYearEnd,
            existingRuleKeys: [key]
        )

        #expect(drafts.count == 1)
        #expect(
            drafts.first?.ruleIdentifier == "se.ab.annual-report-filing"
        )
    }
}
