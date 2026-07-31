import Foundation

struct DeadlineRuleDefinition: Identifiable, Hashable, Sendable {
    let id: String
    let version: String
    let effectiveAt: Date
    let title: String
    let details: String
    let priority: DeadlinePriority
    let monthOffsetFromFinancialYearEnd: Int
    let sourceName: String
    let sourceURL: URL
}

struct GeneratedDeadlineDraft: Equatable, Sendable {
    let ruleIdentifier: String
    let ruleVersion: String
    let ruleEffectiveAt: Date
    let title: String
    let dueAt: Date
    let details: String
    let priority: DeadlinePriority
    let sourceName: String
    let sourceURL: URL
}

enum DeadlineRuleEngineError: LocalizedError, Sendable {
    case invalidFinancialYearEnd

    var errorDescription: String? {
        switch self {
        case .invalidFinancialYearEnd:
            "Räkenskapsårets slut kunde inte användas för deadlineberäkningen."
        }
    }
}

struct DeadlineRuleEngine: Sendable {
    let calendar: Calendar
    let rules: [DeadlineRuleDefinition]

    init(
        calendar: Calendar = .autoupdatingCurrent,
        rules: [DeadlineRuleDefinition] = DeadlineRuleCatalog.current
    ) {
        self.calendar = calendar
        self.rules = rules
    }

    func generate(
        financialYearEnd: Date,
        existingRuleKeys: Set<String> = []
    ) throws -> [GeneratedDeadlineDraft] {
        try rules.compactMap { rule in
            guard let dueAt = calendar.date(
                byAdding: .month,
                value: rule.monthOffsetFromFinancialYearEnd,
                to: financialYearEnd
            ) else {
                throw DeadlineRuleEngineError.invalidFinancialYearEnd
            }
            let key = Self.ruleKey(
                identifier: rule.id,
                dueAt: dueAt,
                calendar: calendar
            )
            guard !existingRuleKeys.contains(key) else { return nil }
            return GeneratedDeadlineDraft(
                ruleIdentifier: rule.id,
                ruleVersion: rule.version,
                ruleEffectiveAt: rule.effectiveAt,
                title: rule.title,
                dueAt: dueAt,
                details: rule.details,
                priority: rule.priority,
                sourceName: rule.sourceName,
                sourceURL: rule.sourceURL
            )
        }
    }

    static func ruleKey(
        identifier: String,
        dueAt: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: dueAt
        )
        return [
            identifier,
            components.year.map(String.init) ?? "",
            components.month.map(String.init) ?? "",
            components.day.map(String.init) ?? "",
        ].joined(separator: ":")
    }
}

enum DeadlineRuleCatalog {
    static let current: [DeadlineRuleDefinition] = [
        DeadlineRuleDefinition(
            id: "se.ab.annual-general-meeting",
            version: "2026.1",
            effectiveAt: catalogEffectiveAt,
            title: "Håll ordinarie årsstämma",
            details: "Årsstämman ska hållas inom sex månader från räkenskapsårets utgång. Kontrollera bolagsordning och bolagsspecifika omständigheter.",
            priority: .high,
            monthOffsetFromFinancialYearEnd: 6,
            sourceName: "Aktiebolagslagen (2005:551), 7 kap. 10 §",
            sourceURL: URL(
                string: "https://www.riksdagen.se/sv/dokument-och-lagar/dokument/svensk-forfattningssamling/aktiebolagslag-2005551_sfs-2005-551/"
            ) ?? fallbackSourceURL
        ),
        DeadlineRuleDefinition(
            id: "se.ab.annual-report-filing",
            version: "2026.1",
            effectiveAt: catalogEffectiveAt,
            title: "Skicka in årsredovisning",
            details: "Årsredovisningen ska ha kommit in till Bolagsverket senast sju månader efter räkenskapsårets slut. Kontrollera alltid aktuella undantag och bolagsspecifika krav.",
            priority: .critical,
            monthOffsetFromFinancialYearEnd: 7,
            sourceName: "Årsredovisningslagen (1995:1554), 8 kap. 6 §",
            sourceURL: URL(
                string: "https://www.riksdagen.se/sv/dokument-och-lagar/dokument/svensk-forfattningssamling/arsredovisningslag-19951554_sfs-1995-1554/"
            ) ?? fallbackSourceURL
        ),
    ]

    private static let fallbackSourceURL =
        URL(filePath: "/deadline-source-unavailable")

    private static let catalogEffectiveAt: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 1
        components.day = 1
        return components.date ?? Date(timeIntervalSince1970: 1_767_225_600)
    }()
}
