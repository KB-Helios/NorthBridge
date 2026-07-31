import Foundation
import SwiftData

@Model
final class FinancialPlanRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var title: String
    var currencyCode: String
    var availableCash: Double
    var monthlyRevenue: Double
    var monthlyCosts: Double
    var proposedGrossSalary: Double
    var proposedDividend: Double
    var salaryTaxRate: Double
    var dividendTaxRate: Double
    var expectedTaxPayments: Double
    var horizonMonths: Int
    var assumptions: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        title: String,
        currencyCode: String = "SEK",
        availableCash: Double,
        monthlyRevenue: Double,
        monthlyCosts: Double,
        proposedGrossSalary: Double,
        proposedDividend: Double,
        salaryTaxRate: Double,
        dividendTaxRate: Double,
        expectedTaxPayments: Double,
        horizonMonths: Int,
        assumptions: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.title = title
        self.currencyCode = currencyCode
        self.availableCash = availableCash
        self.monthlyRevenue = monthlyRevenue
        self.monthlyCosts = monthlyCosts
        self.proposedGrossSalary = proposedGrossSalary
        self.proposedDividend = proposedDividend
        self.salaryTaxRate = salaryTaxRate
        self.dividendTaxRate = dividendTaxRate
        self.expectedTaxPayments = expectedTaxPayments
        self.horizonMonths = horizonMonths
        self.assumptions = assumptions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var input: FinancialPlanningInput {
        FinancialPlanningInput(
            availableCash: availableCash,
            monthlyRevenue: monthlyRevenue,
            monthlyCosts: monthlyCosts,
            proposedGrossSalary: proposedGrossSalary,
            proposedDividend: proposedDividend,
            salaryTaxRate: salaryTaxRate,
            dividendTaxRate: dividendTaxRate,
            expectedTaxPayments: expectedTaxPayments,
            horizonMonths: horizonMonths
        )
    }
}

struct FinancialPlanningInput: Equatable, Sendable {
    let availableCash: Double
    let monthlyRevenue: Double
    let monthlyCosts: Double
    let proposedGrossSalary: Double
    let proposedDividend: Double
    let salaryTaxRate: Double
    let dividendTaxRate: Double
    let expectedTaxPayments: Double
    let horizonMonths: Int
}

struct FinancialPlanningResult: Equatable, Sendable {
    let monthlyOperatingResult: Double
    let monthlyCashBurn: Double
    let cashRunwayMonths: Double?
    let salaryNet: Double
    let dividendNet: Double
    let forecastEndingCash: Double
}

enum FinancialPlanningError: LocalizedError, Equatable, Sendable {
    case negativeValue
    case invalidTaxRate
    case invalidHorizon

    var errorDescription: String? {
        switch self {
        case .negativeValue:
            "Planeringsvärden får inte vara negativa."
        case .invalidTaxRate:
            "Skattesatser måste vara mellan 0 och 100 procent."
        case .invalidHorizon:
            "Prognosperioden måste vara mellan 1 och 60 månader."
        }
    }
}

struct FinancialPlanningCalculator: Sendable {
    func calculate(
        _ input: FinancialPlanningInput
    ) throws -> FinancialPlanningResult {
        let amounts = [
            input.availableCash,
            input.monthlyRevenue,
            input.monthlyCosts,
            input.proposedGrossSalary,
            input.proposedDividend,
            input.expectedTaxPayments
        ]
        guard amounts.allSatisfy({ $0 >= 0 && $0.isFinite }) else {
            throw FinancialPlanningError.negativeValue
        }
        guard (0...1).contains(input.salaryTaxRate),
              (0...1).contains(input.dividendTaxRate) else {
            throw FinancialPlanningError.invalidTaxRate
        }
        guard (1...60).contains(input.horizonMonths) else {
            throw FinancialPlanningError.invalidHorizon
        }

        let operatingResult = input.monthlyRevenue - input.monthlyCosts
        let burn = max(0, -operatingResult)
        let runway = burn > 0 ? input.availableCash / burn : nil
        let forecast = input.availableCash
            + Double(input.horizonMonths) * operatingResult
            - input.expectedTaxPayments

        return FinancialPlanningResult(
            monthlyOperatingResult: operatingResult,
            monthlyCashBurn: burn,
            cashRunwayMonths: runway,
            salaryNet: input.proposedGrossSalary * (1 - input.salaryTaxRate),
            dividendNet: input.proposedDividend * (1 - input.dividendTaxRate),
            forecastEndingCash: forecast
        )
    }
}
