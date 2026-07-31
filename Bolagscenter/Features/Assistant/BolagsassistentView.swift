import SwiftData
import SwiftUI

@MainActor
struct BolagsassistentView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var companies: [CompanyRecord]
    @Query private var memberships: [CompanyMembershipRecord]
    @Query private var deadlines: [DeadlineRecord]
    @Query private var documents: [DocumentRecord]
    @Query private var meetings: [BoardMeetingRecord]
    @Query private var resolutions: [BoardResolutionRecord]
    @Query private var actions: [ActionItemRecord]
    @Query private var metrics: [FinancialMetricRecord]

    @State private var question = ""
    @State private var exchanges: [AssistantExchange] = []
    @State private var proposalToConfirm: AssistantAgendaProposal?
    @State private var errorMessage: String?

    private let engine = LocalAssistantEngine()

    var body: some View {
        VStack(spacing: 0) {
            modeBanner

            if exchanges.isEmpty {
                starterContent
            } else {
                conversation
            }

            composer
        }
        .background(Color.appBackground)
        .navigationTitle("Bolagsassistenten")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Skapa mötesutkast?",
            isPresented: Binding(
                get: { proposalToConfirm != nil },
                set: { if !$0 { proposalToConfirm = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Skapa och öppna utkast") {
                createAgendaDraft()
            }
            Button("Avbryt", role: .cancel) {
                proposalToConfirm = nil
            }
        } message: {
            Text("NorthBridge sparar ett utkast med föreslagen dagordning. Du måste granska datum, plats och varje punkt.")
        }
        .alert(
            "Åtgärden kunde inte genomföras",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var modeBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Lokalt läge")
                    .font(.subheadline.weight(.semibold))
                Text("Svar byggs deterministiskt från behöriga poster på enheten. Inga bolagsdata skickas till en extern AI-tjänst.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .bolagscenterGlassSurface(
            cornerRadius: 16,
            tint: Color.bolagscenterBlue.opacity(0.06)
        )
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }

    private var starterContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                    Text("Fråga om registrerade bolagsdata")
                        .font(.title2.bold())
                    Text("Assistenten citerar alltid de poster som används och säger tydligt när underlag saknas.")
                        .foregroundStyle(.secondary)
                }

                LiquidGlassEffectGroup(spacing: 10) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Förslag")
                            .font(.headline)
                        ForEach(starterQuestions, id: \.self) { prompt in
                            Button {
                                ask(prompt)
                            } label: {
                                HStack {
                                    Text(prompt)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }

                Label(
                    "Svar är informationsunderlag och inte juridisk, skatte-, investerings- eller redovisningsrådgivning.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var conversation: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(exchanges) { exchange in
                    VStack(alignment: .trailing, spacing: 12) {
                        Text(exchange.question)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Color.bolagscenterBlue,
                                in: RoundedRectangle(
                                    cornerRadius: 16,
                                    style: .continuous
                                )
                            )
                            .foregroundStyle(.white)
                            .frame(maxWidth: 560, alignment: .trailing)

                        answerCard(exchange.answer)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(16)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(
                "Fråga om bolaget",
                text: $question,
                axis: .vertical
            )
            .lineLimit(1...5)
            .textFieldStyle(.roundedBorder)
            .submitLabel(.send)
            .onSubmit {
                submitQuestion()
            }
            .accessibilityIdentifier("assistant.question")

            Button {
                submitQuestion()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(question.trimmed.isEmpty || activeCompany == nil)
            .accessibilityLabel("Skicka fråga")
        }
        .padding(12)
        .background(.bar)
    }

    private func answerCard(_ answer: AssistantAnswer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusBadge(
                text: answer.kind.localizedName,
                kind: answer.kind == .fact ? .neutral : .warning
            )
            Text(answer.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !answer.citations.isEmpty {
                Divider()
                Text("Källor")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(answer.citations) { citation in
                    Button {
                        open(citation.destination)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(citation.title)
                                    .foregroundStyle(.primary)
                                Text(citation.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if let proposal = answer.agendaProposal {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Föreslagen dagordning")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(
                        Array(proposal.items.enumerated()),
                        id: \.offset
                    ) { index, item in
                        Text("\(index + 1). \(item)")
                            .font(.subheadline)
                    }
                }
                Button("Granska och skapa mötesutkast") {
                    proposalToConfirm = proposal
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(
            Color.appSurface,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .frame(maxWidth: 620, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var starterQuestions: [String] {
        [
            "Vad behöver jag göra härnäst?",
            "När ska årsredovisningen lämnas in?",
            "Vilka dokument saknas?",
            "Vilka beslut väntar på uppföljning?",
            "Hur har likviditeten utvecklats?",
            "Skapa ett utkast till dagordning."
        ]
    }

    private var activeCompany: CompanyRecord? {
        guard let companyID = environment.selectedCompanyID else { return nil }
        return companies.first { $0.id == companyID }
    }

    private var activeCompanyID: UUID? {
        activeCompany?.id
    }

    private var assistantContext: LocalAssistantContext? {
        guard let company = activeCompany else { return nil }
        let companyID = company.id
        return LocalAssistantContext(
            companyName: company.registeredName,
            deadlines: deadlines
                .filter { $0.companyID == companyID }
                .map {
                    AssistantDeadlineSnapshot(
                        id: $0.id,
                        title: $0.title,
                        dueAt: $0.dueAt,
                        details: $0.details,
                        status: $0.status,
                        sourceName: $0.sourceName
                    )
                },
            documents: documents
                .filter { $0.companyID == companyID }
                .map {
                    AssistantDocumentSnapshot(
                        id: $0.id,
                        title: $0.title,
                        category: $0.category,
                        extractedText: $0.extractedText,
                        importedAt: $0.importedAt,
                        sourceName: $0.sourceName
                    )
                },
            meetings: meetings
                .filter { $0.companyID == companyID }
                .map {
                    AssistantMeetingSnapshot(
                        id: $0.id,
                        title: $0.title,
                        scheduledAt: $0.scheduledAt,
                        status: $0.status,
                        notes: $0.notes
                    )
                },
            resolutions: resolutions
                .filter { $0.companyID == companyID }
                .map {
                    AssistantResolutionSnapshot(
                        id: $0.id,
                        title: $0.title,
                        decisionText: $0.decisionText,
                        status: $0.status,
                        decidedAt: $0.decidedAt
                    )
                },
            actions: actions
                .filter { $0.companyID == companyID }
                .map {
                    AssistantActionSnapshot(
                        id: $0.id,
                        title: $0.title,
                        assignedTo: $0.assignedTo,
                        dueAt: $0.dueAt,
                        status: $0.status
                    )
                },
            metrics: metrics
                .filter { $0.companyID == companyID }
                .map {
                    AssistantMetricSnapshot(
                        id: $0.id,
                        kind: $0.kind,
                        amount: $0.amount,
                        currencyCode: $0.currencyCode,
                        periodEnd: $0.periodEnd,
                        sourceName: $0.sourceName,
                        sourceUpdatedAt: $0.sourceUpdatedAt,
                        valueState: $0.valueState
                    )
                },
            now: .now
        )
    }

    private func submitQuestion() {
        let prompt = question.trimmed
        guard !prompt.isEmpty else { return }
        question = ""
        ask(prompt)
    }

    private func ask(_ prompt: String) {
        guard let assistantContext else {
            errorMessage = String(localized: "Välj ett behörigt bolag först.")
            return
        }
        let answer = engine.answer(
            question: prompt,
            context: assistantContext
        )
        withAnimation(reduceMotion ? nil : .snappy) {
            exchanges.append(
                AssistantExchange(
                    question: prompt,
                    answer: answer
                )
            )
        }
    }

    private func open(_ destination: AssistantCitationDestination) {
        switch destination {
        case .deadline(let id):
            environment.navigate(to: .deadline(id), in: .overview)
        case .document(let id):
            environment.navigate(to: .document(id), in: .documents)
        case .meeting(let id):
            environment.navigate(to: .boardMeeting(id), in: .company)
        case .resolution(let id):
            environment.navigate(to: .resolution(id), in: .company)
        case .actions:
            environment.navigate(to: .actionTracker, in: .company)
        case .finance:
            environment.selectedTab = .finance
        }
    }

    private func createAgendaDraft() {
        guard let proposal = proposalToConfirm,
              let companyID = activeCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.manageBoard, for: role) else {
            proposalToConfirm = nil
            errorMessage = String(localized: "Din roll saknar behörighet att skapa styrelsemöten.")
            return
        }

        let companyMeetingCount = meetings.filter {
            $0.companyID == companyID
        }.count
        let meeting = BoardMeetingRecord(
            companyID: companyID,
            title: proposal.title,
            meetingNumber: "UTK-\(companyMeetingCount + 1)",
            scheduledAt: proposal.scheduledAt,
            location: String(localized: "Ej angiven"),
            status: .draft,
            notes: String(localized: "Dagordningsutkast skapat lokalt av Bolagsassistenten efter användarens bekräftelse.")
        )
        modelContext.insert(meeting)
        for (index, item) in proposal.items.enumerated() {
            modelContext.insert(
                AgendaItemRecord(
                    companyID: companyID,
                    meetingID: meeting.id,
                    position: index + 1,
                    title: item,
                    details: ""
                )
            )
        }
        modelContext.insert(
            AuditEventRecord(
                companyID: companyID,
                accountID: accountID,
                action: "assistant.agendaDraftCreated",
                entityType: "boardMeeting",
                entityID: meeting.id,
                summary: String(localized: "Ett bekräftat dagordningsutkast skapades med Bolagsassistenten.")
            )
        )

        do {
            try modelContext.save()
            proposalToConfirm = nil
            environment.navigate(to: .boardMeeting(meeting.id), in: .company)
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Mötesutkastet kunde inte sparas.")
        }
    }
}

private struct AssistantExchange: Identifiable {
    let id = UUID()
    let question: String
    let answer: AssistantAnswer
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
