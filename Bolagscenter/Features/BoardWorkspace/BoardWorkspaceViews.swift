import SwiftData
import SwiftUI

@MainActor
struct BoardWorkspaceView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \BoardMeetingRecord.scheduledAt, order: .reverse) private var meetings: [BoardMeetingRecord]
    @Query(sort: \ActionItemRecord.dueAt) private var actions: [ActionItemRecord]

    var body: some View {
        List {
            if environment.selectedCompanyID == nil {
                EmptyStateView(
                    systemImage: "building.2",
                    title: "Inget bolag valt",
                    message: "Välj ett bolag för att hantera styrelsearbetet."
                )
            } else {
                Section {
                    NavigationLink(value: AppRoute.boardAndSignatories) {
                        Label("Styrelse och firmateckning", systemImage: "person.3")
                    }
                    NavigationLink(value: AppRoute.actionTracker) {
                        LabeledContent {
                            Text(openActions.count.formatted())
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Åtgärder och uppföljning", systemImage: "checklist")
                        }
                    }
                }

                Section("Styrelsemöten") {
                    if companyMeetings.isEmpty {
                        ContentUnavailableView {
                            Label("Inga styrelsemöten", systemImage: "person.3.sequence")
                        } description: {
                            Text("Skapa ett möte och bygg dagordning, beslut och uppföljning.")
                        } actions: {
                            Button("Skapa möte") {
                                router.navigate(to: .addBoardMeeting)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(companyMeetings) { meeting in
                            NavigationLink(value: AppRoute.boardMeeting(meeting.id)) {
                                BoardMeetingRow(meeting: meeting)
                            }
                        }
                    }
                }

                Section {
                    Text("Mallar och protokoll i NorthBridge är utkaststöd och utgör inte juridisk rådgivning.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Styrelsearbete")
        .scrollContentBackground(.hidden)
        .background(Color.northBridgeBackground)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nytt möte", systemImage: "plus") {
                    router.navigate(to: .addBoardMeeting)
                }
                .disabled(environment.selectedCompanyID == nil)
                .accessibilityIdentifier("board.createMeeting")
            }
        }
    }

    private var companyMeetings: [BoardMeetingRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return meetings.filter { $0.companyID == companyID }
    }

    private var openActions: [ActionItemRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return actions.filter {
            $0.companyID == companyID && $0.status != .completed
        }
    }

    private var router: RouterPath {
        environment.router(for: environment.selectedTab)
    }
}

private struct BoardMeetingRow: View {
    let meeting: BoardMeetingRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(meeting.title)
                    .font(.body.weight(.semibold))
                Spacer()
                StatusBadge(text: meeting.status.localizedName, kind: badgeKind)
            }
            Text(meeting.scheduledAt, format: .dateTime.day().month().year().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label(meeting.location, systemImage: "mappin.and.ellipse")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    private var badgeKind: StatusBadge.Kind {
        switch meeting.status {
        case .approved: .positive
        case .cancelled: .critical
        case .held: .warning
        case .draft, .scheduled: .neutral
        }
    }
}

private struct BoardMemberEditorDestination: Identifiable {
    let id = UUID()
}

@MainActor
struct BoardAndSignatoriesView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \BoardMemberRecord.createdAt) private var members: [BoardMemberRecord]
    @Query(sort: \PersonRecord.fullName) private var people: [PersonRecord]

    @State private var editor: BoardMemberEditorDestination?

    var body: some View {
        Group {
            if companyMembers.isEmpty {
                EmptyStateView(
                    systemImage: "person.3",
                    title: "Styrelsen saknar poster",
                    message: "Registrera styrelseledamöter och firmatecknare med ett tydligt källunderlag.",
                    actionTitle: "Lägg till person",
                    action: { editor = BoardMemberEditorDestination() }
                )
            } else {
                List {
                    Section("Aktuella mandat") {
                        ForEach(companyMembers) { member in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(personName(for: member.personID))
                                    .font(.body.weight(.semibold))
                                HStack {
                                    Text(member.role.localizedName)
                                    if member.isSignatory {
                                        Text("· Firmatecknare")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                Text("Mandat från \(member.mandateStartsAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }

                    Section("Datakvalitet") {
                        Text("Manuellt registrerade poster måste kontrolleras mot bolagets officiella registreringsbevis eller annan spårbar källa.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Styrelse")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.northBridgeBackground)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Lägg till", systemImage: "person.badge.plus") {
                    editor = BoardMemberEditorDestination()
                }
            }
        }
        .sheet(item: $editor) { _ in
            BoardMemberEditorView()
        }
    }

    private var companyMembers: [BoardMemberRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return members.filter {
            guard $0.companyID == companyID else { return false }
            guard let mandateEndsAt = $0.mandateEndsAt else { return true }
            return mandateEndsAt >= .now
        }
    }

    private func personName(for personID: UUID) -> String {
        people.first { $0.id == personID }?.fullName ?? String(localized: "Okänd person")
    }
}

@MainActor
private struct BoardMemberEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var fullName = ""
    @State private var email = ""
    @State private var role: BoardMemberRole = .member
    @State private var isSignatory = false
    @State private var mandateStartsAt = Date.now
    @State private var sourceName = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("Namn", text: $fullName)
                        .textContentType(.name)
                    TextField("E-postadress", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }

                Section("Mandat") {
                    Picker("Roll", selection: $role) {
                        ForEach(BoardMemberRole.allCases) { role in
                            Text(role.localizedName).tag(role)
                        }
                    }
                    Toggle("Firmatecknare", isOn: $isSignatory)
                    DatePicker("Gäller från", selection: $mandateStartsAt, displayedComponents: .date)
                }

                Section {
                    TextField("Källa eller underlag", text: $sourceName)
                } header: {
                    Text("Källa")
                } footer: {
                    Text("Exempel: registreringsbevis, stämmoprotokoll eller manuellt verifierat underlag.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Ny styrelsepost")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.northBridgeBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let currentRole = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.manageBoard, for: currentRole) else {
            errorMessage = String(localized: "Din roll saknar behörighet att ändra styrelsen.")
            return
        }

        let person = PersonRecord(
            companyID: companyID,
            fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.nilIfBlank
        )
        let member = BoardMemberRecord(
            companyID: companyID,
            personID: person.id,
            role: role,
            isSignatory: isSignatory,
            mandateStartsAt: mandateStartsAt,
            sourceName: sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(person)
        modelContext.insert(member)
        modelContext.insert(
            AuditEventRecord(
                companyID: companyID,
                accountID: accountID,
                action: "board.member.created",
                entityType: "boardMember",
                entityID: member.id,
                summary: String(localized: "Styrelsepost skapades för \(person.fullName).")
            )
        )

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Styrelseposten kunde inte sparas.")
        }
    }
}

@MainActor
struct BoardMeetingEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var title = "Ordinarie styrelsemöte"
    @State private var meetingNumber = ""
    @State private var scheduledAt = Date.now.addingTimeInterval(86_400 * 7)
    @State private var location = ""
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Möte") {
                TextField("Titel", text: $title)
                    .accessibilityIdentifier("board.meeting.title")
                TextField("Mötesnummer", text: $meetingNumber)
                DatePicker("Datum och tid", selection: $scheduledAt)
                TextField("Plats eller videolänk", text: $location)
                    .accessibilityIdentifier("board.meeting.location")
                TextField("Förberedande anteckningar", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section {
                Text("Dagordning, deltagare och beslut läggs till efter att mötet har skapats.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Skapa styrelsemöte") { save() }
                    .disabled(!isValid)
                    .accessibilityIdentifier("board.meeting.save")
            }
        }
        .navigationTitle("Nytt styrelsemöte")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.northBridgeBackground)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.manageBoard, for: role) else {
            errorMessage = String(localized: "Din roll saknar behörighet att skapa styrelsemöten.")
            return
        }

        let meeting = BoardMeetingRecord(
            companyID: companyID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            meetingNumber: meetingNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            scheduledAt: scheduledAt,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .scheduled,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(meeting)
        modelContext.insert(
            AuditEventRecord(
                companyID: companyID,
                accountID: accountID,
                action: "board.meeting.created",
                entityType: "boardMeeting",
                entityID: meeting.id,
                summary: String(localized: "Styrelsemöte skapades: \(meeting.title)")
            )
        )

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Styrelsemötet kunde inte sparas.")
        }
    }
}

private enum BoardMeetingSheet: Identifiable {
    case agenda
    case resolution
    case attendee
    case action

    var id: String {
        switch self {
        case .agenda: "agenda"
        case .resolution: "resolution"
        case .attendee: "attendee"
        case .action: "action"
        }
    }
}

@MainActor
struct BoardMeetingDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query private var meetings: [BoardMeetingRecord]
    @Query(sort: \AgendaItemRecord.position) private var agendaItems: [AgendaItemRecord]
    @Query(sort: \BoardResolutionRecord.createdAt) private var resolutions: [BoardResolutionRecord]
    @Query private var attendance: [MeetingAttendanceRecord]
    @Query private var people: [PersonRecord]
    @Query private var companies: [CompanyRecord]
    @Query private var documents: [DocumentRecord]
    @Query private var documentVersions: [DocumentVersionRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    let meetingID: UUID

    @State private var presentedSheet: BoardMeetingSheet?
    @State private var exportedFileURL: URL?
    @State private var errorMessage: String?

    init(meetingID: UUID) {
        self.meetingID = meetingID
        _meetings = Query(filter: #Predicate { $0.id == meetingID })
    }

    var body: some View {
        Group {
            if let meeting {
                List {
                    Section("Möte") {
                        Picker("Status", selection: statusBinding(for: meeting)) {
                            ForEach(BoardMeetingStatus.allCases) { status in
                                Text(status.localizedName).tag(status)
                            }
                        }
                        LabeledContent(
                            "Datum",
                            value: meeting.scheduledAt.formatted(date: .long, time: .shortened)
                        )
                        LabeledContent("Plats", value: meeting.location)
                        if !meeting.meetingNumber.isEmpty {
                            LabeledContent("Nummer", value: meeting.meetingNumber)
                        }
                    }

                    Section("Deltagare") {
                        if meetingAttendees.isEmpty {
                            Text("Ingen närvaro registrerad")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(meetingAttendees) { record in
                                LabeledContent(
                                    personName(for: record.personID),
                                    value: record.attendance.localizedName
                                )
                            }
                        }
                        Button("Lägg till deltagare", systemImage: "person.badge.plus") {
                            presentedSheet = .attendee
                        }
                    }

                    Section("Dagordning") {
                        ForEach(meetingAgenda) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("§ \(item.position) \(item.title)")
                                    .font(.body.weight(.semibold))
                                if !item.details.isEmpty {
                                    Text(item.details)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                        Button("Lägg till punkt", systemImage: "text.badge.plus") {
                            presentedSheet = .agenda
                        }
                    }

                    Section("Beslut") {
                        ForEach(meetingResolutions) { resolution in
                            NavigationLink(value: AppRoute.resolution(resolution.id)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(resolution.title)
                                    Text(resolution.status.localizedName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Button("Registrera beslut", systemImage: "checkmark.seal") {
                            presentedSheet = .resolution
                        }
                        .accessibilityIdentifier("board.resolution.create")
                    }

                    if !meeting.notes.isEmpty {
                        Section("Anteckningar") {
                            Text(meeting.notes)
                        }
                    }

                    Section("Protokoll") {
                        Button(
                            meeting.status == .approved ? "Exportera slutligt protokoll" : "Exportera PDF-utkast",
                            systemImage: "doc.richtext"
                        ) {
                            exportMinutes()
                        }
                        if let exportedFileURL {
                            ShareLink(item: exportedFileURL) {
                                Label("Dela senaste exporten", systemImage: "square.and.arrow.up")
                            }
                        }
                        Text(
                            meeting.status == .approved
                                ? "Exporten markeras som justerad enligt mötets status."
                                : "Exporten märks tydligt som ett utkast."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle(meeting.title)
                .navigationBarTitleDisplayMode(.inline)
                .scrollContentBackground(.hidden)
                .background(Color.northBridgeBackground)
            } else {
                EmptyStateView(
                    systemImage: "person.3.sequence",
                    title: "Mötet saknas",
                    message: "Posten kan ha tagits bort."
                )
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            if let meeting {
                switch sheet {
                case .agenda:
                    AgendaItemEditorView(meeting: meeting, nextPosition: meetingAgenda.count + 1)
                case .resolution:
                    ResolutionEditorView(meeting: meeting, agendaItems: meetingAgenda)
                case .attendee:
                    MeetingAttendeeEditorView(meeting: meeting)
                case .action:
                    ActionItemEditorView(meetingID: meeting.id, resolutionID: nil)
                }
            }
        }
        .alert("Åtgärden kunde inte slutföras", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var meeting: BoardMeetingRecord? {
        meetings.first
    }

    private var meetingAgenda: [AgendaItemRecord] {
        agendaItems.filter { $0.meetingID == meetingID }
    }

    private var meetingResolutions: [BoardResolutionRecord] {
        resolutions.filter { $0.meetingID == meetingID }
    }

    private var meetingAttendees: [MeetingAttendanceRecord] {
        attendance.filter { $0.meetingID == meetingID }
    }

    private func personName(for personID: UUID) -> String {
        people.first { $0.id == personID }?.fullName ?? String(localized: "Okänd person")
    }

    private func statusBinding(for meeting: BoardMeetingRecord) -> Binding<BoardMeetingStatus> {
        Binding(
            get: { meeting.status },
            set: { newStatus in
                guard canManageBoard else {
                    errorMessage = String(localized: "Din roll saknar behörighet att ändra mötesstatus.")
                    return
                }
                meeting.status = newStatus
                saveContext()
            }
        )
    }

    private var canManageBoard: Bool {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ) else {
            return false
        }
        return environment.permissionPolicy.allows(.manageBoard, for: role)
    }

    private func exportMinutes() {
        guard canManageBoard,
              let meeting,
              let company = companies.first(where: { $0.id == meeting.companyID }) else {
            errorMessage = String(localized: "Du saknar behörighet eller bolagsunderlag för exporten.")
            return
        }

        var generatedURL: URL?
        do {
            let input = BoardMinutesPDFInput(
                companyID: company.id,
                companyName: company.registeredName,
                organisationNumber: company.organisationNumber,
                meetingTitle: meeting.title,
                meetingNumber: meeting.meetingNumber,
                scheduledAt: meeting.scheduledAt,
                location: meeting.location,
                status: meeting.status,
                attendees: meetingAttendees.compactMap { record in
                    guard record.attendance == .present else { return nil }
                    return personName(for: record.personID)
                },
                agenda: meetingAgenda.map {
                    BoardMinutesAgendaItem(
                        position: $0.position,
                        title: $0.title,
                        details: $0.details
                    )
                },
                resolutions: meetingResolutions.map {
                    BoardMinutesResolution(
                        title: $0.title,
                        decisionText: $0.decisionText,
                        status: $0.status
                    )
                },
                notes: meeting.notes
            )
            let fileURL = try GovernancePDFExporter.exportBoardMinutes(input)
            generatedURL = fileURL
            let sourceName = String(localized: "Genererat i NorthBridge")
            _ = try GeneratedDocumentVaultService().recordPDF(
                companyID: company.id,
                title: String(localized: "Styrelseprotokoll – \(meeting.title)"),
                category: .boardMinutes,
                fileURL: fileURL,
                sourceName: sourceName,
                documents: documents,
                versions: documentVersions,
                in: modelContext
            )
            modelContext.insert(
                AuditEventRecord(
                    companyID: company.id,
                    accountID: environment.sessionController.activeSession?.accountID,
                    action: "board.minutes.exported",
                    entityType: "boardMeeting",
                    entityID: meeting.id,
                    summary: String(localized: "Styrelseprotokoll exporterades som PDF.")
                )
            )
            try modelContext.save()
            exportedFileURL = fileURL
        } catch {
            modelContext.rollback()
            if let generatedURL {
                try? FileManager.default.removeItem(at: generatedURL)
            }
            errorMessage = error.localizedDescription
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Ändringen kunde inte sparas.")
        }
    }
}

private enum BoardDraftTemplate: String, CaseIterable, Identifiable {
    case custom
    case opening
    case annualAccounts
    case dividendProposal
    case signatory
    case budget

    var id: String { rawValue }

    var title: String {
        switch self {
        case .custom: "Egen punkt"
        case .opening: "Mötets öppnande"
        case .annualAccounts: "Årsredovisning"
        case .dividendProposal: "Förslag om utdelning"
        case .signatory: "Firmateckning"
        case .budget: "Budget och likviditet"
        }
    }

    var details: String {
        switch self {
        case .custom: ""
        case .opening: "Val av ordförande och protokollförare samt fastställande av dagordning."
        case .annualAccounts: "Genomgång av årsredovisning och ställningstagande till framläggande för årsstämman."
        case .dividendProposal: "Bedömning och förslag till årsstämman. Kontrollera försiktighetsregeln och aktuellt beslutsunderlag."
        case .signatory: "Prövning av bolagets firmateckning och beslut om eventuella ändringar."
        case .budget: "Genomgång av budget, prognos och bolagets aktuella likviditet."
        }
    }
}

@MainActor
private struct AgendaItemEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memberships: [CompanyMembershipRecord]

    let meeting: BoardMeetingRecord
    let nextPosition: Int

    @State private var template: BoardDraftTemplate = .custom
    @State private var title = ""
    @State private var details = ""
    @State private var presenterName = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mall", selection: $template) {
                        ForEach(BoardDraftTemplate.allCases) { template in
                            Text(template.title).tag(template)
                        }
                    }
                    .onChange(of: template) { _, newValue in
                        guard newValue != .custom else { return }
                        title = newValue.title
                        details = newValue.details
                    }
                } header: {
                    Text("Utkaststöd")
                } footer: {
                    Text("Mallarna är redaktionellt stöd och inte juridisk rådgivning.")
                }

                Section("Dagordningspunkt") {
                    LabeledContent("Paragraf", value: nextPosition.formatted())
                    TextField("Rubrik", text: $title)
                    TextField("Underlag", text: $details, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("Föredragande", text: $presenterName)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Ny dagordningspunkt")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.northBridgeBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        guard canManage else {
            errorMessage = String(localized: "Din roll saknar behörighet att ändra dagordningen.")
            return
        }
        let item = AgendaItemRecord(
            companyID: meeting.companyID,
            meetingID: meeting.id,
            position: nextPosition,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            presenterName: presenterName.nilIfBlank
        )
        modelContext.insert(item)
        modelContext.insert(
            AuditEventRecord(
                companyID: meeting.companyID,
                accountID: environment.sessionController.activeSession?.accountID,
                action: "board.agenda.created",
                entityType: "agendaItem",
                entityID: item.id,
                summary: String(localized: "Dagordningspunkt lades till: \(item.title)")
            )
        )
        persistAndDismiss()
    }

    private var canManage: Bool {
        guard let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: meeting.companyID,
                accountID: accountID,
                memberships: memberships
              ) else { return false }
        return environment.permissionPolicy.allows(.manageBoard, for: role)
    }

    private func persistAndDismiss() {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Dagordningspunkten kunde inte sparas.")
        }
    }
}

@MainActor
private struct ResolutionEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memberships: [CompanyMembershipRecord]

    let meeting: BoardMeetingRecord
    let agendaItems: [AgendaItemRecord]

    @State private var agendaItemID: UUID?
    @State private var title = ""
    @State private var decisionText = ""
    @State private var status: ResolutionStatus = .draft
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Beslut") {
                    Picker("Dagordningspunkt", selection: $agendaItemID) {
                        Text("Ingen koppling").tag(UUID?.none)
                        ForEach(agendaItems) { item in
                            Text("§ \(item.position) \(item.title)").tag(UUID?.some(item.id))
                        }
                    }
                    TextField("Rubrik", text: $title)
                        .accessibilityIdentifier("board.resolution.title")
                    TextField("Beslutstext", text: $decisionText, axis: .vertical)
                        .lineLimit(4...12)
                        .accessibilityIdentifier("board.resolution.text")
                    Picker("Status", selection: $status) {
                        ForEach(ResolutionStatus.allCases) { status in
                            Text(status.localizedName).tag(status)
                        }
                    }
                }

                Section {
                    Text("Beslutstexten är användarens utkast och måste granskas mot mötets faktiska beslut.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Registrera beslut")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.northBridgeBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(!isValid)
                        .accessibilityIdentifier("board.resolution.save")
                }
            }
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !decisionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard canManage else {
            errorMessage = String(localized: "Din roll saknar behörighet att registrera beslut.")
            return
        }
        let resolution = BoardResolutionRecord(
            companyID: meeting.companyID,
            meetingID: meeting.id,
            agendaItemID: agendaItemID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            decisionText: decisionText.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            decidedAt: status == .adopted ? .now : nil
        )
        modelContext.insert(resolution)
        modelContext.insert(
            AuditEventRecord(
                companyID: meeting.companyID,
                accountID: environment.sessionController.activeSession?.accountID,
                action: "board.resolution.created",
                entityType: "boardResolution",
                entityID: resolution.id,
                summary: String(localized: "Styrelsebeslut registrerades: \(resolution.title)")
            )
        )
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Beslutet kunde inte sparas.")
        }
    }

    private var canManage: Bool {
        guard let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: meeting.companyID,
                accountID: accountID,
                memberships: memberships
              ) else { return false }
        return environment.permissionPolicy.allows(.manageBoard, for: role)
    }
}

@MainActor
private struct MeetingAttendeeEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memberships: [CompanyMembershipRecord]

    let meeting: BoardMeetingRecord

    @State private var fullName = ""
    @State private var attendance: AttendanceStatus = .present
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Deltagarens namn", text: $fullName)
                    .textContentType(.name)
                Picker("Närvaro", selection: $attendance) {
                    ForEach(AttendanceStatus.allCases) { status in
                        Text(status.localizedName).tag(status)
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Lägg till deltagare")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.northBridgeBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        guard canManage else {
            errorMessage = String(localized: "Din roll saknar behörighet att registrera närvaro.")
            return
        }
        let person = PersonRecord(
            companyID: meeting.companyID,
            fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let record = MeetingAttendanceRecord(
            companyID: meeting.companyID,
            meetingID: meeting.id,
            personID: person.id,
            attendance: attendance
        )
        modelContext.insert(person)
        modelContext.insert(record)
        modelContext.insert(
            AuditEventRecord(
                companyID: meeting.companyID,
                accountID: environment.sessionController.activeSession?.accountID,
                action: "board.attendance.created",
                entityType: "meetingAttendance",
                entityID: record.id,
                summary: String(localized: "Närvaro registrerades för \(person.fullName).")
            )
        )
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Deltagaren kunde inte sparas.")
        }
    }

    private var canManage: Bool {
        guard let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: meeting.companyID,
                accountID: accountID,
                memberships: memberships
              ) else { return false }
        return environment.permissionPolicy.allows(.manageBoard, for: role)
    }
}

private struct ActionEditorDestination: Identifiable {
    let id = UUID()
}

@MainActor
struct ResolutionDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query private var resolutions: [BoardResolutionRecord]
    @Query(sort: \ActionItemRecord.dueAt) private var actions: [ActionItemRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    let resolutionID: UUID
    @State private var actionEditor: ActionEditorDestination?
    @State private var errorMessage: String?

    init(resolutionID: UUID) {
        self.resolutionID = resolutionID
        _resolutions = Query(filter: #Predicate { $0.id == resolutionID })
    }

    var body: some View {
        Group {
            if let resolution {
                List {
                    Section("Beslut") {
                        Picker("Status", selection: statusBinding(for: resolution)) {
                            ForEach(ResolutionStatus.allCases) { status in
                                Text(status.localizedName).tag(status)
                            }
                        }
                        Text(resolution.decisionText)
                    }

                    Section("Uppföljning") {
                        ForEach(resolutionActions) { action in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(action.title)
                                Text("\(action.assignedTo) · \(action.dueAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("Lägg till åtgärd", systemImage: "plus.circle") {
                            actionEditor = ActionEditorDestination()
                        }
                    }
                }
                .navigationTitle(resolution.title)
                .navigationBarTitleDisplayMode(.inline)
                .scrollContentBackground(.hidden)
                .background(Color.northBridgeBackground)
                .sheet(item: $actionEditor) { _ in
                    ActionItemEditorView(
                        meetingID: resolution.meetingID,
                        resolutionID: resolution.id
                    )
                }
            } else {
                EmptyStateView(
                    systemImage: "checkmark.seal",
                    title: "Beslutet saknas",
                    message: "Posten kan ha tagits bort."
                )
            }
        }
        .alert("Ändringen kunde inte sparas", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var resolution: BoardResolutionRecord? {
        resolutions.first
    }

    private var resolutionActions: [ActionItemRecord] {
        actions.filter { $0.resolutionID == resolutionID }
    }

    private func statusBinding(for resolution: BoardResolutionRecord) -> Binding<ResolutionStatus> {
        Binding(
            get: { resolution.status },
            set: { newStatus in
                guard canManage(companyID: resolution.companyID) else {
                    errorMessage = String(localized: "Din roll saknar behörighet att ändra beslutet.")
                    return
                }
                resolution.status = newStatus
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    errorMessage = String(localized: "Beslutsstatusen kunde inte sparas.")
                }
            }
        )
    }

    private func canManage(companyID: UUID) -> Bool {
        guard let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ) else { return false }
        return environment.permissionPolicy.allows(.manageBoard, for: role)
    }
}

@MainActor
struct ActionTrackerView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActionItemRecord.dueAt) private var actions: [ActionItemRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var filter: ActionItemStatus?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if filteredActions.isEmpty {
                EmptyStateView(
                    systemImage: "checklist",
                    title: "Inga åtgärder",
                    message: "Åtgärder från styrelsebeslut visas här."
                )
            } else {
                List(filteredActions) { action in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(action.title)
                                .font(.body.weight(.semibold))
                            Spacer()
                            StatusBadge(
                                text: action.status.localizedName,
                                kind: action.status == .completed ? .positive : .neutral
                            )
                        }
                        Text(action.details)
                            .font(.subheadline)
                        Text("\(action.assignedTo) · \(action.dueAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Status", selection: statusBinding(for: action)) {
                            ForEach(ActionItemStatus.allCases) { status in
                                Text(status.localizedName).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Åtgärder")
        .scrollContentBackground(.hidden)
        .background(Color.northBridgeBackground)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Alla") { filter = nil }
                    ForEach(ActionItemStatus.allCases) { status in
                        Button(status.localizedName) { filter = status }
                    }
                } label: {
                    Label("Filtrera", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .alert("Ändringen kunde inte sparas", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var filteredActions: [ActionItemRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return actions.filter {
            $0.companyID == companyID && (filter == nil || $0.status == filter)
        }
    }

    private func statusBinding(for action: ActionItemRecord) -> Binding<ActionItemStatus> {
        Binding(
            get: { action.status },
            set: { newStatus in
                guard canManage(companyID: action.companyID) else {
                    errorMessage = String(localized: "Din roll saknar behörighet att ändra åtgärden.")
                    return
                }
                action.status = newStatus
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    errorMessage = String(localized: "Åtgärdsstatusen kunde inte sparas.")
                }
            }
        )
    }

    private func canManage(companyID: UUID) -> Bool {
        guard let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ) else { return false }
        return environment.permissionPolicy.allows(.manageBoard, for: role)
    }
}

@MainActor
private struct ActionItemEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memberships: [CompanyMembershipRecord]

    let meetingID: UUID?
    let resolutionID: UUID?

    @State private var title = ""
    @State private var details = ""
    @State private var assignedTo = ""
    @State private var dueAt = Date.now.addingTimeInterval(86_400 * 7)
    @State private var priority: DeadlinePriority = .normal
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Åtgärd") {
                    TextField("Rubrik", text: $title)
                    TextField("Beskrivning", text: $details, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("Ansvarig", text: $assignedTo)
                    DatePicker("Deadline", selection: $dueAt, displayedComponents: .date)
                    Picker("Prioritet", selection: $priority) {
                        ForEach(DeadlinePriority.allCases, id: \.self) { priority in
                            Text(priority.localizedName).tag(priority)
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Ny åtgärd")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.northBridgeBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !assignedTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.manageBoard, for: role) else {
            errorMessage = String(localized: "Din roll saknar behörighet att skapa åtgärder.")
            return
        }
        let action = ActionItemRecord(
            companyID: companyID,
            meetingID: meetingID,
            resolutionID: resolutionID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            assignedTo: assignedTo.trimmingCharacters(in: .whitespacesAndNewlines),
            dueAt: dueAt,
            priority: priority
        )
        modelContext.insert(action)
        modelContext.insert(
            AuditEventRecord(
                companyID: companyID,
                accountID: accountID,
                action: "board.action.created",
                entityType: "actionItem",
                entityID: action.id,
                summary: String(localized: "Styrelseåtgärd skapades: \(action.title)")
            )
        )
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Åtgärden kunde inte sparas.")
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
