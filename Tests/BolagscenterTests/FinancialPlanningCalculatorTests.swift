import Testing
@testable import Bolagscenter

struct FinancialPlanningCalculatorTests {
    private let calculator = FinancialPlanningCalculator()

    @Test
    func calculatesCashRunwayAndForecastFromExplicitAssumptions() throws {
        let result = try calculator.calculate(
            FinancialPlanningInput(
                availableCash: 300_000,
                monthlyRevenue: 100_000,
                monthlyCosts: 150_000,
                proposedGrossSalary: 50_000,
                proposedDividend: 100_000,
                salaryTaxRate: 0.3,
                dividendTaxRate: 0.2,
                expectedTaxPayments: 25_000,
                horizonMonths: 3
            )
        )

        #expect(result.monthlyOperatingResult == -50_000)
        #expect(result.monthlyCashBurn == 50_000)
        #expect(result.cashRunwayMonths == 6)
        #expect(result.forecastEndingCash == 125_000)
    }

    @Test
    func calculatesSalaryAndDividendNetWithoutChoosingForUser() throws {
        let result = try calculator.calculate(
            FinancialPlanningInput(
                availableCash: 0,
                monthlyRevenue: 0,
                monthlyCosts: 0,
                proposedGrossSalary: 50_000,
                proposedDividend: 50_000,
                salaryTaxRate: 0.32,
                dividendTaxRate: 0.2,
                expectedTaxPayments: 0,
                horizonMonths: 12
            )
        )

        #expect(abs(result.salaryNet - 34_000) < 0.001)
        #expect(abs(result.dividendNet - 40_000) < 0.001)
        #expect(result.cashRunwayMonths == nil)
    }

    @Test
    func rejectsTaxRateOutsideZeroToOne() {
        #expect(throws: FinancialPlanningError.invalidTaxRate) {
            try calculator.calculate(
                FinancialPlanningInput(
                    availableCash: 0,
                    monthlyRevenue: 0,
                    monthlyCosts: 0,
                    proposedGrossSalary: 0,
                    proposedDividend: 0,
                    salaryTaxRate: 1.01,
                    dividendTaxRate: 0.2,
                    expectedTaxPayments: 0,
                    horizonMonths: 12
                )
            )
        }
    }
}
