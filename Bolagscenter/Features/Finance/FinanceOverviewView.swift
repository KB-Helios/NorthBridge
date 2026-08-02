import Charts
import SwiftData
import SwiftUI

@MainActor
struct FinanceOverviewView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \FinancialMetricRecord.periodEnd)
    private var allMetrics: [FinancialMetricRecord]

    @State private var isPresentingEditor = false
    @AppStorage("northbridge.finance.defaultKPI")
    private var defaultKindRawValue = FinancialMetricKind.revenue.rawValue
    @AppStorage("northbridge.finance.defaultPeriod")
    private var defaultPeriodRawValue = FinancePeriod.yearToDate.rawValue
    @AppStorage("northbridge.finance.chartPresentation")
    private var chartPresentationRawValue = FinanceChartPresentation.line.rawValue

    var body: some View {
        NorthBridgeScreen(contentSpacing: NorthBridgeSpacing.xxl) {
            if metrics.isEmpty {
                NorthBridgeEmptyState(
                    systemImage: "chart.xyaxis.line",
                    title: "Ingen ekonomidata",
                    message: "Anslut en godkänd integration eller registrera ett värde manuellt. Manuella värden märks alltid tydligt.",
                    compact: true,
                    actionTitle: "Registrera värde",
                    action: { isPresentingEditor = true }
                )
                .accessibilityIdentifier("finance.empty")
            } else {
                kpiSelection
                currentMetricHero
                periodSelection
                trendChartCard
                recentValues
            }

            planningLink
            disclaimer
        }
        .navigationTitle("Ekonomi")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                financeMenu
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            FinancialMetricEditorView()
        }
        .task(id: availableKinds) {
            guard !availableKinds.isEmpty else { return }
            if !availableKinds.contains(where: {
                $0.rawValue == defaultKindRawValue
            }), let first = availableKinds.first {
                defaultKindRawValue = first.rawValue
            }
        }
        .animation(
            reduceMotion || !environment.presentationPreferences.enhancedMotion
                ? nil
                : .snappy(duration: 0.28),
            value: defaultKindRawValue
        )
        .animation(
            reduceMotion || !environment.presentationPreferences.enhancedMotion
                ? nil
                : .snappy(duration: 0.24),
            value: defaultPeriodRawValue
        )
    }

    private var financeMenu: some View {
        Menu {
            Button("Registrera värde", systemImage: "plus") {
                isPresentingEditor = true
            }

            NavigationLink(value: AppRoute.financialPlanning) {
                Label(
                    "Planering och prognos",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            }

            Divider()

            Picker("Standard-KPI", selection: $defaultKindRawValue) {
                ForEach(FinancialMetricKind.allCases) { kind in
                    Text(kind.localizedName).tag(kind.rawValue)
                }
            }

            Picker("Standardperiod", selection: $defaultPeriodRawValue) {
                ForEach(FinancePeriod.allCases) { period in
                    Text(period.title).tag(period.rawValue)
                }
            }

            Picker("Diagram", selection: $chartPresentationRawValue) {
                ForEach(FinanceChartPresentation.allCases) { presentation in
                    Label(presentation.title, systemImage: presentation.systemImage)
                        .tag(presentation.rawValue)
                }
            }

            Toggle(
                "Dölj finansiella värden",
                systemImage: hidesFinancialValues ? "eye.slash" : "eye",
                isOn: financialPrivacyBinding
            )
        } label: {
            Label("Ekonomiåtgärder", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("finance.menu")
    }

    private var kpiSelection: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            NorthBridgeSectionHeader(
                "Nyckeltal",
                subtitle: "Välj vilket värde du vill följa"
            )

            ScrollView(.horizontal) {
                HStack(spacing: NorthBridgeSpacing.sm) {
                    ForEach(availableKinds) { kind in
                        NorthBridgeFilterChip(
                            LocalizedStringKey(kind.localizedName),
                            systemImage: systemImage(for: kind),
                            isSelected: kind == selectedKind,
                            count: metricCount(for: kind)
                        ) {
                            defaultKindRawValue = kind.rawValue
                        }
                        .accessibilityIdentifier("finance.kpi.\(kind.rawValue)")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var currentMetricHero: some View {
        if let latest = selectedKindMetrics.last {
            VStack(alignment: .leading, spacing: NorthBridgeSpacing.lg) {
                HStack(alignment: .top, spacing: NorthBridgeSpacing.md) {
                    VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                        Text(latest.kind.localizedName)
                            .font(.headline)
                            .foregroundStyle(Color.northBridgeTextSecondary)
                        Text(
                            latest.periodEnd,
                            format: .dateTime.month(.wide).year()
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.northBridgeTextSecondary)
                    }

                    Spacer(minLength: NorthBridgeSpacing.sm)

                    NorthBridgeGlassIconButton(
                        systemImage: hidesFinancialValues
                            ? "eye.slash.fill"
                            : "eye.fill",
                        accessibilityLabel: hidesFinancialValues
                            ? "Visa finansiella värden"
                            : "Dölj finansiella värden",
                        accessibilityIdentifier: "finance.privacy"
                    ) {
                        environment.presentationPreferences.financialPrivacyBlur.toggle()
                    }
                }

                Text(
                    latest.amount,
                    format: .currency(code: latest.currencyCode)
                        .precision(.fractionLength(0...2))
                )
                .font(
                    .system(
                        dynamicTypeSize.isAccessibilitySize
                            ? .title
                            : .largeTitle,
                        design: .rounded,
                        weight: .bold
                    )
                )
                .monospacedDigit()
                .foregroundStyle(Color.northBridgeTextPrimary)
                .contentTransition(.numericText(value: latest.amount))
                .blur(radius: hidesFinancialValues ? 9 : 0)
                .accessibilityLabel(financialValueAccessibilityLabel(latest))

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: NorthBridgeSpacing.md) {
                        StatusBadge(
                            text: latest.valueState.localizedName,
                            kind: latest.valueState == .booked
                                ? .positive
                                : .warning
                        )
                        Spacer()
                        SourceFooter(
                            source: latest.sourceName,
                            updatedAt: latest.sourceUpdatedAt
                        )
                    }

                    VStack(alignment: .leading, spacing: NorthBridgeSpacing.sm) {
                        StatusBadge(
                            text: latest.valueState.localizedName,
                            kind: latest.valueState == .booked
                                ? .positive
                                : .warning
                        )
                        SourceFooter(
                            source: latest.sourceName,
                            updatedAt: latest.sourceUpdatedAt
                        )
                    }
                }

                NavigationLink(value: AppRoute.financialMetric(latest.id)) {
                    Label("Visa värdets detaljer", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(
                            maxWidth: .infinity,
                            minHeight: NorthBridgeMetrics.minimumTarget
                        )
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("finance.hero.details")
            }
            .padding(NorthBridgeSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color.northBridgeBlue.opacity(0.15),
                        Color.northBridgeRaisedSurface,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(
                    cornerRadius: NorthBridgeRadius.hero,
                    style: .continuous
                )
            )
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(Color.northBridgeBlue.opacity(0.08))
                    .padding(NorthBridgeSpacing.lg)
                    .accessibilityHidden(true)
            }
            .accessibilityIdentifier("finance.hero")
        }
    }

    private var periodSelection: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            NorthBridgeSectionHeader(
                "Period",
                subtitle: "Diagrammet utgår från senaste registrerade period"
            )

            ScrollView(.horizontal) {
                HStack(spacing: NorthBridgeSpacing.sm) {
                    ForEach(FinancePeriod.allCases) { period in
                        NorthBridgeFilterChip(
                            period.titleKey,
                            isSelected: period == selectedPeriod
                        ) {
                            defaultPeriodRawValue = period.rawValue
                        }
                        .accessibilityIdentifier("finance.period.\(period.rawValue)")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                    Text("Utveckling")
                        .font(.title3.weight(.semibold))
                    Text("\(selectedKind.localizedName) · \(selectedPeriod.title)")
                        .font(.caption)
                        .foregroundStyle(Color.northBridgeTextSecondary)
                }
                Spacer()
                Label(
                    selectedChartPresentation.title,
                    systemImage: selectedChartPresentation.systemImage
                )
                .labelStyle(.iconOnly)
                .foregroundStyle(Color.northBridgeBlue)
                .accessibilityLabel(
                    "Diagramtyp: \(selectedChartPresentation.title)"
                )
            }

            if periodMetrics.isEmpty {
                NorthBridgeEmptyState(
                    systemImage: "chart.xyaxis.line",
                    title: "Ingen data för perioden",
                    message: "Välj en längre period eller registrera ett nytt värde.",
                    compact: true
                )
            } else {
                Chart(periodMetrics) { metric in
                    switch selectedChartPresentation {
                    case .line:
                        LineMark(
                            x: .value("Period", metric.periodEnd),
                            y: .value("Belopp", metric.amount)
                        )
                        .foregroundStyle(Color.northBridgeBlue)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Period", metric.periodEnd),
                            y: .value("Belopp", metric.amount)
                        )
                        .foregroundStyle(Color.northBridgeBlue)

                    case .bars:
                        BarMark(
                            x: .value("Period", metric.periodEnd),
                            y: .value("Belopp", metric.amount)
                        )
                        .foregroundStyle(Color.northBridgeBlue)
                        .cornerRadius(5)

                    case .area:
                        AreaMark(
                            x: .value("Period", metric.periodEnd),
                            y: .value("Belopp", metric.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.northBridgeBlue.opacity(0.34),
                                    Color.northBridgeBlue.opacity(0.03),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Period", metric.periodEnd),
                            y: .value("Belopp", metric.amount)
                        )
                        .foregroundStyle(Color.northBridgeBlue)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(minHeight: 240, idealHeight: 270)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.primary.opacity(0.08))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount, format: .number.notation(.compactName))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisGridLine().foregroundStyle(.clear)
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .blur(radius: hidesFinancialValues ? 7 : 0)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Utveckling för \(selectedKind.localizedName), \(selectedPeriod.accessibilityName)"
                )
                .accessibilityValue(
                    hidesFinancialValues
                        ? String(localized: "Finansiella värden dolda")
                        : chartAccessibilitySummary
                )
                .accessibilityIdentifier("finance.chart")
            }
        }
        .padding(NorthBridgeSpacing.lg)
        .background(
            Color.northBridgeSurface,
            in: RoundedRectangle(
                cornerRadius: NorthBridgeRadius.card,
                style: .continuous
            )
        )
    }

    @ViewBuilder
    private var recentValues: some View {
        if !recentMetrics.isEmpty {
            VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
                NorthBridgeSectionHeader(
                    "Senaste värden",
                    subtitle: "Registrerade poster för valt nyckeltal"
                )

                VStack(spacing: 0) {
                    ForEach(Array(recentMetrics.enumerated()), id: \.element.id) { index, metric in
                        NavigationLink(value: AppRoute.financialMetric(metric.id)) {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: NorthBridgeSpacing.md) {
                                    recentMetricIdentity(metric)
                                    Spacer(minLength: NorthBridgeSpacing.sm)
                                    recentMetricAmount(metric)
                                }

                                VStack(alignment: .leading, spacing: NorthBridgeSpacing.sm) {
                                    recentMetricIdentity(metric)
                                    recentMetricAmount(metric)
                                }
                            }
                            .padding(.horizontal, NorthBridgeSpacing.lg)
                            .padding(.vertical, NorthBridgeSpacing.md)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)

                        if index < recentMetrics.count - 1 {
                            Divider()
                                .padding(.leading, NorthBridgeSpacing.lg)
                        }
                    }
                }
                .background(
                    Color.northBridgeSurface,
                    in: RoundedRectangle(
                        cornerRadius: NorthBridgeRadius.card,
                        style: .continuous
                    )
                )
            }
        }
    }

    private func recentMetricIdentity(
        _ metric: FinancialMetricRecord
    ) -> some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
            Text(metric.periodEnd, format: .dateTime.month(.wide).year())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.northBridgeTextPrimary)
            Text("\(metric.valueState.localizedName) · \(metric.sourceName)")
                .font(.caption)
                .foregroundStyle(Color.northBridgeTextSecondary)
                .lineLimit(2)
        }
    }

    private func recentMetricAmount(
        _ metric: FinancialMetricRecord
    ) -> some View {
        Text(
            metric.amount,
            format: .currency(code: metric.currencyCode)
                .precision(.fractionLength(0...2))
        )
        .font(.headline.monospacedDigit())
        .foregroundStyle(Color.northBridgeTextPrimary)
        .blur(radius: hidesFinancialValues ? 7 : 0)
        .accessibilityLabel(financialValueAccessibilityLabel(metric))
    }

    private var planningLink: some View {
        NavigationLink(value: AppRoute.financialPlanning) {
            NorthBridgeCommandCard(
                title: "Planering och prognos",
                detail: "Kassauthållighet, utdelning, lön, skatt, budget och prognos",
                systemImage: "chart.line.uptrend.xyaxis",
                tint: .northBridgeBlue
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("finance.planning")
    }

    private var disclaimer: some View {
        Label(
            "Värden och prognoser i NorthBridge är informationsunderlag, inte formell redovisnings- eller skatterådgivning.",
            systemImage: "info.circle"
        )
        .font(.footnote)
        .foregroundStyle(Color.northBridgeTextSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var metrics: [FinancialMetricRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return allMetrics.filter { $0.companyID == companyID }
    }

    private var hidesFinancialValues: Bool {
        environment.presentationPreferences.financialPrivacyBlur
    }

    private var financialPrivacyBinding: Binding<Bool> {
        Binding(
            get: {
                environment.presentationPreferences.financialPrivacyBlur
            },
            set: {
                environment.presentationPreferences.financialPrivacyBlur = $0
            }
        )
    }

    private var availableKinds: [FinancialMetricKind] {
        let values = Set(metrics.map(\.kindRawValue))
        return FinancialMetricKind.allCases.filter { values.contains($0.rawValue) }
    }

    private var selectedKind: FinancialMetricKind {
        let stored = FinancialMetricKind(rawValue: defaultKindRawValue)
        if let stored, availableKinds.contains(where: { $0 == stored }) {
            return stored
        }
        return availableKinds.first ?? stored ?? .revenue
    }

    private var selectedPeriod: FinancePeriod {
        FinancePeriod(rawValue: defaultPeriodRawValue) ?? .yearToDate
    }

    private var selectedChartPresentation: FinanceChartPresentation {
        FinanceChartPresentation(rawValue: chartPresentationRawValue) ?? .line
    }

    private var selectedKindMetrics: [FinancialMetricRecord] {
        metrics.filter { $0.kind == selectedKind }
    }

    private var periodMetrics: [FinancialMetricRecord] {
        guard let anchor = selectedKindMetrics.last?.periodEnd else { return [] }
        let start = selectedPeriod.startDate(relativeTo: anchor)
        return selectedKindMetrics.filter {
            $0.periodEnd >= start && $0.periodEnd <= anchor
        }
    }

    private var recentMetrics: [FinancialMetricRecord] {
        Array(selectedKindMetrics.suffix(4).reversed())
    }

    private var chartAccessibilitySummary: String {
        guard let first = periodMetrics.first, let last = periodMetrics.last else {
            return String(localized: "Ingen data")
        }
        let lowest = periodMetrics.min(by: { $0.amount < $1.amount }) ?? first
        let highest = periodMetrics.max(by: { $0.amount < $1.amount }) ?? last
        return String(
            localized: "\(periodMetrics.count) värden. Från \(first.amount.formatted(.currency(code: first.currencyCode))) till \(last.amount.formatted(.currency(code: last.currencyCode))). Lägst \(lowest.amount.formatted(.currency(code: lowest.currencyCode))) och högst \(highest.amount.formatted(.currency(code: highest.currencyCode)))."
        )
    }

    private func metricCount(for kind: FinancialMetricKind) -> Int {
        metrics.lazy.filter { $0.kind == kind }.count
    }

    private func financialValueAccessibilityLabel(
        _ metric: FinancialMetricRecord
    ) -> String {
        if hidesFinancialValues {
            return String(localized: "Finansiellt värde dolt")
        }
        return metric.amount.formatted(.currency(code: metric.currencyCode))
    }

    private func systemImage(for kind: FinancialMetricKind) -> String {
        switch kind {
        case .bankBalance, .availableLiquidity:
            "banknote"
        case .revenue:
            "arrow.up.right"
        case .expenses:
            "arrow.down.right"
        case .operatingResult:
            "chart.line.uptrend.xyaxis"
        case .accountsReceivable:
            "tray.and.arrow.down"
        case .accountsPayable:
            "tray.and.arrow.up"
        case .taxObligations, .vatPayable:
            "building.columns"
        case .grossPayroll:
            "person.2"
        }
    }
}

private enum FinancePeriod: String, CaseIterable, Identifiable {
    case oneMonth
    case threeMonths
    case yearToDate
    case oneYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .yearToDate: "YTD"
        case .oneYear: "1Å"
        }
    }

    var titleKey: LocalizedStringKey {
        LocalizedStringKey(title)
    }

    var accessibilityName: String {
        switch self {
        case .oneMonth: String(localized: "en månad")
        case .threeMonths: String(localized: "tre månader")
        case .yearToDate: String(localized: "hittills i år")
        case .oneYear: String(localized: "ett år")
        }
    }

    func startDate(relativeTo anchor: Date) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        switch self {
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: anchor)
                ?? anchor
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: anchor)
                ?? anchor
        case .yearToDate:
            let year = calendar.component(.year, from: anchor)
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1))
                ?? anchor
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: anchor)
                ?? anchor
        }
    }
}

private enum FinanceChartPresentation: String, CaseIterable, Identifiable {
    case line
    case bars
    case area

    var id: String { rawValue }

    var title: String {
        switch self {
        case .line: String(localized: "Linje")
        case .bars: String(localized: "Staplar")
        case .area: String(localized: "Yta")
        }
    }

    var systemImage: String {
        switch self {
        case .line: "chart.xyaxis.line"
        case .bars: "chart.bar"
        case .area: "chart.line.uptrend.xyaxis"
        }
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
                            .foregroundStyle(Color.northBridgeCritical)
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
