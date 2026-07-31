import Foundation
import Testing
@testable import Bolagscenter

struct OwnershipLedgerTests {
    private let ledger = OwnershipLedger()
    private let classA = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let alice = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    private let bob = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3))

    @Test
    func issuanceAndTransferProduceCurrentPositionsWithoutOverwritingHistory() throws {
        let issuance = ShareTransactionSnapshot(
            shareClassID: classA,
            fromShareholderID: nil,
            toShareholderID: alice,
            quantity: 1_000,
            kind: .issuance
        )
        let transfer = ShareTransactionSnapshot(
            shareClassID: classA,
            fromShareholderID: alice,
            toShareholderID: bob,
            quantity: 250,
            kind: .transfer
        )

        try ledger.validate(issuance, existing: [])
        try ledger.validate(transfer, existing: [issuance])

        let positions = ledger.positions(from: [issuance, transfer])
        #expect(positions.first { $0.shareholderID == alice }?.quantity == 750)
        #expect(positions.first { $0.shareholderID == bob }?.quantity == 250)
        #expect([issuance, transfer].count == 2)
    }

    @Test
    func transferCannotCreateNegativeHolding() {
        let issuance = ShareTransactionSnapshot(
            shareClassID: classA,
            fromShareholderID: nil,
            toShareholderID: alice,
            quantity: 100,
            kind: .issuance
        )
        let invalidTransfer = ShareTransactionSnapshot(
            shareClassID: classA,
            fromShareholderID: alice,
            toShareholderID: bob,
            quantity: 101,
            kind: .transfer
        )

        #expect(throws: OwnershipLedgerError.insufficientShares(available: 100)) {
            try ledger.validate(invalidTransfer, existing: [issuance])
        }
    }

    @Test
    func transferRequiresDifferentParties() {
        let invalidTransfer = ShareTransactionSnapshot(
            shareClassID: classA,
            fromShareholderID: alice,
            toShareholderID: alice,
            quantity: 1,
            kind: .transfer
        )

        #expect(throws: OwnershipLedgerError.sameParty) {
            try ledger.validate(invalidTransfer, existing: [])
        }
    }

    @Test
    func redemptionReducesIssuedShares() throws {
        let issuance = ShareTransactionSnapshot(
            shareClassID: classA,
            fromShareholderID: nil,
            toShareholderID: alice,
            quantity: 100,
            kind: .issuance
        )
        let redemption = ShareTransactionSnapshot(
            shareClassID: classA,
            fromShareholderID: alice,
            toShareholderID: nil,
            quantity: 40,
            kind: .redemption
        )

        try ledger.validate(redemption, existing: [issuance])
        #expect(ledger.positions(from: [issuance, redemption]).first?.quantity == 60)
    }
}
