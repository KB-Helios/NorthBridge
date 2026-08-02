import SwiftData
import SwiftUI

private enum UserManagementSheet: Identifiable {
    case invite
    case edit(UUID)

    var id: String {
        switch self {
        case .invite: "invite"
        case .edit(let id): "edit:\(id.uuidString)"
        }
    }
}

@MainActor
struct UserRoleManagementView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserAccountRecord.displayName) private var accounts: [UserAccountRecord]
    @Query(sort: \CompanyMembershipRecord.createdAt) private var memberships: [CompanyMembershipRecord]
    @Query(sort: \CompanyInvitationRecord.createdAt, order: .reverse) private var invitations: [CompanyInvitationRecord]

    @State private var presentedSheet: UserManagementSheet?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Behöriga användare") {
                ForEach(companyMemberships) { membership in
                    Button {
                        presentedSheet = .edit(membership.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(accountName(for: membership.accountID))
                                    .foregroundStyle(.primary)
                                Text(accountEmail(for: membership.accountID))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(membership.role.localizedName)
                                    .foregroundStyle(.primary)
                                Text(membership.isActive ? "Aktiv" : "Inaktiv")
                                    .font(.caption)
                                    .foregroundStyle(membership.isActive ? Color.green : Color.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }

            Section {
                if companyInvitations.isEmpty {
                    Text("Inga väntande inbjudningar")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(companyInvitations) { invitation in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(invitation.displayName)
                                    .font(.body.weight(.semibold))
                                Spacer()
                                StatusBadge(
                                    text: effectiveStatus(for: invitation).localizedName,
                                    kind: effectiveStatus(for: invitation) == .delivered ? .positive : .warning
                                )
                            }
                            Text(invitation.email)
                                .font(.subheadline)
                            Text(invitation.role.localizedName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Avbryt", role: .destructive) {
                                cancel(invitation)
                            }
                            .disabled(!canManageUsers)
                        }
                    }
                }
            } header: {
                Text("Inbjudningar")
            } footer: {
                Text("Ett sparat inbjudningsutkast ger ingen åtkomst. Leverans och godkännande kräver den konfigurerade backendens autentiseringsflöde.")
            }

            Section {
                Text("Roller kontrolleras både innan lokala mutationer och ska kontrolleras igen av backend. Minst en aktiv ägare eller administratör måste finnas kvar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Användare och roller")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.northBridgeBackground)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Inbjudan", systemImage: "person.badge.plus") {
                    presentedSheet = .invite
                }
                .disabled(!canManageUsers)
                .accessibilityIdentifier("users.invite")
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .invite:
                InvitationEditorView()
            case .edit(let membershipID):
                MembershipEditorView(membershipID: membershipID)
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

    private var companyMemberships: [CompanyMembershipRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return memberships.filter { $0.companyID == companyID }
    }

    private var companyInvitations: [CompanyInvitationRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return invitations.filter {
            $0.companyID == companyID && $0.status != .cancelled && $0.status != .accepted
        }
    }

    private var canManageUsers: Bool {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ) else {
            return false
        }
        return environment.permissionPolicy.allows(.manageUsers, for: role)
    }

    private func accountName(for accountID: UUID) -> String {
        accounts.first { $0.id == accountID }?.displayName ?? String(localized: "Okänd användare")
    }

    private func accountEmail(for accountID: UUID) -> String {
        accounts.first { $0.id == accountID }?.email ?? ""
    }

    private func effectiveStatus(
        for invitation: CompanyInvitationRecord
    ) -> InvitationStatus {
        if invitation.status == .awaitingDelivery && invitation.expiresAt <= .now {
            return .expired
        }
        return invitation.status
    }

    private func cancel(_ invitation: CompanyInvitationRecord) {
        guard canManageUsers,
              let accountID = environment.sessionController.activeSession?.accountID else {
            errorMessage = String(localized: "Din roll saknar behörighet att avbryta inbjudningar.")
            return
        }
        invitation.status = .cancelled
        modelContext.insert(
            AuditEventRecord(
                companyID: invitation.companyID,
                accountID: accountID,
                action: "membership.invitation.cancelled",
                entityType: "companyInvitation",
                entityID: invitation.id,
                summary: String(localized: "Inbjudningsutkastet till \(invitation.email) avbröts.")
            )
        )
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Inbjudningen kunde inte avbrytas.")
        }
    }
}

@MainActor
private struct InvitationEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memberships: [CompanyMembershipRecord]
    @Query private var invitations: [CompanyInvitationRecord]

    @State private var displayName = ""
    @State private var email = ""
    @State private var role: CompanyRole = .readOnlyAdvisor
    @State private var responsibilities = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Mottagare") {
                    TextField("Namn", text: $displayName)
                        .textContentType(.name)
                    TextField("E-postadress", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    Picker("Roll", selection: $role) {
                        ForEach(CompanyRole.allCases) { role in
                            Text(role.localizedName).tag(role)
                        }
                    }
                    TextField(
                        "Ansvarsområden",
                        text: $responsibilities,
                        axis: .vertical
                    )
                    .lineLimit(2...6)
                }

                Section {
                    Text("Utkastet lagras lokalt med statusen Väntar på leverans. Det ger inte åtkomst och skickas inte förrän en backend med säkert acceptansflöde är konfigurerad.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Nytt inbjudningsutkast")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.northBridgeBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara utkast") { save() }
                        .disabled(
                            displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }
            }
        }
    }

    private func save() {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let currentRole = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.manageUsers, for: currentRole) else {
            errorMessage = String(localized: "Din roll saknar behörighet att skapa inbjudningar.")
            return
        }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        do {
            try MembershipPolicy().validateInvitation(
                email: normalizedEmail,
                pendingEmails: invitations
                    .filter {
                        $0.companyID == companyID
                            && $0.status != .cancelled
                            && $0.status != .expired
                    }
                    .map(\.email)
            )
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let invitation = CompanyInvitationRecord(
            companyID: companyID,
            email: normalizedEmail,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            role: role,
            responsibilities: responsibilities.trimmingCharacters(in: .whitespacesAndNewlines),
            invitedByAccountID: accountID
        )
        modelContext.insert(invitation)
        modelContext.insert(
            AuditEventRecord(
                companyID: companyID,
                accountID: accountID,
                action: "membership.invitation.drafted",
                entityType: "companyInvitation",
                entityID: invitation.id,
                summary: String(localized: "Inbjudningsutkast skapades för \(normalizedEmail).")
            )
        )
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Inbjudningsutkastet kunde inte sparas.")
        }
    }
}

@MainActor
private struct MembershipEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var targetMemberships: [CompanyMembershipRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    let membershipID: UUID
    @State private var selectedRole: CompanyRole = .readOnlyAdvisor
    @State private var isActive = true
    @State private var didLoad = false
    @State private var errorMessage: String?

    init(membershipID: UUID) {
        self.membershipID = membershipID
        _targetMemberships = Query(filter: #Predicate { $0.id == membershipID })
    }

    var body: some View {
        NavigationStack {
            Form {
                if let membership = targetMemberships.first {
                    Section("Behörighet") {
                        Picker("Roll", selection: $selectedRole) {
                            ForEach(CompanyRole.allCases) { role in
                                Text(role.localizedName).tag(role)
                            }
                        }
                        Toggle("Aktiv behörighet", isOn: $isActive)
                    }
                    Section {
                        Text("Ändringen sparas lokalt och ska synkroniseras genom backendens behörighetskontroll när samarbete är aktiverat.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .task {
                        guard !didLoad else { return }
                        selectedRole = membership.role
                        isActive = membership.isActive
                        didLoad = true
                    }
                } else {
                    ContentUnavailableView(
                        "Behörigheten saknas",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Redigera roll")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.northBridgeBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(targetMemberships.first == nil)
                }
            }
        }
    }

    private func save() {
        guard let membership = targetMemberships.first,
              let accountID = environment.sessionController.activeSession?.accountID,
              let currentRole = ActiveCompanyAccess.role(
                companyID: membership.companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.manageUsers, for: currentRole) else {
            errorMessage = String(localized: "Din roll saknar behörighet att ändra roller.")
            return
        }

        let companyMemberships = memberships.filter {
            $0.companyID == membership.companyID
        }
        do {
            try MembershipPolicy().validateChange(
                membershipID: membership.id,
                newRole: selectedRole,
                willRemainActive: isActive,
                memberships: companyMemberships.map {
                    MembershipSnapshot(
                        id: $0.id,
                        accountID: $0.accountID,
                        role: $0.role,
                        isActive: $0.isActive
                    )
                }
            )
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        membership.role = selectedRole
        membership.isActive = isActive
        modelContext.insert(
            AuditEventRecord(
                companyID: membership.companyID,
                accountID: accountID,
                action: "membership.updated",
                entityType: "companyMembership",
                entityID: membership.id,
                summary: String(localized: "Behörighet uppdaterades till \(selectedRole.localizedName).")
            )
        )
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Behörigheten kunde inte sparas.")
        }
    }
}
