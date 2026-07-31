import SwiftUI
import WidgetKit

struct BolagscenterTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct BolagscenterTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BolagscenterTimelineEntry {
        BolagscenterTimelineEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (BolagscenterTimelineEntry) -> Void
    ) {
        completion(BolagscenterTimelineEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<BolagscenterTimelineEntry>) -> Void
    ) {
        let entry = BolagscenterTimelineEntry(date: .now, snapshot: WidgetSnapshotStore.load())
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct NextDeadlineWidgetView: View {
    @Environment(\.redactionReasons) private var redactionReasons
    let entry: BolagscenterTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Nästa deadline", systemImage: "calendar.badge.clock")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            if entry.snapshot.showsSensitiveData,
               let title = entry.snapshot.deadlineTitle,
               let date = entry.snapshot.deadlineDate {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .privacySensitive()
                Text(date, format: .dateTime.day().month(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .privacySensitive()
            } else if entry.snapshot.openDeadlineCount > 0 {
                Text("\(entry.snapshot.openDeadlineCount) öppna")
                    .font(.title2.bold())
                    .privacySensitive()
                Text("Aktivera detaljer i appen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(redactionReasons.isEmpty ? "Inga öppna deadlines" : "Deadline")
                    .font(.headline)
                    .redacted(reason: redactionReasons)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "northbridge://deadlines"))
    }
}

struct PendingActionsWidgetView: View {
    let entry: BolagscenterTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Åtgärder", systemImage: "checklist")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Text(entry.snapshot.openActionCount.formatted())
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .privacySensitive()
            Text(
                entry.snapshot.openActionCount == 1
                    ? "öppen styrelseåtgärd"
                    : "öppna styrelseåtgärder"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .privacySensitive()
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "northbridge://action"))
    }
}

struct CompanyPulseWidgetView: View {
    let entry: BolagscenterTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Bolagspuls", systemImage: "waveform.path.ecg")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if entry.snapshot.pulseFactors.isEmpty {
                Spacer()
                Label("Inga registrerade riskfaktorer", systemImage: "checkmark.circle")
                    .font(.headline)
                    .privacySensitive()
                Text("Inte en juridisk kontroll")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(entry.snapshot.pulseFactors.count) faktorer")
                    .font(.title3.bold())
                    .privacySensitive()
                ForEach(entry.snapshot.pulseFactors.prefix(2), id: \.self) { factor in
                    Label(factor, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .lineLimit(1)
                        .privacySensitive()
                }
                Spacer(minLength: 0)
                Text("Registrerade signaler, inte certifiering")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "northbridge://company"))
    }
}

struct AvailableLiquidityWidgetView: View {
    let entry: BolagscenterTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tillgänglig likviditet", systemImage: "banknote")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            if let amount = entry.snapshot.availableLiquidity,
               let currencyCode = entry.snapshot.liquidityCurrencyCode {
                Text(amount, format: .currency(code: currencyCode))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .privacySensitive()
                if let updatedAt = entry.snapshot.liquiditySourceUpdatedAt {
                    Text("Källa uppdaterad \(updatedAt, format: .dateTime.day().month())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .privacySensitive()
                }
            } else if entry.snapshot.showsSensitiveData {
                Text("Inget värde registrerat")
                    .font(.headline)
            } else {
                Label("Dolt", systemImage: "eye.slash")
                    .font(.title3.bold())
                Text("Aktivera detaljer i appen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "northbridge://finance"))
    }
}

struct NextDeadlineWidget: Widget {
    let kind = "NextDeadlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BolagscenterTimelineProvider()) { entry in
            NextDeadlineWidgetView(entry: entry)
        }
        .configurationDisplayName("Nästa deadline")
        .description("Visar nästa registrerade deadline. Känsligt innehåll döljs när enheten är låst.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PendingActionsWidget: Widget {
    let kind = "PendingActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BolagscenterTimelineProvider()) { entry in
            PendingActionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Väntande åtgärder")
        .description("Visar antal öppna styrelseåtgärder.")
        .supportedFamilies([.systemSmall])
    }
}

struct CompanyPulseWidget: Widget {
    let kind = "CompanyPulseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BolagscenterTimelineProvider()) { entry in
            CompanyPulseWidgetView(entry: entry)
        }
        .configurationDisplayName("Bolagspuls")
        .description("Visar förklarade lokala riskfaktorer utan att ange ett godtyckligt poängtal.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AvailableLiquidityWidget: Widget {
    let kind = "AvailableLiquidityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BolagscenterTimelineProvider()) { entry in
            AvailableLiquidityWidgetView(entry: entry)
        }
        .configurationDisplayName("Tillgänglig likviditet")
        .description("Visar senaste källmarkerade likviditetsvärde när känsliga widgetdetaljer är aktiverade.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct BolagscenterWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextDeadlineWidget()
        PendingActionsWidget()
        CompanyPulseWidget()
        AvailableLiquidityWidget()
    }
}
