import Foundation
import Testing
@testable import Bolagscenter

struct LocalAssistantEngineTests {
    private let engine = LocalAssistantEngine()

    @Test
    func refusesToInventAnnualReportDeadline() {
        let answer = engine.answer(
            question: "När ska årsredovisningen lämnas in?",
            context: emptyContext
        )

        #expect(answer.kind == .fact)
        #expect(answer.text.contains("kan därför inte ange ett datum"))
        #expect(answer.citations.isEmpty)
    }

    @Test
    func citesExactDeadlineForNextAction() {
        let deadlineID = UUID()
        var context = emptyContext
        context = LocalAssistantContext(
            companyName: context.companyName,
            deadlines: [
                AssistantDeadlineSnapshot(
                    id: deadlineID,
                    title: "Årsredovisning",
                    dueAt: context.now.addingTimeInterval(86_400),
                    details: "Skicka in fastställd årsredovisning.",
                    status: .open,
                    sourceName: "Bolagsverket"
                )
            ],
            documents: [],
            meetings: [],
            resolutions: [],
            actions: [],
            metrics: [],
            now: context.now
        )

        let answer = engine.answer(
            question: "Vad behöver jag göra härnäst?",
            context: context
        )

        #expect(answer.citations.count == 1)
        #expect(
            answer.citations.first?.destination == .deadline(deadlineID)
        )
    }

    @Test
    func labelsLiquidityDeltaAsCalculationAndCitesBothInputs() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let context = LocalAssistantContext(
            companyName: "Test AB",
            deadlines: [],
            documents: [],
            meetings: [],
            resolutions: [],
            actions: [],
            metrics: [
                AssistantMetricSnapshot(
                    id: UUID(),
                    kind: .availableLiquidity,
                    amount: 100_000,
                    currencyCode: "SEK",
                    periodEnd: now.addingTimeInterval(-86_400),
                    sourceName: "Test",
                    sourceUpdatedAt: now,
                    valueState: .booked
                ),
                AssistantMetricSnapshot(
                    id: UUID(),
                    kind: .availableLiquidity,
                    amount: 125_000,
                    currencyCode: "SEK",
                    periodEnd: now,
                    sourceName: "Test",
                    sourceUpdatedAt: now,
                    valueState: .booked
                )
            ],
            now: now
        )

        let answer = engine.answer(
            question: "Hur har likviditeten utvecklats?",
            context: context
        )

        #expect(answer.kind == .calculation)
        #expect(answer.citations.count == 2)
    }

    @Test
    func agendaRemainsProposalUntilCallerConfirmsPersistence() {
        let answer = engine.answer(
            question: "Skapa ett utkast till dagordning.",
            context: emptyContext
        )

        #expect(answer.kind == .suggestion)
        #expect(answer.agendaProposal != nil)
        #expect(answer.agendaProposal?.items.isEmpty == false)
    }

    private var emptyContext: LocalAssistantContext {
        LocalAssistantContext(
            companyName: "Test AB",
            deadlines: [],
            documents: [],
            meetings: [],
            resolutions: [],
            actions: [],
            metrics: [],
            now: Date(timeIntervalSince1970: 1_000_000)
        )
    }
}
