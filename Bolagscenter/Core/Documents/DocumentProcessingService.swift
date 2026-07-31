import Foundation
import PDFKit
import UniformTypeIdentifiers
import Vision

struct DocumentAnalysis: Sendable {
    let extractedText: String
    let detectedOrganisationNumbers: [String]
    let detectedDates: [String]
    let detectedParties: [String]
    let suggestedTitle: String
    let suggestedCategory: DocumentCategory
    let pageCount: Int
}

enum DocumentProcessingError: LocalizedError {
    case unsupportedContent
    case unreadableImage
    case unableToCreatePDF

    var errorDescription: String? {
        switch self {
        case .unsupportedContent:
            "Filtypen kan inte analyseras."
        case .unreadableImage:
            "En eller flera dokumentsidor kunde inte läsas."
        case .unableToCreatePDF:
            "De skannade sidorna kunde inte sammanfogas till en PDF."
        }
    }
}

actor DocumentProcessingService {
    func analyze(data: Data, typeIdentifier: String) throws -> DocumentAnalysis {
        let pageTexts: [String]
        let pageCount: Int

        if typeIdentifier == UTType.pdf.identifier {
            guard let document = PDFDocument(data: data) else {
                throw DocumentProcessingError.unsupportedContent
            }
            pageCount = document.pageCount
            pageTexts = try (0..<document.pageCount).map { index in
                guard let page = document.page(at: index) else { return "" }
                if let embeddedText = page.string, !embeddedText.trimmed.isEmpty {
                    return embeddedText
                }
                let thumbnail = page.thumbnail(
                    of: CGSize(width: 1_600, height: 2_200),
                    for: .mediaBox
                )
                guard let imageData = thumbnail.jpegData(compressionQuality: 0.92) else {
                    return ""
                }
                return try recognizeText(in: imageData)
            }
        } else if UTType(typeIdentifier)?.conforms(to: .image) == true {
            pageCount = 1
            pageTexts = [try recognizeText(in: data)]
        } else {
            throw DocumentProcessingError.unsupportedContent
        }

        let extractedText = pageTexts
            .map(\.trimmed)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return DocumentMetadataExtractor().extract(
            from: extractedText,
            pageCount: pageCount
        )
    }

    @MainActor
    static func makePDF(from pageImageData: [Data]) throws -> Data {
        let document = PDFDocument()
        for (index, data) in pageImageData.enumerated() {
            guard let image = UIImage(data: data),
                  let page = PDFPage(image: image) else {
                throw DocumentProcessingError.unreadableImage
            }
            document.insert(page, at: index)
        }
        guard let data = document.dataRepresentation(), !data.isEmpty else {
            throw DocumentProcessingError.unableToCreatePDF
        }
        return data
    }

    private func recognizeText(in data: Data) throws -> String {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            throw DocumentProcessingError.unreadableImage
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.recognitionLanguages = ["sv-SE", "en-US"]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n") ?? ""
    }

}

struct DocumentMetadataExtractor: Sendable {
    func extract(from text: String, pageCount: Int) -> DocumentAnalysis {
        DocumentAnalysis(
            extractedText: text,
            detectedOrganisationNumbers: extractOrganisationNumbers(from: text),
            detectedDates: extractDates(from: text),
            detectedParties: extractParties(from: text),
            suggestedTitle: suggestTitle(from: text),
            suggestedCategory: suggestCategory(from: text),
            pageCount: pageCount
        )
    }

    private func extractOrganisationNumbers(from text: String) -> [String] {
        matches(pattern: #"\b\d{6}[-\s]?\d{4}\b"#, in: text)
            .compactMap { try? OrganisationNumber($0).formatted }
            .uniqued()
    }

    private func extractDates(from text: String) -> [String] {
        let patterns = [
            #"\b20\d{2}[-/.](?:0?[1-9]|1[0-2])[-/.](?:0?[1-9]|[12]\d|3[01])\b"#,
            #"\b(?:0?[1-9]|[12]\d|3[01])[-/.](?:0?[1-9]|1[0-2])[-/.]20\d{2}\b"#
        ]
        return patterns
            .flatMap { matches(pattern: $0, in: text) }
            .uniqued()
    }

    private func extractParties(from text: String) -> [String] {
        var parties = captureGroups(
            pattern: #"(?im)^\s*mellan\s+(.{2,80}?)\s+och\s+(.{2,80}?)\s*[.,;]?\s*$"#,
            groupIndexes: [1, 2],
            in: text
        )
        parties += captureGroups(
            pattern: #"(?im)^\s*(?:part(?:en|\s+\d+)?|köpare|säljare|uppdragsgivare|leverantör)\s*[:\-]\s*(.{2,100}?)\s*[.,;]?\s*$"#,
            groupIndexes: [1],
            in: text
        )
        parties += matches(
            pattern: #"(?im)\b[\p{L}\p{N}][\p{L}\p{N}&.'’ -]{1,70}\s(?:AB|HB|KB)\b"#,
            in: text
        )

        return Array(
            parties
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines.union(
                            CharacterSet(charactersIn: ".,;:")
                        )
                    )
                }
                .map {
                    $0.replacingOccurrences(
                        of: #"(?i)^\s*mellan\s+"#,
                        with: "",
                        options: .regularExpression
                    )
                }
                .filter { $0.count >= 2 && $0.count <= 100 }
                .uniqued()
                .prefix(20)
        )
    }

    private func matches(pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private func captureGroups(
        pattern: String,
        groupIndexes: [Int],
        in text: String
    ) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).flatMap { match in
            groupIndexes.compactMap { groupIndex in
                guard groupIndex < match.numberOfRanges,
                      let range = Range(
                        match.range(at: groupIndex),
                        in: text
                      ) else {
                    return nil
                }
                return String(text[range])
            }
        }
    }

    private func suggestTitle(from text: String) -> String {
        let candidate = text
            .components(separatedBy: .newlines)
            .map(\.trimmed)
            .first { line in
                line.count >= 4
                    && line.count <= 90
                    && line.rangeOfCharacter(from: .letters) != nil
            }
        return candidate ?? String(localized: "Skannat dokument")
    }

    private func suggestCategory(from text: String) -> DocumentCategory {
        let normalized = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "sv_SE")
        )
        let rules: [(DocumentCategory, [String])] = [
            (.registrationCertificate, ["registreringsbevis", "bolagsverket"]),
            (.articlesOfAssociation, ["bolagsordning"]),
            (.annualReports, ["arsredovisning", "forvaltningsberattelse"]),
            (.boardMinutes, ["styrelseprotokoll", "styrelsemote"]),
            (.generalMeetingMinutes, ["stammoprotokoll", "arsstamma"]),
            (.shareholderAgreement, ["aktieagaravtal"]),
            (.shareholderRegister, ["aktiebok"]),
            (.taxDocuments, ["skatteverket", "momsdeklaration", "inkomstdeklaration"]),
            (.insurance, ["forsakringsbrev", "forsakring"]),
            (.powersOfAttorney, ["fullmakt"]),
            (.agreements, ["avtal", "parter"])
        ]
        return rules.first { _, keywords in
            keywords.contains { normalized.contains($0) }
        }?.0 ?? .other
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
