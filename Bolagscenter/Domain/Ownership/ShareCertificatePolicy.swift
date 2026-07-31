import Foundation

struct ShareCertificateDraft: Sendable {
    let certificateNumber: String
    let quantity: Int
    let shareNumberFrom: Int?
    let shareNumberTo: Int?
}

enum ShareCertificateValidationError: LocalizedError, Equatable, Sendable {
    case missingCertificateNumber
    case duplicateCertificateNumber
    case invalidQuantity
    case insufficientHolding(available: Int)
    case incompleteShareNumberRange
    case invalidShareNumberRange
    case overlappingShareNumberRange
    case shareNumberRangeDoesNotMatchQuantity(expected: Int)

    var errorDescription: String? {
        switch self {
        case .missingCertificateNumber:
            "Ange ett unikt aktiebrevsnummer."
        case .duplicateCertificateNumber:
            "Aktiebrevsnumret används redan i bolaget."
        case .invalidQuantity:
            "Antalet aktier måste vara större än noll."
        case .insufficientHolding(let available):
            "Aktiebrevet överskrider det ej certifierade innehavet. Tillgängligt: \(available) aktier."
        case .incompleteShareNumberRange:
            "Ange både första och sista aktienummer, eller lämna båda tomma."
        case .invalidShareNumberRange:
            "Aktienummerintervallet måste börja på ett positivt tal och sluta på samma eller ett högre tal."
        case .overlappingShareNumberRange:
            "Aktienummerintervallet överlappar ett annat aktivt aktiebrev för aktieslaget."
        case .shareNumberRangeDoesNotMatchQuantity(let expected):
            "Aktienummerintervallet omfattar \(expected) aktier och måste motsvara angivet antal."
        }
    }
}

struct ShareCertificatePolicy: Sendable {
    func validate(
        _ draft: ShareCertificateDraft,
        currentHolding: Int,
        alreadyCertifiedQuantity: Int,
        existingCertificateNumbers: Set<String>,
        existingShareNumberRanges: [ClosedRange<Int>] = []
    ) throws {
        let normalizedNumber = normalize(draft.certificateNumber)
        guard !normalizedNumber.isEmpty else {
            throw ShareCertificateValidationError.missingCertificateNumber
        }
        guard !existingCertificateNumbers
            .map({ normalize($0) })
            .contains(normalizedNumber) else {
            throw ShareCertificateValidationError.duplicateCertificateNumber
        }
        guard draft.quantity > 0 else {
            throw ShareCertificateValidationError.invalidQuantity
        }

        let available = max(0, currentHolding - alreadyCertifiedQuantity)
        guard draft.quantity <= available else {
            throw ShareCertificateValidationError.insufficientHolding(
                available: available
            )
        }

        switch (draft.shareNumberFrom, draft.shareNumberTo) {
        case (nil, nil):
            return
        case (.some, nil), (nil, .some):
            throw ShareCertificateValidationError.incompleteShareNumberRange
        case (let first?, let last?):
            guard first > 0, last >= first else {
                throw ShareCertificateValidationError.invalidShareNumberRange
            }
            let rangeQuantity = last - first + 1
            guard rangeQuantity == draft.quantity else {
                throw ShareCertificateValidationError
                    .shareNumberRangeDoesNotMatchQuantity(expected: rangeQuantity)
            }
            let proposedRange = first...last
            guard !existingShareNumberRanges.contains(where: {
                $0.overlaps(proposedRange)
            }) else {
                throw ShareCertificateValidationError.overlappingShareNumberRange
            }
        }
    }

    private func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
