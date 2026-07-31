import Foundation

struct OrganisationNumber: Hashable, Codable, Sendable, CustomStringConvertible {
    let digits: String

    init(_ input: String) throws {
        let normalized = input.filter(\.isNumber)
        guard normalized.count == 10 else {
            throw ValidationError.invalidLength
        }
        guard normalized.allSatisfy({ $0.wholeNumberValue != nil }) else {
            throw ValidationError.invalidCharacters
        }
        guard let thirdDigit = normalized.dropFirst(2).first?.wholeNumberValue, thirdDigit >= 2 else {
            throw ValidationError.invalidOrganisationNumber
        }
        guard Self.passesLuhn(normalized) else {
            throw ValidationError.invalidChecksum
        }
        digits = normalized
    }

    var formatted: String {
        let splitIndex = digits.index(digits.startIndex, offsetBy: 6)
        return "\(digits[..<splitIndex])-\(digits[splitIndex...])"
    }

    var description: String { formatted }

    private static func passesLuhn(_ value: String) -> Bool {
        let numbers = value.compactMap(\.wholeNumberValue)
        guard numbers.count == 10 else { return false }

        let sum = numbers.enumerated().reduce(into: 0) { result, item in
            let product = item.element * (item.offset.isMultiple(of: 2) ? 2 : 1)
            result += product > 9 ? product - 9 : product
        }
        return sum.isMultiple(of: 10)
    }

    enum ValidationError: LocalizedError, Equatable {
        case invalidLength
        case invalidCharacters
        case invalidOrganisationNumber
        case invalidChecksum

        var errorDescription: String? {
            switch self {
            case .invalidLength:
                "Organisationsnumret ska innehålla tio siffror."
            case .invalidCharacters:
                "Organisationsnumret innehåller ogiltiga tecken."
            case .invalidOrganisationNumber:
                "Numret ser inte ut att vara ett svenskt organisationsnummer."
            case .invalidChecksum:
                "Kontrollsiffran i organisationsnumret stämmer inte."
            }
        }
    }
}
