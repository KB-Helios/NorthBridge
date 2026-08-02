import SwiftData
import SwiftUI

@MainActor
struct ActivityHistoryView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \AuditEventRecord.occurredAt, order: .reverse) private var events: [AuditEventRecord]

    @State private var selectedCategory: ActivityCategory = .all
    @State private var showsRoutineSystemEvents = false

    var body: some View {
        let currentEvents = visibleEvents

        NorthBridgeScreen {
            activitySummary
            filterBar

            if currentEvents.isEmpty {
                NorthBridgeEmptyState(
                    systemImage: selectedCategory == .all
                        ? "checkmark.circle"
                        : selectedCategory.systemImage,
                    title: selectedCategory == .all
                        ? "Lugnt i aktivitetsflödet"
                        : "Ingen aktivitet i filtret",
                    message: selectedCategory == .all
                        ? "Nya verifierbara händelser visas här när bolagets uppgifter ändras."
                        : "Välj Alla för att se hela bolagets historik.",
                    compact: true,
                    actionTitle: selectedCategory == .all ? nil : "Visa alla",
                    action: selectedCategory == .all ? nil : { selectedCategory = .all }
                )
            } else {
                timeline(groupedEvents(from: currentEvents))
            }

            if hiddenRoutineEventCount > 0, !showsRoutineSystemEvents {
                Button {
                    withAnimation(selectionAnimation) {
                        showsRoutineSystemEvents = true
                    }
                } label: {
                    Label(
                        "Visa \(hiddenRoutineEventCount) rutinmässiga systemhändelser",
                        systemImage: "ellipsis.circle"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Aktivitet")
        .accessibilityIdentifier("activity.timeline.root")
    }

    private var activitySummary: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.northBridgeBlue.opacity(0.14))
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.northBridgeBlue)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text("Bolagets händelsekedja")
                    .font(.title3.weight(.semibold))
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(ActivityCategory.allCases) { category in
                    NorthBridgeFilterChip(
                        category.title,
                        systemImage: category == .all ? nil : category.systemImage,
                        isSelected: selectedCategory == category,
                        count: category == .all ? companyEvents.count : count(for: category)
                    ) {
                        withAnimation(selectionAnimation) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("activity.timeline.filters")
    }

    private func timeline(_ groups: [ActivityDayGroup]) -> some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 12) {
                    Text(group.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: 0) {
                        ForEach(group.events) { event in
                            let category = ActivityCategory.category(for: event)
                            NorthBridgeTimelineRow(
                                systemImage: category.systemImage,
                                tint: category.tint,
                                title: event.summary,
                                detail: category.eventLabel,
                                timestamp: event.occurredAt.formatted(date: .omitted, time: .shortened),
                                isLast: event.id == group.events.last?.id
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
        }
    }

    private var companyEvents: [AuditEventRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return events.filter { $0.companyID == companyID }
    }

    private var selectionAnimation: Animation? {
        reduceMotion || !environment.presentationPreferences.enhancedMotion
            ? nil
            : NorthBridgeMotion.selection
    }

    private var filteredEvents: [AuditEventRecord] {
        companyEvents.filter { event in
            selectedCategory == .all || ActivityCategory.category(for: event) == selectedCategory
        }
    }

    private var visibleEvents: [AuditEventRecord] {
        guard !showsRoutineSystemEvents else { return filteredEvents }
        return filteredEvents.filter { !isRoutineSystemEvent($0) }
    }

    private var hiddenRoutineEventCount: Int {
        filteredEvents.lazy.filter(isRoutineSystemEvent).count
    }

    private func groupedEvents(
        from currentEvents: [AuditEventRecord]
    ) -> [ActivityDayGroup] {
        let calendar = Calendar.autoupdatingCurrent
        let groups = Dictionary(grouping: currentEvents) {
            calendar.startOfDay(for: $0.occurredAt)
        }
        return groups
            .map { date, events in
                ActivityDayGroup(
                    date: date,
                    title: dayTitle(for: date, calendar: calendar),
                    events: events.sorted { $0.occurredAt > $1.occurredAt }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private var summaryText: String {
        guard let latest = companyEvents.first?.occurredAt else {
            return String(localized: "Historiken är tom och bolagets läge är lugnt.")
        }
        return String(
            localized: "\(companyEvents.count) händelser · senast \(latest.formatted(date: .abbreviated, time: .shortened))"
        )
    }

    private func count(for category: ActivityCategory) -> Int {
        companyEvents.lazy.filter { ActivityCategory.category(for: $0) == category }.count
    }

    private func dayTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) {
            return String(localized: "I dag")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "I går")
        }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func isRoutineSystemEvent(_ event: AuditEventRecord) -> Bool {
        guard ActivityCategory.category(for: event) == .system else { return false }
        let action = event.action.lowercased()
        return action.contains("sync")
            || action.contains("refresh")
            || action.contains("session")
            || action.contains("notification")
    }
}

private struct ActivityDayGroup: Identifiable {
    let date: Date
    let title: String
    let events: [AuditEventRecord]

    var id: Date { date }
}

private enum ActivityCategory: String, CaseIterable, Identifiable {
    case all
    case company
    case documents
    case governance
    case finance
    case system

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: "Alla"
        case .company: "Bolag"
        case .documents: "Dokument"
        case .governance: "Styrning"
        case .finance: "Ekonomi"
        case .system: "System"
        }
    }

    var eventLabel: String {
        switch self {
        case .all: String(localized: "Aktivitet")
        case .company: String(localized: "Bolag")
        case .documents: String(localized: "Dokument")
        case .governance: String(localized: "Styrning")
        case .finance: String(localized: "Ekonomi")
        case .system: String(localized: "System")
        }
    }

    var systemImage: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .company: "building.2"
        case .documents: "doc.text"
        case .governance: "person.3.sequence"
        case .finance: "chart.xyaxis.line"
        case .system: "gearshape.2"
        }
    }

    var tint: Color {
        switch self {
        case .all: .northBridgeBlue
        case .company: .northBridgeBlue
        case .documents: .cyan
        case .governance: .indigo
        case .finance: .green
        case .system: .gray
        }
    }

    static func category(for event: AuditEventRecord) -> ActivityCategory {
        let haystack = "\(event.entityType).\(event.action)".lowercased()

        if haystack.contains("document") {
            return .documents
        }
        if haystack.contains("financial")
            || haystack.contains("finance")
            || haystack.contains("metric")
            || haystack.contains("forecast")
            || haystack.contains("budget") {
            return .finance
        }
        if haystack.contains("board")
            || haystack.contains("resolution")
            || haystack.contains("share")
            || haystack.contains("owner")
            || haystack.contains("meeting")
            || haystack.contains("signator")
            || haystack.contains("membership")
            || haystack.contains("invitation") {
            return .governance
        }
        if haystack.contains("company")
            || haystack.contains("profile")
            || haystack.contains("deadline") {
            return .company
        }
        return .system
    }
}
