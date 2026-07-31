import Testing
@testable import Bolagscenter

struct DocumentMetadataExtractorTests {
    private let extractor = DocumentMetadataExtractor()

    @Test
    func extractsValidatedOrganisationNumbersAndDates() {
        let result = extractor.extract(
            from: """
            Årsredovisning 2025
            Exempelbolaget AB
            Organisationsnummer 556016-0680
            Fastställd 2026-06-30
            """,
            pageCount: 4
        )

        #expect(result.detectedOrganisationNumbers == ["556016-0680"])
        #expect(result.detectedDates == ["2026-06-30"])
        #expect(result.pageCount == 4)
        #expect(result.suggestedCategory == .annualReports)
        #expect(result.suggestedTitle == "Årsredovisning 2025")
    }

    @Test
    func rejectsNumberThatFailsOrganisationNumberChecksum() {
        let result = extractor.extract(
            from: "Organisationsnummer 556016-0681",
            pageCount: 1
        )

        #expect(result.detectedOrganisationNumbers.isEmpty)
    }

    @Test
    func classifiesBoardMinutesWithoutInventingMetadata() {
        let result = extractor.extract(
            from: "Styrelseprotokoll\nBeslut om budget och likviditet",
            pageCount: 2
        )

        #expect(result.suggestedCategory == .boardMinutes)
        #expect(result.detectedOrganisationNumbers.isEmpty)
        #expect(result.detectedDates.isEmpty)
    }

    @Test
    func extractsLikelyAgreementPartiesAsReviewableSuggestions() {
        let result = extractor.extract(
            from: """
            Aktieägaravtal
            Mellan Nordisk Test AB och Anna Andersson
            Organisationsnummer 556016-0680
            """,
            pageCount: 3
        )

        #expect(result.detectedParties.contains("Nordisk Test AB"))
        #expect(result.detectedParties.contains("Anna Andersson"))
        #expect(result.suggestedCategory == .shareholderAgreement)
    }
}
