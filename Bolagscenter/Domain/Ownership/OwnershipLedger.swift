import Foundation

struct ShareTransactionSnapshot: Equatable, Sendable {
    let shareClassID: UUID
    let fromShareholderID: UUID?
    let toShareholderID: UUID?
    let quantity: Int
    let kind: ShareTransactionKind
}

struct SharePosition: Identifiable, Equatable, Sendable {
    let shareholderID: UUID
    let shareClassID: UUID
    let quantity: Int

    var id: String {
        "\(shareholderID.uuidString):\(shareClassID.uuidString)"
    }
}

enum OwnershipLedgerError: LocalizedError, Equatable, Sendable {
    case quantityMustBePositive
    case missingRecipient
    case missingSender
    case sameParty
    case insufficientShares(available: Int)

    var errorDescription: String? {
        switch self {
        case .quantityMustBePositive:
            "Antalet aktier måste vara större än noll."
        case .missingRecipient:
            "En mottagare måste anges."
        case .missingSender:
            "En överlåtare måste anges."
        case .sameParty:
            "Överlåtare och mottagare måste vara olika."
        case .insufficientShares(let available):
            "Överlåtaren har bara \(available) aktier i det valda aktieslaget."
        }
    }
}

struct OwnershipLedger: Sendable {
    func positions(from transactions: [ShareTransactionSnapshot]) -> [SharePosition] {
        struct PositionKey: Hashable {
            let shareholderID: UUID
            let shareClassID: UUID
        }

        var balances: [PositionKey: Int] = [:]
        for transaction in transactions {
            if let sender = transaction.fromShareholderID {
                balances[PositionKey(shareholderID: sender, shareClassID: transaction.shareClassID), default: 0] -= transaction.quantity
            }
            if let recipient = transaction.toShareholderID {
                balances[PositionKey(shareholderID: recipient, shareClassID: transaction.shareClassID), default: 0] += transaction.quantity
            }
        }

        return balances
            .filter { $0.value != 0 }
            .map {
                SharePosition(
                    shareholderID: $0.key.shareholderID,
                    shareClassID: $0.key.shareClassID,
                    quantity: $0.value
                )
            }
            .sorted {
                if $0.shareholderID == $1.shareholderID {
                    $0.shareClassID.uuidString < $1.shareClassID.uuidString
                } else {
                    $0.shareholderID.uuidString < $1.shareholderID.uuidString
                }
            }
    }

    func validate(
        _ candidate: ShareTransactionSnapshot,
        existing: [ShareTransactionSnapshot]
    ) throws {
        guard candidate.quantity > 0 else {
            throw OwnershipLedgerError.quantityMustBePositive
        }

        switch candidate.kind {
        case .issuance:
            guard candidate.toShareholderID != nil else {
                throw OwnershipLedgerError.missingRecipient
            }
        case .transfer, .correction:
            guard let sender = candidate.fromShareholderID else {
                throw OwnershipLedgerError.missingSender
            }
            guard let recipient = candidate.toShareholderID else {
                throw OwnershipLedgerError.missingRecipient
            }
            guard sender != recipient else {
                throw OwnershipLedgerError.sameParty
            }
            try validateAvailableShares(
                shareholderID: sender,
                shareClassID: candidate.shareClassID,
                quantity: candidate.quantity,
                existing: existing
            )
        case .redemption:
            guard let sender = candidate.fromShareholderID else {
                throw OwnershipLedgerError.missingSender
            }
            try validateAvailableShares(
                shareholderID: sender,
                shareClassID: candidate.shareClassID,
                quantity: candidate.quantity,
                existing: existing
            )
        }
    }

    private func validateAvailableShares(
        shareholderID: UUID,
        shareClassID: UUID,
        quantity: Int,
        existing: [ShareTransactionSnapshot]
    ) throws {
        let available = positions(from: existing)
            .first {
                $0.shareholderID == shareholderID
                    && $0.shareClassID == shareClassID
            }?
            .quantity ?? 0
        guard available >= quantity else {
            throw OwnershipLedgerError.insufficientShares(available: available)
        }
    }
}

extension ShareTransactionRecord {
    var snapshot: ShareTransactionSnapshot {
        ShareTransactionSnapshot(
            shareClassID: shareClassID,
            fromShareholderID: fromShareholderID,
            toShareholderID: toShareholderID,
            quantity: quantity,
            kind: kind
        )
    }
}
