import AppIntents
import Foundation

enum IntentHandoffDestination: String, Sendable {
    case deadlines
    case createDeadline
    case openCompany
    case createBoardMeeting
    case scanDocument
    case addAction
    case assistant
}

enum IntentHandoffStore {
    private static let suiteName = "group.com.kbhelios.northbridge"
    private static let destinationKey = "intent.pendingDestination"

    static func write(_ destination: IntentHandoffDestination) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw IntentHandoffError.appGroupUnavailable
        }
        defaults.set(destination.rawValue, forKey: destinationKey)
    }

    static func consume() -> IntentHandoffDestination? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let rawValue = defaults.string(forKey: destinationKey),
              let destination = IntentHandoffDestination(rawValue: rawValue) else {
            return nil
        }
        defaults.removeObject(forKey: destinationKey)
        return destination
    }
}

enum IntentHandoffError: LocalizedError {
    case appGroupUnavailable

    var errorDescription: String? {
        "NorthBridge kunde inte öppna den valda åtgärden."
    }
}

struct ShowDeadlinesIntent: AppIntent {
    static let title: LocalizedStringResource = "Visa deadlines"
    static let description = IntentDescription("Öppnar deadlinecentret i NorthBridge.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        try IntentHandoffStore.write(.deadlines)
        return .result()
    }
}

struct CreateDeadlineIntent: AppIntent {
    static let title: LocalizedStringResource = "Skapa deadline"
    static let description = IntentDescription("Öppnar formuläret för en ny deadline i NorthBridge.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        try IntentHandoffStore.write(.createDeadline)
        return .result()
    }
}

struct OpenCompanyIntent: AppIntent {
    static let title: LocalizedStringResource = "Öppna bolag"
    static let description = IntentDescription("Öppnar det senast valda behöriga bolaget i NorthBridge.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        try IntentHandoffStore.write(.openCompany)
        return .result()
    }
}

struct CreateBoardMeetingIntent: AppIntent {
    static let title: LocalizedStringResource = "Skapa styrelsemöte"
    static let description = IntentDescription("Öppnar formuläret för ett nytt styrelsemöte.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        try IntentHandoffStore.write(.createBoardMeeting)
        return .result()
    }
}

struct ScanCompanyDocumentIntent: AppIntent {
    static let title: LocalizedStringResource = "Skanna bolagsdokument"
    static let description = IntentDescription("Öppnar den inbyggda dokumentskannern.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        try IntentHandoffStore.write(.scanDocument)
        return .result()
    }
}

struct AddActionIntent: AppIntent {
    static let title: LocalizedStringResource = "Lägg till åtgärd"
    static let description = IntentDescription("Öppnar styrelsens åtgärdslista.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        try IntentHandoffStore.write(.addAction)
        return .result()
    }
}

struct AskBolagsassistentenIntent: AppIntent {
    static let title: LocalizedStringResource = "Fråga Bolagsassistenten"
    static let description = IntentDescription("Öppnar den lokala, källgrundade Bolagsassistenten.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        try IntentHandoffStore.write(.assistant)
        return .result()
    }
}

struct BolagscenterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowDeadlinesIntent(),
            phrases: [
                "Visa deadlines i \(.applicationName)",
                "Vad är nästa deadline i \(.applicationName)"
            ],
            shortTitle: "Visa deadlines",
            systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: CreateDeadlineIntent(),
            phrases: [
                "Skapa en deadline i \(.applicationName)"
            ],
            shortTitle: "Skapa deadline",
            systemImageName: "calendar.badge.plus"
        )
        AppShortcut(
            intent: OpenCompanyIntent(),
            phrases: [
                "Öppna mitt bolag i \(.applicationName)"
            ],
            shortTitle: "Öppna bolag",
            systemImageName: "building.2"
        )
        AppShortcut(
            intent: CreateBoardMeetingIntent(),
            phrases: [
                "Skapa styrelsemöte i \(.applicationName)"
            ],
            shortTitle: "Nytt styrelsemöte",
            systemImageName: "person.3.sequence"
        )
        AppShortcut(
            intent: ScanCompanyDocumentIntent(),
            phrases: [
                "Skanna bolagsdokument i \(.applicationName)"
            ],
            shortTitle: "Skanna dokument",
            systemImageName: "doc.viewfinder"
        )
        AppShortcut(
            intent: AddActionIntent(),
            phrases: [
                "Lägg till åtgärd i \(.applicationName)"
            ],
            shortTitle: "Lägg till åtgärd",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: AskBolagsassistentenIntent(),
            phrases: [
                "Fråga \(.applicationName) om mitt bolag"
            ],
            shortTitle: "Fråga assistenten",
            systemImageName: "sparkles"
        )
    }

    static var shortcutTileColor: ShortcutTileColor { .navy }
}
