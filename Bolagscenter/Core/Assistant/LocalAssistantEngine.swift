import Foundation

enum AssistantStatementKind: String, Sendable {
    case fact
    case calculation
    case suggestion

    var localizedName: String {
        switch self {
        case .fact: "Fakta"
        case .calculation: "Beräkning"
        case .suggestion: "Förslag"
        }
    }
}

enum AssistantCitationDestination: Hashable, Sendable {
    case deadline(UUID)
    case document(UUID)
    case meeting(UUID)
    case resolution(UUID)
    case actions
    case finance
}

struct AssistantCitation: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let destination: AssistantCitationDestination
}

struct AssistantAgendaProposal: Equatable, Sendable {
    let title: String
    let scheduledAt: Date
    let items: [String]
}

struct AssistantAnswer: Equatable, Sendable {
    let kind: AssistantStatementKind
    let text: String
    let citations: [AssistantCitation]
    let agendaProposal: AssistantAgendaProposal?
}

struct AssistantDeadlineSnapshot: Sendable {
    let id: UUID
    let title: String
    let dueAt: Date
    let details: String
    let status: DeadlineStatus
    let sourceName: String
}

struct AssistantDocumentSnapshot: Sendable {
    let id: UUID
    let title: String
    let category: DocumentCategory
    let extractedText: String?
    let importedAt: Date
    let sourceName: String
}

struct AssistantMeetingSnapshot: Sendable {
    let id: UUID
    let title: String
    let scheduledAt: Date
    let status: BoardMeetingStatus
    let notes: String
}

struct AssistantResolutionSnapshot: Sendable {
    let id: UUID
    let title: String
    let decisionText: String
    let status: ResolutionStatus
    let decidedAt: Date?
}

struct AssistantActionSnapshot: Sendable {
    let id: UUID
    let title: String
    let assignedTo: String
    let dueAt: Date
    let status: ActionItemStatus
}

struct AssistantMetricSnapshot: Sendable {
    let id: UUID
    let kind: FinancialMetricKind
    let amount: Double
    let currencyCode: String
    let periodEnd: Date
    let sourceName: String
    let sourceUpdatedAt: Date
    let valueState: FinancialValueState
}

struct LocalAssistantContext: Sendable {
    let companyName: String
    let deadlines: [AssistantDeadlineSnapshot]
    let documents: [AssistantDocumentSnapshot]
    let meetings: [AssistantMeetingSnapshot]
    let resolutions: [AssistantResolutionSnapshot]
    let actions: [AssistantActionSnapshot]
    let metrics: [AssistantMetricSnapshot]
    let now: Date
}

struct LocalAssistantEngine: Sendable {
    func answer(
        question: String,
        context: LocalAssistantContext
    ) -> AssistantAnswer {
        let normalized = question
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        if normalized.contains("dagordning") {
            return agendaAnswer(context: context)
        }
        if normalized.contains("arsredovis") {
            return annualReportAnswer(context: context)
        }
        if normalized.contains("dokument")
            && (normalized.contains("saknas") || normalized.contains("missing")) {
            return missingDocumentsAnswer(context: context)
        }
        if normalized.contains("sammanfatta")
            && (normalized.contains("protokoll") || normalized.contains("mote")) {
            return minutesSummaryAnswer(context: context)
        }
        if normalized.contains("beslut")
            || normalized.contains("uppfolj")
            || normalized.contains("atgard") {
            return pendingActionsAnswer(context: context)
        }
        if normalized.contains("likvid")
            || normalized.contains("kassa")
            || normalized.contains("bank") {
            return liquidityAnswer(context: context)
        }
        return nextActionAnswer(context: context)
    }

    private func nextActionAnswer(
        context: LocalAssistantContext
    ) -> AssistantAnswer {
        let openDeadlines = context.deadlines
            .filter { $0.status != .completed && $0.status != .dismissed }
            .sorted { $0.dueAt < $1.dueAt }
        let openActions = context.actions
            .filter { $0.status != .completed }
            .sorted { $0.dueAt < $1.dueAt }

        let deadline = openDeadlines.first
        let action = openActions.first
        guard deadline != nil || action != nil else {
            return AssistantAnswer(
                kind: .fact,
                text: "Jag hittar inga öppna deadlines eller styrelseåtgärder i \(context.companyName). Det betyder bara att inga sådana poster är registrerade — inte att bolaget saknar externa skyldigheter.",
                citations: [],
                agendaProposal: nil
            )
        }

        if let deadline, action == nil || deadline.dueAt <= action?.dueAt ?? .distantFuture {
            return AssistantAnswer(
                kind: .fact,
                text: "Nästa registrerade åtgärd är deadline “\(deadline.title)” den \(date(deadline.dueAt)). \(deadline.details)",
                citations: [deadlineCitation(deadline)],
                agendaProposal: nil
            )
        }

        guard let action else {
            return AssistantAnswer(
                kind: .fact,
                text: "Ingen nästa åtgärd kunde bestämmas från registrerade poster.",
                citations: [],
                agendaProposal: nil
            )
        }
        return AssistantAnswer(
            kind: .fact,
            text: "Nästa registrerade styrelseåtgärd är “\(action.title)”, tilldelad \(action.assignedTo), med förfallodatum \(date(action.dueAt)).",
            citations: [actionCitation(action)],
            agendaProposal: nil
        )
    }

    private func annualReportAnswer(
        context: LocalAssistantContext
    ) -> AssistantAnswer {
        let candidates = context.deadlines
            .filter {
                $0.status != .completed
                    && $0.status != .dismissed
                    && $0.title.folding(
                        options: [.caseInsensitive, .diacriticInsensitive],
                        locale: .current
                    ).contains("arsredovis")
            }
            .sorted { $0.dueAt < $1.dueAt }
        guard let deadline = candidates.first else {
            return AssistantAnswer(
                kind: .fact,
                text: "Ingen öppen deadline för årsredovisning finns registrerad. Jag kan därför inte ange ett datum utan att hitta på uppgifter. Lägg till en källmarkerad deadline eller anslut en godkänd källa.",
                citations: [],
                agendaProposal: nil
            )
        }
        return AssistantAnswer(
            kind: .fact,
            text: "Den registrerade deadlinen för årsredovisning är \(date(deadline.dueAt)). Källan i posten är \(deadline.sourceName).",
            citations: [deadlineCitation(deadline)],
            agendaProposal: nil
        )
    }

    private func missingDocumentsAnswer(
        context: LocalAssistantContext
    ) -> AssistantAnswer {
        let expected: [DocumentCategory] = [
            .registrationCertificate,
            .articlesOfAssociation,
            .annualReports,
            .boardMinutes,
            .shareholderRegister
        ]
        let present = Set(context.documents.map(\.category))
        let missing = expected.filter { !present.contains($0) }
        guard !missing.isEmpty else {
            return AssistantAnswer(
                kind: .fact,
                text: "Alla fem grundkategorier som NorthBridge kontrollerar lokalt har minst ett dokument. Jag har inte bedömt dokumentens juridiska giltighet eller om fler handlingar krävs.",
                citations: context.documents
                    .filter { expected.contains($0.category) }
                    .prefix(5)
                    .map(documentCitation),
                agendaProposal: nil
            )
        }

        return AssistantAnswer(
            kind: .suggestion,
            text: "Följande grundkategorier saknar en registrerad fil: \(missing.map(\.localizedName).joined(separator: ", ")). Detta är en lokal kontroll av dokumentvalvet, inte en juridisk fullständighetsbedömning.",
            citations: [],
            agendaProposal: nil
        )
    }

    private func minutesSummaryAnswer(
        context: LocalAssistantContext
    ) -> AssistantAnswer {
        let minutes = context.documents
            .filter { $0.category == .boardMinutes }
            .sorted { $0.importedAt > $1.importedAt }
        if let document = minutes.first,
           let text = document.extractedText?.trimmingCharacters(
            in: .whitespacesAndNewlines
           ),
           !text.isEmpty {
            let excerpt = text.count > 700
                ? String(text.prefix(700)) + "…"
                : text
            return AssistantAnswer(
                kind: .fact,
                text: "Senaste protokollets lokalt extraherade text börjar:\n\n\(excerpt)\n\nDetta är ett utdrag, inte en AI-tolkning. Kontrollera originaldokumentet.",
                citations: [documentCitation(document)],
                agendaProposal: nil
            )
        }

        if let meeting = context.meetings
            .filter({ !$0.notes.isEmpty })
            .sorted(by: { $0.scheduledAt > $1.scheduledAt })
            .first {
            return AssistantAnswer(
                kind: .fact,
                text: "Inget styrelseprotokoll med extraherad text hittades. Senaste registrerade mötesanteckning är:\n\n\(meeting.notes)",
                citations: [meetingCitation(meeting)],
                agendaProposal: nil
            )
        }

        return AssistantAnswer(
            kind: .fact,
            text: "Jag hittar inget styrelseprotokoll med extraherad text och inga mötesanteckningar att sammanfatta.",
            citations: [],
            agendaProposal: nil
        )
    }

    private func pendingActionsAnswer(
        context: LocalAssistantContext
    ) -> AssistantAnswer {
        let actions = context.actions
            .filter { $0.status != .completed }
            .sorted { $0.dueAt < $1.dueAt }
        let draftResolutions = context.resolutions
            .filter { $0.status == .draft || $0.status == .tabled }
            .sorted { ($0.decidedAt ?? .distantFuture) < ($1.decidedAt ?? .distantFuture) }
        guard !actions.isEmpty || !draftResolutions.isEmpty else {
            return AssistantAnswer(
                kind: .fact,
                text: "Jag hittar inga öppna styrelseåtgärder eller beslut som är utkast eller bordlagda.",
                citations: [],
                agendaProposal: nil
            )
        }

        var parts: [String] = []
        if !actions.isEmpty {
            parts.append("\(actions.count) öppna åtgärder")
        }
        if !draftResolutions.isEmpty {
            parts.append("\(draftResolutions.count) beslut som väntar på behandling")
        }
        let citations = actions.prefix(4).map(actionCitation)
            + draftResolutions.prefix(4).map(resolutionCitation)
        return AssistantAnswer(
            kind: .fact,
            text: "Registrerade uppföljningsposter: \(parts.joined(separator: " och ")). Öppna källorna nedan för fullständig status.",
            citations: citations,
            agendaProposal: nil
        )
    }

    private func liquidityAnswer(
        context: LocalAssistantContext
    ) -> AssistantAnswer {
        let values = context.metrics
            .filter { $0.kind == .availableLiquidity || $0.kind == .bankBalance }
            .sorted { $0.periodEnd < $1.periodEnd }
        guard let latest = values.last else {
            return AssistantAnswer(
                kind: .fact,
                text: "Ingen tillgänglig likviditet eller banksaldopost finns registrerad. Jag kan därför inte beskriva utvecklingen.",
                citations: [],
                agendaProposal: nil
            )
        }

        guard values.count >= 2 else {
            return AssistantAnswer(
                kind: .fact,
                text: "Senaste registrerade \(latest.kind.localizedName.lowercased()) är \(money(latest)). En enda datapunkt räcker inte för att beräkna en utveckling.",
                citations: [metricCitation(latest)],
                agendaProposal: nil
            )
        }

        let previous = values[values.count - 2]
        let delta = latest.amount - previous.amount
        let direction = delta >= 0 ? "ökat" : "minskat"
        return AssistantAnswer(
            kind: .calculation,
            text: "\(latest.kind.localizedName) har \(direction) med \(abs(delta).formatted(.currency(code: latest.currencyCode))) mellan \(date(previous.periodEnd)) och \(date(latest.periodEnd)). Beräkningen jämför de två senaste lokalt registrerade posterna och är inte en kassaflödesprognos.",
            citations: [metricCitation(previous), metricCitation(latest)],
            agendaProposal: nil
        )
    }

    private func agendaAnswer(
        context: LocalAssistantContext
    ) -> AssistantAnswer {
        var items = [
            "Mötets öppnande",
            "Val av ordförande och protokollförare",
            "Godkännande av dagordning",
            "Föregående protokoll och öppna åtgärder"
        ]
        let overdue = context.deadlines
            .filter {
                $0.status != .completed
                    && $0.status != .dismissed
                    && $0.dueAt < context.now
            }
            .sorted { $0.dueAt < $1.dueAt }
        let actions = context.actions
            .filter { $0.status != .completed }
            .sorted { $0.dueAt < $1.dueAt }

        items += overdue.prefix(3).map { "Hantera försenad deadline: \($0.title)" }
        items += actions.prefix(3).map { "Följ upp åtgärd: \($0.title)" }
        items += ["Övriga frågor", "Mötets avslutande"]

        let citations = overdue.prefix(3).map(deadlineCitation)
            + actions.prefix(3).map(actionCitation)
        let proposal = AssistantAgendaProposal(
            title: "Styrelsemöte – utkast",
            scheduledAt: Calendar.current.date(
                byAdding: .day,
                value: 7,
                to: context.now
            ) ?? context.now.addingTimeInterval(7 * 86_400),
            items: items
        )
        return AssistantAnswer(
            kind: .suggestion,
            text: "Jag föreslår en dagordning med \(items.count) punkter baserad på standardpunkter och registrerade uppföljningar. Förslaget är utkaststöd, inte juridisk rådgivning. Granska allt innan ett mötesutkast skapas.",
            citations: citations,
            agendaProposal: proposal
        )
    }

    private func deadlineCitation(
        _ value: AssistantDeadlineSnapshot
    ) -> AssistantCitation {
        AssistantCitation(
            id: "deadline:\(value.id)",
            title: value.title,
            detail: "Deadline · \(date(value.dueAt)) · \(value.sourceName)",
            destination: .deadline(value.id)
        )
    }

    private func documentCitation(
        _ value: AssistantDocumentSnapshot
    ) -> AssistantCitation {
        AssistantCitation(
            id: "document:\(value.id)",
            title: value.title,
            detail: "Dokument · \(value.category.localizedName) · \(value.sourceName)",
            destination: .document(value.id)
        )
    }

    private func meetingCitation(
        _ value: AssistantMeetingSnapshot
    ) -> AssistantCitation {
        AssistantCitation(
            id: "meeting:\(value.id)",
            title: value.title,
            detail: "Möte · \(date(value.scheduledAt)) · \(value.status.localizedName)",
            destination: .meeting(value.id)
        )
    }

    private func resolutionCitation(
        _ value: AssistantResolutionSnapshot
    ) -> AssistantCitation {
        AssistantCitation(
            id: "resolution:\(value.id)",
            title: value.title,
            detail: "Beslut · \(value.status.localizedName)",
            destination: .resolution(value.id)
        )
    }

    private func actionCitation(
        _ value: AssistantActionSnapshot
    ) -> AssistantCitation {
        AssistantCitation(
            id: "action:\(value.id)",
            title: value.title,
            detail: "Åtgärd · \(value.assignedTo) · \(date(value.dueAt))",
            destination: .actions
        )
    }

    private func metricCitation(
        _ value: AssistantMetricSnapshot
    ) -> AssistantCitation {
        AssistantCitation(
            id: "metric:\(value.id)",
            title: value.kind.localizedName,
            detail: "\(money(value)) · \(value.sourceName) · \(date(value.sourceUpdatedAt))",
            destination: .finance
        )
    }

    private func date(_ value: Date) -> String {
        value.formatted(date: .long, time: .omitted)
    }

    private func money(_ value: AssistantMetricSnapshot) -> String {
        value.amount.formatted(.currency(code: value.currencyCode))
    }
}
