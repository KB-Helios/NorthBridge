import Charts
import SwiftData
import SwiftUI

@MainActor
struct FinancialMetricDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \FinancialMetricRecord.periodEnd) private var metrics: [FinancialMetricRecord]

    let metricID: UUID

    var body: some View {
        Group {
            if let metric {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(metric.amount, format: .currency(code: metric.currencyCode))
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .contentTransition(.numericText())
                            StatusBadge(
                                text: metric.valueState.localizedName,
                                kind: metric.valueState == .booked
                                    ? .positive
                                    : .warning
                            )
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
                    }

                    Section("Period") {
                        LabeledContent(
                            "Från",
                            value: metric.periodStart.formatted(
                                date: .long,
                                time: .omitted
                            )
                        )
                        LabeledContent(
                            "Till",
                            value: metric.periodEnd.formatted(
                                date: .long,
                                time: .omitted
                            )
                        )
                        LabeledContent("Valuta", value: metric.currencyCode)
                    }

                    Section("Källa") {
                        LabeledContent("Underlag", value: metric.sourceName)
                        LabeledContent(
                            "Källan uppdaterad",
                            value: metric.sourceUpdatedAt.formatted(
                                date: .long,
                                time: .shortened
                            )
                        )
                        LabeledContent(
                            "Värdetyp",
                            value: metric.valueState.localizedName
                        )
                    }

                    comparisonSection(metric)

                    if relatedMetrics.count > 1 {
                        Section("Historik") {
                            Chart(relatedMetrics) { value in
                                LineMark(
                                    x: .value("Period", value.periodEnd),
                                    y: .value("Belopp", value.amount)
                                )
                                .foregroundStyle(Color.bolagscenterBlue)
                                PointMark(
                                    x: .value("Period", value.periodEnd),
                                    y: .value("Belopp", value.amount)
                                )
                                .foregroundStyle(Color.bolagscenterBlue)
                            }
                            .frame(height: 220)
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .accessibilityLabel(
                                "Historik för \(metric.kind.localizedName)"
                            )
                            .accessibilityValue(historyAccessibilityValue)
                        }
                    }

                    Section {
                        Label(
                            "Jämförelser är matematiska beräkningar av registrerade värden och utgör inte redovisnings- eller skatterådgivning.",
                            systemImage: "info.circle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle(metric.kind.localizedName)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                EmptyStateView(
                    systemImage: "chart.xyaxis.line",
                    title: "Mätvärdet saknas",
                    message: "Posten kan ha tagits bort eller tillhöra ett annat bolag."
                )
            }
        }
    }

    @ViewBuilder
    private func comparisonSection(
        _ metric: FinancialMetricRecord
    ) -> some View {
        Section("Föregående period") {
            if let previousMetric {
                let delta = metric.amount - previousMetric.amount
                LabeledContent(
                    "Föregående värde",
                    value: previousMetric.amount.formatted(
                        .currency(code: metric.currencyCode)
                    )
                )
                LabeledContent(
                    "Förändring",
                    value: delta.formatted(
                        .currency(code: metric.currencyCode)
                    )
                )
                if previousMetric.amount != 0 {
                    LabeledContent(
                        "Procentuell förändring",
                        value: (delta / abs(previousMetric.amount)).formatted(
                            .percent.precision(.fractionLength(1))
                        )
                    )
                } else {
                    Text("Procentuell förändring visas inte när föregående värde är noll.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                SourceFooter(
                    source: previousMetric.sourceName,
                    updatedAt: previousMetric.sourceUpdatedAt
                )
            } else {
                Text("Ingen tidigare jämförbar post finns i samma valuta.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metric: FinancialMetricRecord? {
        metrics.first {
            $0.id == metricID
                && $0.companyID == environment.selectedCompanyID
        }
    }

    private var relatedMetrics: [FinancialMetricRecord] {
        guard let metric else { return [] }
        return metrics.filter {
            $0.companyID == metric.companyID
                && $0.kind == metric.kind
                && $0.currencyCode == metric.currencyCode
        }
    }

    private var previousMetric: FinancialMetricRecord? {
        guard let metric,
              let index = relatedMetrics.firstIndex(where: { $0.id == metric.id }),
              index > relatedMetrics.startIndex else {
            return nil
        }
        return relatedMetrics[relatedMetrics.index(before: index)]
    }

    private var historyAccessibilityValue: String {
        guard let first = relatedMetrics.first,
              let last = relatedMetrics.last else {
            return String(localized: "Ingen historik")
        }
        return String(
            localized: "Från \(first.amount.formatted(.currency(code: first.currencyCode))) till \(last.amount.formatted(.currency(code: last.currencyCode)))."
        )
    }
}

@MainActor
struct FinancialPlanningView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinancialPlanRecord.updatedAt, order: .reverse) private var plans: [FinancialPlanRecord]
    @Query(sort: \FinancialMetricRecord.periodEnd, order: .reverse) private var metrics: [FinancialMetricRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var title = "Grundscenario"
    @State private var currencyCode = "SEK"
    @State private var availableCash = 0.0
    @State private var monthlyRevenue = 0.0
    @State private var monthlyCosts = 0.0
    @State private var proposedGrossSalary = 0.0
    @State private var proposedDividend = 0.0
    @State private var salaryTaxPercent = 30.0
    @State private var dividendTaxPercent = 20.0
    @State private var expectedTaxPayments = 0.0
    @State private var horizonMonths = 12
    @State private var assumptions = ""
    @State private var errorMessage: String?
    @State private var didSeed = false
    @State private var saveTrigger = 0

    private let calculator = FinancialPlanningCalculator()

    var body: some View {
        Form {
            if !companyPlans.isEmpty {
                Section("Sparade scenarier") {
                    ForEach(companyPlans) { plan in
                        Button {
                            load(plan)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.title)
                                    .foregroundStyle(.primary)
                                if let result = try? calculator.calculate(plan.input) {
                                    Text(
                                        "Prognos \(result.forecastEndingCash.formatted(.currency(code: plan.currencyCode))) efter \(plan.horizonMonths) månader"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section("Scenario") {
                TextField("Namn", text: $title)
                Picker("Valuta", selection: $currencyCode) {
                    Text("SEK").tag("SEK")
                    Text("EUR").tag("EUR")
                    Text("USD").tag("USD")
                }
                Stepper(
                    "Prognosperiod: \(horizonMonths) månader",
                    value: $horizonMonths,
                    in: 1...60
                )
                TextField(
                    "Antaganden och underlag",
                    text: $assumptions,
                    axis: .vertical
                )
                .lineLimit(2...6)
            }

            Section {
                amountField("Tillgänglig kassa", value: $availableCash)
                amountField("Månadsintäkter", value: $monthlyRevenue)
                amountField("Månadskostnader", value: $monthlyCosts)
                amountField(
                    "Förväntade skattebetalningar under perioden",
                    value: $expectedTaxPayments
                )
            } header: {
                Text("Kassauthållighet, budget och prognos")
            } footer: {
                Text("Månadsbeloppen är användarens antaganden. Förifyllda värden kommer från senaste registrerade poster och måste kontrolleras mot rätt period.")
            }

            if let result {
                Section("Beräknade estimat") {
                    LabeledContent(
                        "Månadsresultat",
                        value: result.monthlyOperatingResult.formatted(
                            .currency(code: currencyCode)
                        )
                    )
                    LabeledContent(
                        "Månatlig cash burn",
                        value: result.monthlyCashBurn.formatted(
                            .currency(code: currencyCode)
                        )
                    )
                    if let runway = result.cashRunwayMonths {
                        LabeledContent(
                            "Kassauthållighet",
                            value: "\(runway.formatted(.number.precision(.fractionLength(1)))) månader"
                        )
                    } else {
                        LabeledContent(
                            "Kassauthållighet",
                            value: "Ingen negativ burn i antagandet"
                        )
                    }
                    LabeledContent(
                        "Prognostiserad slutkassa",
                        value: result.forecastEndingCash.formatted(
                            .currency(code: currencyCode)
                        )
                    )
                }
            }

            Section {
                amountField(
                    "Föreslagen bruttolön",
                    value: $proposedGrossSalary
                )
                percentageField(
                    "Antagen skatt på lön",
                    value: $salaryTaxPercent
                )
                amountField(
                    "Föreslagen utdelning",
                    value: $proposedDividend
                )
                percentageField(
                    "Antagen skatt på utdelning",
                    value: $dividendTaxPercent
                )
            } header: {
                Text("Lön jämfört med utdelning")
            } footer: {
                Text("Skattesatserna är manuella antaganden. NorthBridge avgör inte gränsbelopp, arbetsgivaravgifter eller skattemässig behörighet.")
            }

            if let result {
                Section("Nettobelopp enligt antaganden") {
                    LabeledContent(
                        "Lön efter antagen skatt",
                        value: result.salaryNet.formatted(
                            .currency(code: currencyCode)
                        )
                    )
                    LabeledContent(
                        "Utdelning efter antagen skatt",
                        value: result.dividendNet.formatted(
                            .currency(code: currencyCode)
                        )
                    )
                }
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
                Button("Spara scenario", systemImage: "square.and.arrow.down") {
                    save()
                }
                .disabled(result == nil || title.trimmed.isEmpty)
            } footer: {
                Text("Alla resultat är estimat och utgör inte formell redovisnings-, skatte- eller investeringsrådgivning.")
            }
        }
        .navigationTitle("Planering och prognos")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            seedFromLatestMetrics()
        }
        .sensoryFeedback(.success, trigger: saveTrigger)
    }

    private var companyPlans: [FinancialPlanRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return plans.filter { $0.companyID == companyID }
    }

    private var companyMetrics: [FinancialMetricRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return metrics.filter { $0.companyID == companyID }
    }

    private var input: FinancialPlanningInput {
        FinancialPlanningInput(
            availableCash: availableCash,
            monthlyRevenue: monthlyRevenue,
            monthlyCosts: monthlyCosts,
            proposedGrossSalary: proposedGrossSalary,
            proposedDividend: proposedDividend,
            salaryTaxRate: salaryTaxPercent / 100,
            dividendTaxRate: dividendTaxPercent / 100,
            expectedTaxPayments: expectedTaxPayments,
            horizonMonths: horizonMonths
        )
    }

    private var result: FinancialPlanningResult? {
        try? calculator.calculate(input)
    }

    @ViewBuilder
    private func amountField(
        _ label: LocalizedStringKey,
        value: Binding<Double>
    ) -> some View {
        TextField(label, value: value, format: .number)
            .keyboardType(.decimalPad)
    }

    @ViewBuilder
    private func percentageField(
        _ label: LocalizedStringKey,
        value: Binding<Double>
    ) -> some View {
        LabeledContent {
            TextField("Procent", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        } label: {
            Text(label)
        }
    }

    private func latestAmount(for kinds: [FinancialMetricKind]) -> Double {
        companyMetrics.first { kinds.contains($0.kind) }?.amount ?? 0
    }

    private func seedFromLatestMetrics() {
        guard !didSeed else { return }
        didSeed = true
        availableCash = latestAmount(for: [.availableLiquidity, .bankBalance])
        monthlyRevenue = latestAmount(for: [.revenue])
        monthlyCosts = latestAmount(for: [.expenses])
        proposedGrossSalary = latestAmount(for: [.grossPayroll])
        expectedTaxPayments = latestAmount(for: [.taxObligations, .vatPayable])
    }

    private func load(_ plan: FinancialPlanRecord) {
        title = plan.title
        currencyCode = plan.currencyCode
        availableCash = plan.availableCash
        monthlyRevenue = plan.monthlyRevenue
        monthlyCosts = plan.monthlyCosts
        proposedGrossSalary = plan.proposedGrossSalary
        proposedDividend = plan.proposedDividend
        salaryTaxPercent = plan.salaryTaxRate * 100
        dividendTaxPercent = plan.dividendTaxRate * 100
        expectedTaxPayments = plan.expectedTaxPayments
        horizonMonths = plan.horizonMonths
        assumptions = plan.assumptions
    }

    private func save() {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.manageFinance, for: role) else {
            errorMessage = String(localized: "Din roll saknar behörighet att spara ekonomiscenarier.")
            return
        }

        do {
            _ = try calculator.calculate(input)
            let plan = FinancialPlanRecord(
                companyID: companyID,
                title: title.trimmed,
                currencyCode: currencyCode,
                availableCash: availableCash,
                monthlyRevenue: monthlyRevenue,
                monthlyCosts: monthlyCosts,
                proposedGrossSalary: proposedGrossSalary,
                proposedDividend: proposedDividend,
                salaryTaxRate: salaryTaxPercent / 100,
                dividendTaxRate: dividendTaxPercent / 100,
                expectedTaxPayments: expectedTaxPayments,
                horizonMonths: horizonMonths,
                assumptions: assumptions.trimmed
            )
            modelContext.insert(plan)
            modelContext.insert(
                AuditEventRecord(
                    companyID: companyID,
                    accountID: accountID,
                    action: "financialPlan.created",
                    entityType: "financialPlan",
                    entityID: plan.id,
                    summary: String(localized: "Ekonomiscenario sparades: \(plan.title)")
                )
            )
            try modelContext.save()
            errorMessage = nil
            saveTrigger += 1
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
