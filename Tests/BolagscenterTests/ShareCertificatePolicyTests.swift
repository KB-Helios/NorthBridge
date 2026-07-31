import Testing
@testable import Bolagscenter

struct ShareCertificatePolicyTests {
    private let policy = ShareCertificatePolicy()

    @Test
    func acceptsCertificateWithinUncertifiedHolding() throws {
        try policy.validate(
            ShareCertificateDraft(
                certificateNumber: "AB-2026-01",
                quantity: 250,
                shareNumberFrom: 1,
                shareNumberTo: 250
            ),
            currentHolding: 1_000,
            alreadyCertifiedQuantity: 500,
            existingCertificateNumbers: ["AB-2025-01"]
        )
    }

    @Test
    func rejectsCertificateThatWouldExceedHolding() {
        #expect(
            throws: ShareCertificateValidationError.insufficientHolding(
                available: 100
            )
        ) {
            try policy.validate(
                ShareCertificateDraft(
                    certificateNumber: "AB-2026-02",
                    quantity: 101,
                    shareNumberFrom: nil,
                    shareNumberTo: nil
                ),
                currentHolding: 1_000,
                alreadyCertifiedQuantity: 900,
                existingCertificateNumbers: []
            )
        }
    }

    @Test
    func rejectsDuplicateNumberCaseInsensitively() {
        #expect(throws: ShareCertificateValidationError.duplicateCertificateNumber) {
            try policy.validate(
                ShareCertificateDraft(
                    certificateNumber: " ab-2026-01 ",
                    quantity: 1,
                    shareNumberFrom: nil,
                    shareNumberTo: nil
                ),
                currentHolding: 1,
                alreadyCertifiedQuantity: 0,
                existingCertificateNumbers: ["AB-2026-01"]
            )
        }
    }

    @Test
    func requiresShareNumberRangeToMatchQuantity() {
        #expect(
            throws: ShareCertificateValidationError
                .shareNumberRangeDoesNotMatchQuantity(expected: 10)
        ) {
            try policy.validate(
                ShareCertificateDraft(
                    certificateNumber: "AB-2026-03",
                    quantity: 9,
                    shareNumberFrom: 1,
                    shareNumberTo: 10
                ),
                currentHolding: 100,
                alreadyCertifiedQuantity: 0,
                existingCertificateNumbers: []
            )
        }
    }

    @Test
    func rejectsOverlappingActiveShareNumberRange() {
        #expect(throws: ShareCertificateValidationError.overlappingShareNumberRange) {
            try policy.validate(
                ShareCertificateDraft(
                    certificateNumber: "AB-2026-04",
                    quantity: 10,
                    shareNumberFrom: 95,
                    shareNumberTo: 104
                ),
                currentHolding: 1_000,
                alreadyCertifiedQuantity: 100,
                existingCertificateNumbers: ["AB-2026-01"],
                existingShareNumberRanges: [1...100]
            )
        }
    }
}
