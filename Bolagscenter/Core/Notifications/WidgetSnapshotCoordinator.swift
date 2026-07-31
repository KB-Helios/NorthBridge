import SwiftData
import WidgetKit

@MainActor
enum WidgetSnapshotCoordinator {
    static func clear(resetPrivacyPreference: Bool = false) {
        WidgetSnapshotStore.clear()
        if resetPrivacyPreference {
            WidgetPrivacyPreference.reset()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func refresh(companyID: UUID, modelContext: ModelContext) {
        let deadlineDescriptor = FetchDescriptor<DeadlineRecord>(
            predicate: #Predicate { $0.companyID == companyID },
            sortBy: [SortDescriptor(\.dueAt)]
        )
        let actionDescriptor = FetchDescriptor<ActionItemRecord>(
            predicate: #Predicate { $0.companyID == companyID },
            sortBy: [SortDescriptor(\.dueAt)]
        )
        let documentDescriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.companyID == companyID }
        )
        let integrationDescriptor = FetchDescriptor<IntegrationRecord>(
            predicate: #Predicate { $0.companyID == companyID }
        )
        let metricDescriptor = FetchDescriptor<FinancialMetricRecord>(
            predicate: #Predicate { $0.companyID == companyID },
            sortBy: [SortDescriptor(\.periodEnd, order: .reverse)]
        )
        let companyDescriptor = FetchDescriptor<CompanyRecord>(
            predicate: #Predicate { $0.id == companyID }
        )

        do {
            let openDeadlines = try modelContext.fetch(deadlineDescriptor).filter {
                $0.status != .completed && $0.status != .dismissed
            }
            let openActions = try modelContext.fetch(actionDescriptor).filter {
                $0.status != .completed
            }
            let documents = try modelContext.fetch(documentDescriptor)
            let integrations = try modelContext.fetch(integrationDescriptor)
            let metrics = try modelContext.fetch(metricDescriptor)
            let company = try modelContext.fetch(companyDescriptor).first
            let next = openDeadlines.first
            let latestLiquidity = metrics.first {
                $0.kind == .availableLiquidity || $0.kind == .bankBalance
            }
            let showsSensitiveData = WidgetPrivacyPreference.showsSensitiveData
            var pulseFactors: [String] = []
            if openDeadlines.contains(where: { $0.dueAt < .now }) {
                pulseFactors.append(String(localized: "Försenade deadlines"))
            }
            if documents.isEmpty {
                pulseFactors.append(String(localized: "Dokument saknas"))
            }
            if company?.status == .unknown || company?.isStale == true {
                pulseFactors.append(String(localized: "Registrering behöver verifieras"))
            }
            if !openActions.isEmpty {
                pulseFactors.append(String(localized: "Styrelseåtgärder väntar"))
            }
            if integrations.contains(
                where: { $0.state == .failed || $0.state == .unauthorized }
            ) {
                pulseFactors.append(String(localized: "Integration behöver åtgärdas"))
            }
            if let latestLiquidity, latestLiquidity.amount < 0 {
                pulseFactors.append(String(localized: "Negativ registrerad likviditet"))
            }

            try WidgetSnapshotStore.save(
                WidgetSnapshot(
                    deadlineTitle: showsSensitiveData ? next?.title : nil,
                    deadlineDate: showsSensitiveData ? next?.dueAt : nil,
                    openDeadlineCount: openDeadlines.count,
                    openActionCount: openActions.count,
                    pulseFactors: pulseFactors,
                    availableLiquidity: showsSensitiveData
                        ? latestLiquidity?.amount
                        : nil,
                    liquidityCurrencyCode: showsSensitiveData
                        ? latestLiquidity?.currencyCode
                        : nil,
                    liquiditySourceUpdatedAt: showsSensitiveData
                        ? latestLiquidity?.sourceUpdatedAt
                        : nil,
                    showsSensitiveData: showsSensitiveData,
                    updatedAt: .now
                )
            )
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            SecureLogger.persistence.error(
                "Widget snapshot refresh failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
    }
}
