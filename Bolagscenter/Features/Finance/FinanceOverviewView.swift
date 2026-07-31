import Charts
import SwiftData
import SwiftUI

@MainActor
struct FinanceOverviewView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \FinancialMetricRecord.periodEnd) private var allMetrics: [FinancialMetricRecord]
    @State private var isPresentingEditor = false
    @State private var selectedKind: FinancialMetricKind = .revenue

    var body: some View {
        ScrollView {
            LiquidGlassEffectGroup(spacing: AppSpacing.section) {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    if metrics.isEmpty {
                        EmptyStateView(
                            systemImage: "chart.xyaxis.line",
                            title: "Ingen ekonomidata",
                            message: "Anslut en godkänd integration eller registrera ett värde manuellt. Manuella värden märks alltid tydligt.",
                            actionTitle: "Registrera värde",
                            action: { isPresentingEditor = true }
                        )
                        .frame(minHeight: 420)
                    } else {
                        metricPicker
                        currentMetricSummary
                        trendChart
                    }
                    planningLink
                    disclaimer
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Ekonomi")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Registrera värde", systemImage: "plus") {
                        isPresentingEditor = true
                    }
                    NavigationLink(value: AppRoute.financialPlanning) {
                        Label("Planering och prognos", systemImage: "chart.line.uptrend.xyaxis")
                    }
                } label: {
                    Label("Ekonomiåtgärder", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            FinancialMetricEditorView()
        }
        .task(id: availableKinds) {
            if !availableKinds.contains(selectedKind), let first = availableKinds.first {
                selectedKind = first
            }
        }
    }

    private var metricPicker: some View {
        Picker("Mätvärde", selection: $selectedKind) {
            ForEach(availableKinds) { kind in
                Text(kind.localizedName).tag(kind)
            }
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var currentMetricSummary: some View {
        if let latest = selectedMetrics.last {
            NavigationLink(value: AppRoute.financialMetric(latest.id)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(latest.kind.localizedName)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    Text(latest.amount, format: .currency(code: latest.currencyCode))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                    HStack {
                        StatusBadge(text: latest.valueState.localizedName, kind: latest.valueState == .booked ? .positive : .warning)
                        Spacer()
                        Text(latest.periodEnd, format: .dateTime.month().year())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    SourceFooter(source: latest.sourceName, updatedAt: latest.sourceUpdatedAt)
                }
                .padding(18)
                .bolagscenterGlassSurface(
                    cornerRadius: 18,
                    tint: Color.bolagscenterBlue.opacity(0.06),
                    interactive: true
                )
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
        }
    }

    private var planningLink: some View {
        NavigationLink(value: AppRoute.financialPlanning) {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Planering och prognos")
                        .font(.headline)
                    Text("Kassauthållighet, utdelning, lön, skatt, budget och prognos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .bolagscenterGlassSurface(
                cornerRadius: 18,
                interactive: true
            )
        }
        .buttonStyle(.plain)
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Utveckling")
            Chart(selectedMetrics) { metric in
                LineMark(
                    x: .value("Period", metric.periodEnd),
                    y: .value("Belopp", metric.amount)
                )
                .foregroundStyle(Color.bolagscenterBlue)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Period", metric.periodEnd),
                    y: .value("Belopp", metric.amount)
                )
                .foregroundStyle(Color.bolagscenterBlue)
            }
            .frame(height: 240)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .accessibilityLabel("Utveckling för \(selectedKind.localizedName)")
            .accessibilityValue(chartAccessibilitySummary)
        }
    }

    private var disclaimer: some View {
        Label(
            "Värden och prognoser i NorthBridge är informationsunderlag, inte formell redovisnings- eller skatterådgivning.",
            systemImage: "info.circle"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var metrics: [FinancialMetricRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return allMetrics.filter { $0.companyID == companyID }
    }

    private var availableKinds: [FinancialMetricKind] {
        let values = Set(metrics.map(\.kindRawValue))
        return FinancialMetricKind.allCases.filter { values.contains($0.rawValue) }
    }

    private var selectedMetrics: [FinancialMetricRecord] {
        metrics.filter { $0.kind == selectedKind }
    }

    private var chartAccessibilitySummary: String {
        guard let first = selectedMetrics.first, let last = selectedMetrics.last else {
            return String(localized: "Ingen data")
        }
        return String(
            localized: "Från \(first.amount.formatted(.currency(code: first.currencyCode))) till \(last.amount.formatted(.currency(code: last.currencyCode)))."
        )
    }
}

@MainActor
private struct FinancialMetricEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var kind: FinancialMetricKind = .revenue
    @State private var amount = 0.0
    @State private var currencyCode = "SEK"
    @State private var periodStart = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var periodEnd = Date.now
    @State private var sourceName = ""
    @State private var valueState: FinancialValueState = .manuallyEntered
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Värde") {
                    Picker("Mätvärde", selection: $kind) {
                        ForEach(FinancialMetricKind.allCases) { kind in
                            Text(kind.localizedName).tag(kind)
                        }
                    }
                    TextField("Belopp", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Valuta", selection: $currencyCode) {
                        Text("SEK").tag("SEK")
                        Text("EUR").tag("EUR")
                        Text("USD").tag("USD")
                    }
                    Picker("Status", selection: $valueState) {
                        ForEach(FinancialValueState.allCases) { state in
                            Text(state.localizedName).tag(state)
                        }
                    }
                }

                Section("Period och källa") {
                    DatePicker("Från", selection: $periodStart, displayedComponents: .date)
                    DatePicker("Till", selection: $periodEnd, in: periodStart..., displayedComponents: .date)
                    TextField("Källa eller underlag", text: $sourceName)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Registrera ekonomivärde")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let companyID = environment.selectedCompanyID,
              let membership = memberships.first(where: { $0.companyID == companyID && $0.isActive }),
              environment.permissionPolicy.allows(.manageFinance, for: membership.role) else {
            errorMessage = String(localized: "Din roll saknar behörighet till ekonomidata.")
            return
        }

        let metric = FinancialMetricRecord(
            companyID: companyID,
            kind: kind,
            amount: amount,
            currencyCode: currencyCode,
            periodStart: periodStart,
            periodEnd: periodEnd,
            sourceName: sourceName.trimmingCharacters(in: .whitespacesAndNewlines),
            valueState: valueState
        )
        let audit = AuditEventRecord(
            companyID: companyID,
            accountID: environment.sessionController.activeSession?.accountID,
            action: "financialMetric.created",
            entityType: "financialMetric",
            entityID: metric.id,
            summary: String(localized: "Ekonomivärde registrerades: \(metric.kind.localizedName)")
        )
        modelContext.insert(metric)
        modelContext.insert(audit)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Värdet kunde inte sparas.")
        }
    }
}
