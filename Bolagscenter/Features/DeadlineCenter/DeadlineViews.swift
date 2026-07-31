import SwiftData
import SwiftUI

struct DeadlineRow: View {
    let deadline: DeadlineRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(deadline.dueAt, format: .dateTime.day())
                    .font(.title3.bold().monospacedDigit())
                Text(deadline.dueAt, format: .dateTime.month(.abbreviated))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(deadline.title)
                    .font(.body.weight(.semibold))
                HStack(spacing: 6) {
                    Text(deadline.priority.localizedName)
                    if let responsible = deadline.responsibleName, !responsible.isEmpty {
                        Text("·")
                        Text(responsible)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

@MainActor
struct DeadlineCenterView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \DeadlineRecord.dueAt) private var deadlines: [DeadlineRecord]
    @State private var filter: Filter = .open
    @State private var showsRuleGenerator = false

    private enum Filter: String, CaseIterable, Identifiable {
        case open
        case completed
        case all

        var id: String { rawValue }
        var title: String {
            switch self {
            case .open: "Öppna"
            case .completed: "Klara"
            case .all: "Alla"
            }
        }
    }

    var body: some View {
        Group {
            if filteredDeadlines.isEmpty {
                EmptyStateView(
                    systemImage: "calendar",
                    title: "Inga deadlines",
                    message: "Skapa en deadline för att fördela ansvar och följa upp arbetet.",
                    actionTitle: "Lägg till deadline",
                    action: { router.navigate(to: .addDeadline) }
                )
            } else {
                List(filteredDeadlines) { deadline in
                    NavigationLink(value: AppRoute.deadline(deadline.id)) {
                        DeadlineRow(deadline: deadline)
                    }
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Deadlines")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Lägg till", systemImage: "plus") {
                    Button(
                        "Manuell deadline",
                        systemImage: "square.and.pencil"
                    ) {
                        router.navigate(to: .addDeadline)
                    }
                    Button(
                        "Skapa från regelverk",
                        systemImage: "calendar.badge.plus"
                    ) {
                        showsRuleGenerator = true
                    }
                }
            }
        }
        .sheet(isPresented: $showsRuleGenerator) {
            DeadlineRuleGeneratorView()
        }
    }

    private var filteredDeadlines: [DeadlineRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return deadlines.filter { deadline in
            guard deadline.companyID == companyID else { return false }
            switch filter {
            case .open:
                return deadline.status != .completed && deadline.status != .dismissed
            case .completed:
                return deadline.status == .completed
            case .all:
                return true
            }
        }
    }

    private var router: RouterPath {
        environment.router(for: environment.selectedTab)
    }
}

@MainActor
private struct DeadlineRuleGeneratorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var deadlines: [DeadlineRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var financialYearEnd = Date.now
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Räkenskapsårets slut",
                        selection: $financialYearEnd,
                        displayedComponents: .date
                    )
                } header: {
                    Text("Beräkningsunderlag")
                } footer: {
                    Text("Kontrollera datumet mot bolagets registrerade räkenskapsår innan du sparar.")
                }

                Section {
                    if generatedDrafts.isEmpty {
                        Text("Alla matchande regler finns redan för den valda perioden.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(
                            generatedDrafts,
                            id: \.ruleIdentifier
                        ) { draft in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(draft.title)
                                    .font(.body.weight(.semibold))
                                Text(
                                    draft.dueAt,
                                    format: .dateTime
                                        .day()
                                        .month(.wide)
                                        .year()
                                )
                                Text(draft.details)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Text("Version \(draft.ruleVersion)")
                                    Spacer()
                                    Link(
                                        "Källa",
                                        destination: draft.sourceURL
                                    )
                                }
                                .font(.caption.weight(.semibold))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Förhandsgranskning")
                } footer: {
                    Text("Reglerna är källhänvisad planeringshjälp. NorthBridge garanterar inte juridisk efterlevnad.")
                }

                if let errorMessage {
                    Section {
                        Label(
                            errorMessage,
                            systemImage: "exclamationmark.circle.fill"
                        )
                        .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(
                                "Skapa \(generatedDrafts.count) deadlines"
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(generatedDrafts.isEmpty || isSaving)
                }
            }
            .navigationTitle("Deadlineregler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private var companyID: UUID? {
        environment.selectedCompanyID
    }

    private var existingRuleKeys: Set<String> {
        guard let companyID else { return [] }
        return Set(
            deadlines
                .filter { $0.companyID == companyID }
                .compactMap { deadline in
                    guard let identifier = deadline.ruleIdentifier else {
                        return nil
                    }
                    return DeadlineRuleEngine.ruleKey(
                        identifier: identifier,
                        dueAt: deadline.dueAt
                    )
                }
        )
    }

    private var generatedDrafts: [GeneratedDeadlineDraft] {
        (try? DeadlineRuleEngine().generate(
            financialYearEnd: financialYearEnd,
            existingRuleKeys: existingRuleKeys
        )) ?? []
    }

    private func save() {
        guard let companyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.manageDeadlines, for: role) else {
            errorMessage = String(
                localized: "Din roll saknar behörighet att skapa deadlines."
            )
            return
        }
        let drafts: [GeneratedDeadlineDraft]
        do {
            drafts = try DeadlineRuleEngine().generate(
                financialYearEnd: financialYearEnd,
                existingRuleKeys: existingRuleKeys
            )
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        guard !drafts.isEmpty else { return }

        isSaving = true
        defer { isSaving = false }
        for draft in drafts {
            let deadline = DeadlineRecord(
                companyID: companyID,
                title: draft.title,
                dueAt: draft.dueAt,
                details: draft.details,
                priority: draft.priority,
                sourceName: draft.sourceName,
                sourceURL: draft.sourceURL.absoluteString,
                ruleIdentifier: draft.ruleIdentifier,
                ruleVersion: draft.ruleVersion,
                ruleEffectiveAt: draft.ruleEffectiveAt
            )
            modelContext.insert(deadline)
            modelContext.insert(
                DeadlineActionEventRecord(
                    companyID: companyID,
                    deadlineID: deadline.id,
                    accountID: accountID,
                    kind: .created,
                    details: String(
                        localized: "Deadline skapades från regel \(draft.ruleIdentifier), version \(draft.ruleVersion)."
                    )
                )
            )
            modelContext.insert(
                AuditEventRecord(
                    companyID: companyID,
                    accountID: accountID,
                    action: "deadline.rule.generated",
                    entityType: "deadline",
                    entityID: deadline.id,
                    summary: String(
                        localized: "Deadline skapades från \(draft.sourceName)."
                    )
                )
            )
        }

        do {
            try modelContext.save()
            WidgetSnapshotCoordinator.refresh(
                companyID: companyID,
                modelContext: modelContext
            )
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(
                localized: "Deadlinerna kunde inte sparas."
            )
        }
    }
}

@MainActor
struct DeadlineDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query private var deadlines: [DeadlineRecord]
    @Query private var supportingDocuments: [DeadlineSupportingDocumentRecord]
    @Query private var reminders: [DeadlineReminderRecord]
    @Query(sort: \DeadlineActionEventRecord.occurredAt, order: .reverse)
    private var actionEvents: [DeadlineActionEventRecord]
    @Query(sort: \DocumentRecord.title) private var documents: [DocumentRecord]
    @Query private var memberships: [CompanyMembershipRecord]
    @Query private var notificationPreferences: [NotificationPreferenceRecord]

    let deadlineID: UUID
    @State private var noteText = ""
    @State private var errorMessage: String?

    init(deadlineID: UUID) {
        self.deadlineID = deadlineID
        _deadlines = Query(filter: #Predicate { $0.id == deadlineID })
    }

    var body: some View {
        Group {
            if let deadline = deadlines.first {
                List {
                    Section("Status") {
                        Picker(
                            "Status",
                            selection: Binding(
                                get: { deadline.status },
                                set: { updateStatus($0, deadline: deadline) }
                            )
                        ) {
                            ForEach(DeadlineStatus.allCases, id: \.self) { status in
                                Text(status.localizedName).tag(status)
                            }
                        }
                        .disabled(!canManage(deadline.companyID))
                    }

                    Section("Detaljer") {
                        LabeledContent(
                            "Datum",
                            value: deadline.dueAt.formatted(
                                date: .long,
                                time: .omitted
                            )
                        )
                        LabeledContent(
                            "Prioritet",
                            value: deadline.priority.localizedName
                        )
                        if let responsible = deadline.responsibleName,
                           !responsible.isEmpty {
                            LabeledContent("Ansvarig", value: responsible)
                        }
                        Text(deadline.details)
                    }

                    Section {
                        if linkedSupportingDocuments.isEmpty {
                            Text("Inga stödjande dokument har bifogats.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(linkedSupportingDocuments) { document in
                                NavigationLink(
                                    value: AppRoute.document(document.id)
                                ) {
                                    Label(document.title, systemImage: "doc.text")
                                }
                                .swipeActions {
                                    if canManage(deadline.companyID) {
                                        Button(
                                            "Ta bort",
                                            systemImage: "paperclip.badge.minus",
                                            role: .destructive
                                        ) {
                                            detach(
                                                document,
                                                from: deadline
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        if canManage(deadline.companyID),
                           !availableSupportingDocuments.isEmpty {
                            Menu("Bifoga dokument", systemImage: "paperclip") {
                                ForEach(availableSupportingDocuments) { document in
                                    Button(document.title) {
                                        attach(
                                            document,
                                            to: deadline
                                        )
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Stödjande dokument")
                    } footer: {
                        if availableSupportingDocuments.isEmpty,
                           linkedSupportingDocuments.isEmpty {
                            Text("Importera först ett dokument i Dokumentvalvet.")
                        }
                    }

                    Section {
                        if let reminder {
                            Toggle(
                                "Aktiverad",
                                isOn: Binding(
                                    get: { reminder.isEnabled },
                                    set: {
                                        reminder.isEnabled = $0
                                        persistReminder(
                                            reminder,
                                            deadline: deadline
                                        )
                                    }
                                )
                            )
                            Stepper(
                                "Förvarning: \(reminder.leadTimeDays) dagar",
                                value: Binding(
                                    get: { reminder.leadTimeDays },
                                    set: {
                                        reminder.leadTimeDays = $0
                                        persistReminder(
                                            reminder,
                                            deadline: deadline
                                        )
                                    }
                                ),
                                in: 0...60
                            )
                            .disabled(!reminder.isEnabled)
                        } else if canManage(deadline.companyID) {
                            Button(
                                "Anpassa påminnelse",
                                systemImage: "bell.badge"
                            ) {
                                createReminder(for: deadline)
                            }
                        } else {
                            Text("Följer bolagets allmänna notisinställning.")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Påminnelse")
                    } footer: {
                        Text(reminderFooter)
                    }

                    if canManage(deadline.companyID) {
                        Section("Lägg till anteckning") {
                            TextField(
                                "Vad har gjorts?",
                                text: $noteText,
                                axis: .vertical
                            )
                            .lineLimit(2...5)
                            Button("Registrera i historiken", systemImage: "note.text.badge.plus") {
                                addNote(to: deadline)
                            }
                            .disabled(noteText.trimmed.isEmpty)
                        }
                    }

                    Section("Åtgärdshistorik") {
                        if deadlineEvents.isEmpty {
                            Text("Ingen åtgärdshistorik har registrerats.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(deadlineEvents) { event in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: event.kind.systemImage)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(event.kind.localizedName)
                                            .font(.subheadline.weight(.semibold))
                                        Text(event.details)
                                            .font(.subheadline)
                                        Text(
                                            event.occurredAt,
                                            format: .dateTime
                                                .day()
                                                .month()
                                                .year()
                                                .hour()
                                                .minute()
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }

                    Section("Källa") {
                        LabeledContent("Källa", value: deadline.sourceName)
                        if let sourceURL = deadline.sourceURL,
                           let url = URL(string: sourceURL) {
                            Link("Öppna källan", destination: url)
                        }
                        if let identifier = deadline.ruleIdentifier {
                            LabeledContent("Regel-ID", value: identifier)
                        }
                        if let version = deadline.ruleVersion {
                            LabeledContent("Regelversion", value: version)
                        }
                        if let effectiveAt = deadline.ruleEffectiveAt {
                            LabeledContent("Gäller från", value: effectiveAt.formatted(date: .long, time: .omitted))
                        }
                        Text("NorthBridge garanterar inte juridisk efterlevnad.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage {
                        Section {
                            Label(
                                errorMessage,
                                systemImage: "exclamationmark.circle.fill"
                            )
                            .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle(deadline.title)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                EmptyStateView(
                    systemImage: "calendar.badge.exclamationmark",
                    title: "Deadline saknas",
                    message: "Posten kan ha tagits bort."
                )
            }
        }
    }

    private var linkedSupportRecords: [DeadlineSupportingDocumentRecord] {
        supportingDocuments
            .filter { $0.deadlineID == deadlineID }
            .sorted { $0.attachedAt < $1.attachedAt }
    }

    private var linkedSupportingDocuments: [DocumentRecord] {
        let ids = Set(linkedSupportRecords.map(\.documentID))
        return documents.filter { ids.contains($0.id) }
    }

    private var availableSupportingDocuments: [DocumentRecord] {
        guard let companyID = deadlines.first?.companyID else { return [] }
        let linkedIDs = Set(linkedSupportRecords.map(\.documentID))
        return documents.filter {
            $0.companyID == companyID && !linkedIDs.contains($0.id)
        }
    }

    private var reminder: DeadlineReminderRecord? {
        reminders.first { $0.deadlineID == deadlineID }
    }

    private var deadlineEvents: [DeadlineActionEventRecord] {
        actionEvents.filter { $0.deadlineID == deadlineID }
    }

    private var deadlineNotificationPreference: NotificationPreferenceRecord? {
        guard let companyID = deadlines.first?.companyID,
              let accountID = environment.sessionController.activeSession?.accountID else {
            return nil
        }
        return notificationPreferences.first {
            $0.companyID == companyID
                && $0.accountID == accountID
                && $0.category == .deadlines
        }
    }

    private var reminderFooter: String {
        guard let preference = deadlineNotificationPreference else {
            return String(localized: "Aktivera deadline-notiser under Mer > Notiser för att schemalägga påminnelsen.")
        }
        return preference.isEnabled
            ? String(localized: "Den här inställningen ersätter standardförvarningen för just denna deadline.")
            : String(localized: "Deadline-notiser är avstängda under Mer > Notiser. Inställningen sparas men schemaläggs inte.")
    }

    private func canManage(_ companyID: UUID) -> Bool {
        guard let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ) else {
            return false
        }
        return environment.permissionPolicy.allows(.manageDeadlines, for: role)
    }

    private func updateStatus(
        _ status: DeadlineStatus,
        deadline: DeadlineRecord
    ) {
        guard canManage(deadline.companyID), status != deadline.status else {
            return
        }
        let oldStatus = deadline.status
        deadline.status = status
        insertEvent(
            deadline: deadline,
            kind: .statusChanged,
            details: String(
                localized: "Status ändrades från \(oldStatus.localizedName) till \(status.localizedName)."
            )
        )
        save(deadline: deadline)
    }

    private func createReminder(for deadline: DeadlineRecord) {
        guard canManage(deadline.companyID) else { return }
        let value = DeadlineReminderRecord(
            companyID: deadline.companyID,
            deadlineID: deadline.id
        )
        modelContext.insert(value)
        persistReminder(value, deadline: deadline)
    }

    private func persistReminder(
        _ reminder: DeadlineReminderRecord,
        deadline: DeadlineRecord
    ) {
        guard canManage(deadline.companyID) else { return }
        reminder.leadTimeDays = min(max(reminder.leadTimeDays, 0), 60)
        reminder.updatedAt = .now
        insertEvent(
            deadline: deadline,
            kind: .reminderUpdated,
            details: reminder.isEnabled
                ? String(localized: "Påminnelse sattes till \(reminder.leadTimeDays) dagar före.")
                : String(localized: "Den individuella påminnelsen stängdes av.")
        )
        save(deadline: deadline)
    }

    private func attach(
        _ document: DocumentRecord,
        to deadline: DeadlineRecord
    ) {
        guard canManage(deadline.companyID),
              document.companyID == deadline.companyID,
              !linkedSupportRecords.contains(where: {
                  $0.documentID == document.id
              }) else {
            return
        }
        modelContext.insert(
            DeadlineSupportingDocumentRecord(
                companyID: deadline.companyID,
                deadlineID: deadline.id,
                documentID: document.id,
                attachedByAccountID: activeAccountID
            )
        )
        insertEvent(
            deadline: deadline,
            kind: .documentAttached,
            details: String(localized: "Dokumentet \(document.title) bifogades.")
        )
        save(deadline: deadline)
    }

    private func detach(
        _ document: DocumentRecord,
        from deadline: DeadlineRecord
    ) {
        guard canManage(deadline.companyID),
              let record = linkedSupportRecords.first(where: {
                  $0.documentID == document.id
              }) else {
            return
        }
        modelContext.delete(record)
        insertEvent(
            deadline: deadline,
            kind: .documentRemoved,
            details: String(localized: "Dokumentet \(document.title) togs bort.")
        )
        save(deadline: deadline)
    }

    private func addNote(to deadline: DeadlineRecord) {
        guard canManage(deadline.companyID), !noteText.trimmed.isEmpty else {
            return
        }
        insertEvent(
            deadline: deadline,
            kind: .note,
            details: noteText.trimmed
        )
        noteText = ""
        save(deadline: deadline)
    }

    private var activeAccountID: UUID? {
        environment.sessionController.activeSession?.accountID
    }

    private func insertEvent(
        deadline: DeadlineRecord,
        kind: DeadlineActionEventKind,
        details: String
    ) {
        modelContext.insert(
            DeadlineActionEventRecord(
                companyID: deadline.companyID,
                deadlineID: deadline.id,
                accountID: activeAccountID,
                kind: kind,
                details: details
            )
        )
        modelContext.insert(
            AuditEventRecord(
                companyID: deadline.companyID,
                accountID: activeAccountID,
                action: "deadline.\(kind.rawValue)",
                entityType: "deadline",
                entityID: deadline.id,
                summary: details
            )
        )
    }

    private func save(deadline: DeadlineRecord) {
        do {
            try modelContext.save()
            WidgetSnapshotCoordinator.refresh(
                companyID: deadline.companyID,
                modelContext: modelContext
            )
            synchronizeReminder(for: deadline)
            errorMessage = nil
        } catch {
            modelContext.rollback()
            SecureLogger.persistence.error(
                "Deadline update failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
            errorMessage = String(localized: "Ändringen kunde inte sparas.")
        }
    }

    private func synchronizeReminder(for deadline: DeadlineRecord) {
        guard let preference = deadlineNotificationPreference else { return }
        let reminder = reminders.first { $0.deadlineID == deadline.id }
        let snapshot = DeadlineNotificationSnapshot(
            id: deadline.id,
            companyID: deadline.companyID,
            title: deadline.title,
            dueAt: deadline.dueAt,
            status: deadline.status,
            reminderIsEnabled: reminder?.isEnabled,
            reminderLeadTimeDays: reminder?.leadTimeDays
        )
        let preferenceSnapshot = NotificationPreferenceSnapshot(
            category: preference.category,
            isEnabled: preference.isEnabled,
            leadTimeDays: preference.leadTimeDays,
            showsSensitiveDetails: preference.showsSensitiveDetails
        )
        Task {
            do {
                try await environment.notificationScheduler.updateDeadline(
                    snapshot,
                    preference: preferenceSnapshot
                )
            } catch {
                errorMessage = String(
                    localized: "Ändringen sparades, men notisen kunde inte schemaläggas."
                )
            }
        }
    }
}

@MainActor
struct DeadlineEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var title = ""
    @State private var dueAt = Date.now.addingTimeInterval(86_400 * 7)
    @State private var details = ""
    @State private var responsibleName = ""
    @State private var priority: DeadlinePriority = .normal
    @State private var sourceName = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Deadline") {
                TextField("Titel", text: $title)
                    .accessibilityIdentifier("deadline.title")
                DatePicker("Datum", selection: $dueAt, displayedComponents: .date)
                Picker("Prioritet", selection: $priority) {
                    ForEach(DeadlinePriority.allCases, id: \.self) { priority in
                        Text(priority.localizedName).tag(priority)
                    }
                }
                TextField("Ansvarig", text: $responsibleName)
                TextField("Beskrivning", text: $details, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section {
                TextField("Källa eller underlag", text: $sourceName)
            } header: {
                Text("Källa")
            } footer: {
                Text("Manuella deadlines ska alltid ha ett spårbart underlag.")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Spara deadline") {
                    saveDeadline()
                }
                .disabled(!isValid)
                .accessibilityIdentifier("deadline.save")
            }
        }
        .navigationTitle("Ny deadline")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveDeadline() {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.manageDeadlines, for: role) else {
            errorMessage = String(localized: "Din roll saknar behörighet att skapa deadlines.")
            return
        }

        let deadline = DeadlineRecord(
            companyID: companyID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueAt: dueAt,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            responsibleName: responsibleName.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority,
            sourceName: sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let audit = AuditEventRecord(
            companyID: companyID,
            accountID: accountID,
            action: "deadline.created",
            entityType: "deadline",
            entityID: deadline.id,
            summary: String(localized: "Deadline skapades: \(deadline.title)")
        )
        modelContext.insert(deadline)
        modelContext.insert(audit)
        modelContext.insert(
            DeadlineActionEventRecord(
                companyID: companyID,
                deadlineID: deadline.id,
                accountID: accountID,
                kind: .created,
                details: String(localized: "Deadline skapades med status Öppen.")
            )
        )

        do {
            try modelContext.save()
            WidgetSnapshotCoordinator.refresh(companyID: companyID, modelContext: modelContext)
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Deadlinen kunde inte sparas.")
        }
    }

}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
