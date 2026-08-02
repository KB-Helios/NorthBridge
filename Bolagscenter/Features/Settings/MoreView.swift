import SwiftData
import SwiftUI

@MainActor
struct SettingsHubView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \UserAccountRecord.createdAt) private var accounts: [UserAccountRecord]

    var body: some View {
        @Bindable var preferences = environment.presentationPreferences

        NorthBridgeScreen(contentSpacing: NorthBridgeSpacing.xxl) {
            if let account = activeAccount {
                profileCard(account)
            }

            settingsSection("Utseende") {
                VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
                    Label("Färgtema", systemImage: "circle.lefthalf.filled")
                        .font(.subheadline.weight(.semibold))
                    Picker("Färgtema", selection: $preferences.appearance) {
                        ForEach(NorthBridgeAppearance.allCases) { appearance in
                            Label(appearance.title, systemImage: appearance.systemImage)
                                .tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.appearance")
                }
            }

            settingsSection("Rörelse och respons") {
                VStack(spacing: 0) {
                    Toggle(isOn: $preferences.enhancedMotion) {
                        NorthBridgeSettingsRow(
                            "Förstärkt rörelse",
                            subtitle: "Mjuka övergångar och visuella tillståndsbyten",
                            systemImage: "waveform.path",
                            tint: .northBridgeInformational,
                            showsChevron: false
                        )
                    }
                    .accessibilityIdentifier("settings.motion.enhanced")

                    settingsDivider

                    Toggle(isOn: $preferences.hapticsEnabled) {
                        NorthBridgeSettingsRow(
                            "Haptisk respons",
                            subtitle: "Diskret återkoppling vid val och bekräftelser",
                            systemImage: "hand.tap.fill",
                            tint: .northBridgeBlue,
                            showsChevron: false
                        )
                    }
                    .accessibilityIdentifier("settings.haptics")
                }
                .tint(.northBridgeBlue)
            }

            settingsSection("Presentation") {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
                        Label("Täthet på översikten", systemImage: "rectangle.compress.vertical")
                            .font(.subheadline.weight(.semibold))
                        Picker("Täthet på översikten", selection: $preferences.dashboardDensity) {
                            ForEach(NorthBridgeDashboardDensity.allCases) { density in
                                Text(density.title).tag(density)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.dashboardDensity")
                    }
                    .padding(.vertical, NorthBridgeSpacing.sm)

                    settingsDivider

                    Toggle(isOn: $preferences.financialPrivacyBlur) {
                        NorthBridgeSettingsRow(
                            "Dölj finansiella belopp",
                            subtitle: "Maskerar värden tills du väljer att visa dem",
                            systemImage: "eye.slash.fill",
                            tint: .northBridgeNavy,
                            showsChevron: false
                        )
                    }
                    .tint(.northBridgeBlue)
                    .accessibilityIdentifier("settings.financePrivacy")

                    settingsDivider

                    VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
                        Label("Standardvy för dokument", systemImage: "doc.text.image")
                            .font(.subheadline.weight(.semibold))
                        Picker(
                            "Standardvy för dokument",
                            selection: $preferences.documentPresentation
                        ) {
                            ForEach(NorthBridgeDocumentPresentation.allCases) { presentation in
                                Label(
                                    presentation.title,
                                    systemImage: presentation.systemImage
                                )
                                .tag(presentation)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.documents.presentation")
                    }
                    .padding(.vertical, NorthBridgeSpacing.sm)
                }
            }

            navigationSection("Arbetsyta") {
                NavigationLink(value: AppRoute.assistant) {
                    NorthBridgeSettingsRow(
                        "Bolagsassistenten",
                        subtitle: "Lokal vägledning utifrån bolagets uppgifter",
                        systemImage: "sparkles",
                        tint: .northBridgeBlue
                    )
                }

                settingsDivider

                NavigationLink(value: AppRoute.deadlines) {
                    NorthBridgeSettingsRow(
                        "Deadlinecenter",
                        subtitle: "Kommande myndighets- och bolagshändelser",
                        systemImage: "calendar.badge.clock",
                        tint: .northBridgeWarning
                    )
                }

                settingsDivider

                NavigationLink(value: AppRoute.activity) {
                    NorthBridgeSettingsRow(
                        "Aktivitetshistorik",
                        subtitle: "Spårbara händelser i arbetsytan",
                        systemImage: "clock.arrow.circlepath",
                        tint: .northBridgeInformational
                    )
                }
            }

            navigationSection("Organisation och tjänster") {
                NavigationLink(value: AppRoute.integrations) {
                    NorthBridgeSettingsRow(
                        "Integrationer",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        tint: .northBridgeBlue
                    )
                }

                settingsDivider

                NavigationLink(value: AppRoute.usersAndRoles) {
                    NorthBridgeSettingsRow(
                        "Användare och roller",
                        systemImage: "person.2.badge.gearshape",
                        tint: .northBridgeInformational
                    )
                }

                settingsDivider

                NavigationLink(value: AppRoute.notificationSettings) {
                    NorthBridgeSettingsRow(
                        "Notiser",
                        systemImage: "bell.badge",
                        tint: .northBridgeWarning
                    )
                }

                settingsDivider

                NavigationLink(value: AppRoute.subscription) {
                    NorthBridgeSettingsRow(
                        "Prenumeration",
                        systemImage: "creditcard",
                        tint: .northBridgePositive
                    )
                }

                settingsDivider

                NavigationLink(value: AppRoute.security) {
                    NorthBridgeSettingsRow(
                        "Integritet och säkerhet",
                        systemImage: "lock.shield.fill",
                        tint: .northBridgeNavy
                    )
                }

                settingsDivider

                NavigationLink(value: AppRoute.accountSettings) {
                    NorthBridgeSettingsRow(
                        "Konto och data",
                        systemImage: "person.crop.circle",
                        tint: .northBridgeBlue
                    )
                }
            }

            Label(
                "Myndighets-, bank-, bokförings-, prenumerations- och AI-integrationer aktiveras först när respektive avtal och autentiseringsuppgifter finns.",
                systemImage: "info.circle"
            )
            .font(.footnote)
            .foregroundStyle(Color.northBridgeTextSecondary)
            .padding(.horizontal, NorthBridgeSpacing.xs)
        }
        .navigationTitle("Inställningar")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("settings.hub")
    }

    private func profileCard(_ account: UserAccountRecord) -> some View {
        NavigationLink(value: AppRoute.accountSettings) {
            HStack(spacing: NorthBridgeSpacing.lg) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(.white.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                    Text(account.displayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(account.email)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.forward")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityHidden(true)
            }
            .padding(NorthBridgeSpacing.xl)
            .background {
                LinearGradient(
                    colors: [.northBridgeNavy, .northBridgeBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: NorthBridgeRadius.hero,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: NorthBridgeRadius.hero,
                    style: .continuous
                )
                .stroke(.white.opacity(0.14), lineWidth: 0.5)
            }
            .shadow(
                color: NorthBridgeElevation.floating.color,
                radius: NorthBridgeElevation.floating.radius,
                x: NorthBridgeElevation.floating.x,
                y: NorthBridgeElevation.floating.y
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profil, \(account.displayName), \(account.email)")
        .accessibilityHint("Öppnar konto och data")
    }

    private func settingsSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            NorthBridgeSectionHeader(title)
            content()
                .padding(.horizontal, NorthBridgeSpacing.lg)
                .padding(.vertical, NorthBridgeSpacing.md)
                .northBridgeCardSurface()
        }
    }

    private func navigationSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        settingsSection(title) {
            VStack(spacing: 0) {
                content()
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsDivider: some View {
        Divider()
            .overlay(Color.northBridgeHairline)
            .padding(.leading, 46)
    }

    private var activeAccount: UserAccountRecord? {
        guard let accountID = environment.sessionController.activeSession?.accountID else {
            return nil
        }
        return accounts.first { $0.id == accountID }
    }
}

typealias MoreView = SettingsHubView

@MainActor
struct SecuritySettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @State private var showsSensitiveWidgetData = false

    var body: some View {
        @Bindable var lockController = environment.lockController

        Form {
            Section {
                Toggle(isOn: $lockController.isEnabled) {
                    Label("Face ID eller enhetskod", systemImage: "faceid")
                }
            } header: {
                Text("Appskydd")
            } footer: {
                Text("När appskydd är aktiverat låses NorthBridge automatiskt i bakgrunden.")
            }

            Section("Loggning") {
                Label("Känsliga identifierare maskeras i tekniska loggar.", systemImage: "eye.slash")
                    .font(.footnote)
            }

            Section {
                Toggle(
                    "Visa bolagsdetaljer i widgetar",
                    isOn: Binding(
                        get: { showsSensitiveWidgetData },
                        set: { updateWidgetPrivacy($0) }
                    )
                )
            } header: {
                Text("Widgetintegritet")
            } footer: {
                Text("Av som standard. När detta aktiveras får deadline, datum och likviditetsbelopp skrivas till den skyddade appgruppen. Widgetinnehållet markeras fortfarande som integritetskänsligt.")
            }
        }
        .navigationTitle("Integritet och säkerhet")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.northBridgeBackground)
        .task {
            showsSensitiveWidgetData = WidgetPrivacyPreference.showsSensitiveData
        }
    }

    private func updateWidgetPrivacy(_ newValue: Bool) {
        showsSensitiveWidgetData = newValue
        WidgetPrivacyPreference.showsSensitiveData = newValue
        if let companyID = environment.selectedCompanyID {
            WidgetSnapshotCoordinator.refresh(
                companyID: companyID,
                modelContext: modelContext
            )
        }
    }
}
