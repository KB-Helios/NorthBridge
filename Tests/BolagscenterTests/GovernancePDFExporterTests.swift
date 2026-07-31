import Foundation
import PDFKit
import Testing
@testable import Bolagscenter

@MainActor
struct GovernancePDFExporterTests {
    @Test
    func exportsCompanyOverviewAsReadablePDF() throws {
        let input = CompanyOverviewPDFInput(
            companyID: UUID(),
            companyName: "NorthBridge Test AB",
            organisationNumber: "5599991238",
            status: .active,
            companyType: "Aktiebolag",
            registeredOffice: "Stockholm",
            incorporationDate: Date(timeIntervalSince1970: 1_700_000_000),
            fiscalYear: "01-01–12-31",
            businessDescription: "Utvecklar säkra digitala bolagstjänster.",
            shareCapital: 25_000,
            shareCapitalCurrencyCode: "SEK",
            generatedAt: Date(timeIntervalSince1970: 1_750_000_000),
            sourceName: "Testkälla",
            sourceUpdatedAt: Date(timeIntervalSince1970: 1_749_000_000),
            lastSynchronizedAt: Date(timeIntervalSince1970: 1_749_500_000),
            peopleCount: 3,
            shareholderCount: 2,
            documentCount: 7,
            meetingCount: 4,
            adoptedResolutionCount: 5,
            openDeadlines: [
                CompanyOverviewDeadlineRow(
                    title: "Lämna årsredovisning",
                    dueAt: Date(timeIntervalSince1970: 1_760_000_000),
                    priority: .high,
                    responsibleName: "Anna Andersson"
                )
            ],
            financialMetrics: [
                CompanyOverviewFinancialMetricRow(
                    title: "Tillgänglig likviditet",
                    amount: 325_000,
                    currencyCode: "SEK",
                    valueState: .booked,
                    sourceName: "Testbokföring",
                    sourceUpdatedAt: Date(timeIntervalSince1970: 1_749_500_000)
                )
            ]
        )

        let url = try GovernancePDFExporter.exportCompanyOverview(input)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try #require(PDFDocument(url: url))
        #expect(document.pageCount >= 1)
        #expect(extractedText(from: document).contains("NorthBridge Test AB"))
        #expect(extractedText(from: document).contains("Kommande deadlines"))
    }

    @Test
    func exportsBoardMinutesAsReadablePDF() throws {
        let input = BoardMinutesPDFInput(
            companyID: UUID(),
            companyName: "NorthBridge Test AB",
            organisationNumber: "5599991238",
            meetingTitle: "Ordinarie styrelsemöte",
            meetingNumber: "2026-01",
            scheduledAt: Date(timeIntervalSince1970: 1_750_000_000),
            location: "Stockholm",
            status: .approved,
            attendees: ["Anna Andersson"],
            agenda: [
                BoardMinutesAgendaItem(
                    position: 1,
                    title: "Mötets öppnande",
                    details: "Ordföranden öppnade mötet."
                )
            ],
            resolutions: [
                BoardMinutesResolution(
                    title: "Godkännande",
                    decisionText: "Styrelsen godkände förslaget.",
                    status: .adopted
                )
            ],
            notes: ""
        )

        let url = try GovernancePDFExporter.exportBoardMinutes(input)
        let secondURL = try GovernancePDFExporter.exportBoardMinutes(input)
        defer { try? FileManager.default.removeItem(at: url) }
        defer { try? FileManager.default.removeItem(at: secondURL) }

        let document = try #require(PDFDocument(url: url))
        #expect(url != secondURL)
        #expect(document.pageCount >= 1)
        #expect(extractedText(from: document).contains("STYRELSEPROTOKOLL"))
    }

    @Test
    func exportsShareholderRegisterAsReadablePDF() throws {
        let input = ShareholderRegisterPDFInput(
            companyID: UUID(),
            companyName: "NorthBridge Test AB",
            organisationNumber: "5599991238",
            generatedAt: Date(timeIntervalSince1970: 1_750_000_000),
            rows: [
                ShareholderRegisterRow(
                    shareholderName: "Anna Andersson",
                    identityReference: "SE-TEST-1",
                    shareClassName: "A",
                    quantity: 1_000,
                    ownershipPercentage: 1,
                    votingPercentage: 1
                )
            ],
            totalShares: 1_000,
            totalVotes: 1_000
        )

        let url = try GovernancePDFExporter.exportShareholderRegister(input)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try #require(PDFDocument(url: url))
        #expect(document.pageCount >= 1)
        #expect(extractedText(from: document).contains("AKTIEBOK"))
    }

    @Test
    func exportsShareCertificateAsClearlyLabeledDraftPDF() throws {
        let input = ShareCertificatePDFInput(
            certificateID: UUID(),
            companyID: UUID(),
            companyName: "NorthBridge Test AB",
            organisationNumber: "5599991238",
            certificateNumber: "AB-2026-01",
            shareholderName: "Anna Andersson",
            shareholderIdentityReference: "SE-TEST-1",
            shareholderPostalAddress: "Testgatan 1, 111 11 Stockholm",
            shareClassName: "A",
            quantity: 100,
            shareNumberFrom: 1,
            shareNumberTo: 100,
            issuedAt: Date(timeIntervalSince1970: 1_750_000_000),
            status: .draft,
            notes: ""
        )

        let url = try GovernancePDFExporter.exportShareCertificate(input)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try #require(PDFDocument(url: url))
        let text = extractedText(from: document)
        #expect(document.pageCount >= 1)
        #expect(text.contains("AKTIEBREV"))
        #expect(text.contains("UTKAST"))
        #expect(text.contains("AB-2026-01"))
    }

    private func extractedText(from document: PDFDocument) -> String {
        (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
    }
}
