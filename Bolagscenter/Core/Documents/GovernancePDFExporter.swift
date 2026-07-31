import Foundation
import PDFKit
import UIKit

struct BoardMinutesPDFInput: Sendable {
    let companyID: UUID
    let companyName: String
    let organisationNumber: String
    let meetingTitle: String
    let meetingNumber: String
    let scheduledAt: Date
    let location: String
    let status: BoardMeetingStatus
    let attendees: [String]
    let agenda: [BoardMinutesAgendaItem]
    let resolutions: [BoardMinutesResolution]
    let notes: String
}

struct BoardMinutesAgendaItem: Sendable {
    let position: Int
    let title: String
    let details: String
}

struct BoardMinutesResolution: Sendable {
    let title: String
    let decisionText: String
    let status: ResolutionStatus
}

struct ShareholderRegisterPDFInput: Sendable {
    let companyID: UUID
    let companyName: String
    let organisationNumber: String
    let generatedAt: Date
    let rows: [ShareholderRegisterRow]
    let totalShares: Int
    let totalVotes: Double
}

struct ShareholderRegisterRow: Sendable {
    let shareholderName: String
    let identityReference: String
    let shareClassName: String
    let quantity: Int
    let ownershipPercentage: Double
    let votingPercentage: Double
}

struct ShareCertificatePDFInput: Sendable {
    let certificateID: UUID
    let companyID: UUID
    let companyName: String
    let organisationNumber: String
    let certificateNumber: String
    let shareholderName: String
    let shareholderIdentityReference: String
    let shareholderPostalAddress: String
    let shareClassName: String
    let quantity: Int
    let shareNumberFrom: Int?
    let shareNumberTo: Int?
    let issuedAt: Date
    let status: ShareCertificateStatus
    let notes: String
}

struct CompanyOverviewPDFInput: Sendable {
    let companyID: UUID
    let companyName: String
    let organisationNumber: String
    let status: CompanyStatus
    let companyType: String
    let registeredOffice: String
    let incorporationDate: Date?
    let fiscalYear: String
    let businessDescription: String
    let shareCapital: Double?
    let shareCapitalCurrencyCode: String
    let generatedAt: Date
    let sourceName: String
    let sourceUpdatedAt: Date
    let lastSynchronizedAt: Date?
    let peopleCount: Int
    let shareholderCount: Int
    let documentCount: Int
    let meetingCount: Int
    let adoptedResolutionCount: Int
    let openDeadlines: [CompanyOverviewDeadlineRow]
    let financialMetrics: [CompanyOverviewFinancialMetricRow]
}

struct CompanyOverviewDeadlineRow: Sendable {
    let title: String
    let dueAt: Date
    let priority: DeadlinePriority
    let responsibleName: String?
}

struct CompanyOverviewFinancialMetricRow: Sendable {
    let title: String
    let amount: Double
    let currencyCode: String
    let valueState: FinancialValueState
    let sourceName: String
    let sourceUpdatedAt: Date
}

enum GovernancePDFExportError: LocalizedError {
    case invalidDocument
    case unableToProtectFile

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "PDF-dokumentet kunde inte verifieras efter exporten."
        case .unableToProtectFile:
            "PDF-dokumentet skapades men kunde inte skyddas på enheten."
        }
    }
}

@MainActor
enum GovernancePDFExporter {
    fileprivate static let pageSize = CGSize(width: 595.2, height: 841.8)
    fileprivate static let pageMargins = UIEdgeInsets(top: 56, left: 56, bottom: 54, right: 56)

    static func exportBoardMinutes(_ input: BoardMinutesPDFInput) throws -> URL {
        let fileURL = try outputURL(
            companyID: input.companyID,
            filename: uniqueFilename(
                stem: "styrelseprotokoll-\(safeFilename(input.meetingNumber))"
            )
        )
        let title = input.meetingNumber.isEmpty
            ? input.meetingTitle
            : "\(input.meetingTitle) · \(input.meetingNumber)"
        let renderer = makeRenderer(title: title, author: input.companyName)

        try renderer.writePDF(to: fileURL) { context in
            var writer = PDFPageWriter(context: context, title: "STYRELSEPROTOKOLL")
            writer.startPage()
            writer.heading(input.companyName, size: 22)
            writer.text("Organisationsnummer \(formattedOrganisationNumber(input.organisationNumber))", style: .secondary)
            writer.rule()

            writer.keyValue("Möte", value: title)
            writer.keyValue(
                "Datum",
                value: input.scheduledAt.formatted(date: .long, time: .shortened)
            )
            writer.keyValue("Plats", value: input.location)
            writer.keyValue("Status", value: input.status.localizedName)

            writer.section("Närvarande")
            if input.attendees.isEmpty {
                writer.text("Ingen närvaro har registrerats.", style: .secondary)
            } else {
                for attendee in input.attendees {
                    writer.bullet(attendee)
                }
            }

            writer.section("Dagordning")
            if input.agenda.isEmpty {
                writer.text("Ingen dagordning har registrerats.", style: .secondary)
            } else {
                for item in input.agenda.sorted(by: { $0.position < $1.position }) {
                    writer.subheading("§ \(item.position) \(item.title)")
                    if !item.details.isEmpty {
                        writer.text(item.details)
                    }
                }
            }

            writer.section("Beslut")
            if input.resolutions.isEmpty {
                writer.text("Inga beslut har registrerats.", style: .secondary)
            } else {
                for resolution in input.resolutions {
                    writer.subheading(resolution.title)
                    writer.text(resolution.decisionText)
                    writer.text("Status: \(resolution.status.localizedName)", style: .secondary)
                }
            }

            if !input.notes.isEmpty {
                writer.section("Anteckningar")
                writer.text(input.notes)
            }

            writer.section("Justering")
            writer.text(
                input.status == .approved
                    ? "Protokollet är markerat som justerat i NorthBridge."
                    : "Detta dokument är ett utkast och har inte markerats som justerat."
            )
            writer.signatureLine("Ordförande")
            writer.signatureLine("Justerare")
            writer.finish()
        }

        try secureAndValidate(fileURL)
        return fileURL
    }

    static func exportShareholderRegister(_ input: ShareholderRegisterPDFInput) throws -> URL {
        let fileURL = try outputURL(
            companyID: input.companyID,
            filename: uniqueFilename(
                stem: "aktiebok-\(input.generatedAt.ISO8601Format().prefix(10))"
            )
        )
        let renderer = makeRenderer(title: "Aktiebok", author: input.companyName)

        try renderer.writePDF(to: fileURL) { context in
            var writer = PDFPageWriter(context: context, title: "AKTIEBOK")
            writer.startPage()
            writer.heading(input.companyName, size: 22)
            writer.text("Organisationsnummer \(formattedOrganisationNumber(input.organisationNumber))", style: .secondary)
            writer.text(
                "Sammanställd \(input.generatedAt.formatted(date: .long, time: .shortened))",
                style: .secondary
            )
            writer.rule()

            writer.keyValue("Totalt antal aktier", value: input.totalShares.formatted())
            writer.keyValue(
                "Totalt antal röster",
                value: input.totalVotes.formatted(.number.precision(.fractionLength(0...2)))
            )
            writer.section("Aktieinnehav")

            if input.rows.isEmpty {
                writer.text("Aktieboken saknar registrerade innehav.", style: .secondary)
            } else {
                for row in input.rows {
                    writer.subheading(row.shareholderName)
                    if !row.identityReference.isEmpty {
                        writer.text(row.identityReference, style: .secondary)
                    }
                    writer.keyValue("Aktieslag", value: row.shareClassName)
                    writer.keyValue("Antal", value: row.quantity.formatted())
                    writer.keyValue(
                        "Ägarandel",
                        value: row.ownershipPercentage.formatted(.percent.precision(.fractionLength(1)))
                    )
                    writer.keyValue(
                        "Röstandel",
                        value: row.votingPercentage.formatted(.percent.precision(.fractionLength(1)))
                    )
                    writer.spacing(8)
                }
            }

            writer.section("Underlag")
            writer.text(
                "Aktieboken är sammanställd från historiska aktiehändelser registrerade i NorthBridge. Kontrollera innehållet mot bolagets rättsligt bindande underlag."
            )
            writer.finish()
        }

        try secureAndValidate(fileURL)
        return fileURL
    }

    static func exportShareCertificate(_ input: ShareCertificatePDFInput) throws -> URL {
        let fileURL = try outputURL(
            companyID: input.companyID,
            filename: uniqueFilename(
                stem: "aktiebrev-\(safeFilename(input.certificateNumber))"
            )
        )
        let title = input.status == .draft
            ? "Aktiebrev – utkast"
            : "Aktiebrev"
        let renderer = makeRenderer(title: title, author: input.companyName)

        try renderer.writePDF(to: fileURL) { context in
            var writer = PDFPageWriter(
                context: context,
                title: input.status == .draft
                    ? "AKTIEBREV · UTKAST"
                    : "AKTIEBREV"
            )
            writer.startPage()
            writer.heading(input.companyName, size: 22)
            writer.text(
                "Organisationsnummer \(formattedOrganisationNumber(input.organisationNumber))",
                style: .secondary
            )
            writer.rule()

            writer.keyValue("Aktiebrevsnummer", value: input.certificateNumber)
            writer.keyValue(
                "Registrerad status",
                value: input.status.localizedName
            )
            writer.keyValue(
                "Registrerat datum",
                value: input.issuedAt.formatted(date: .long, time: .omitted)
            )

            writer.section("Aktieägare")
            writer.subheading(input.shareholderName)
            if !input.shareholderIdentityReference.isEmpty {
                writer.keyValue(
                    "Identitetsreferens",
                    value: input.shareholderIdentityReference
                )
            }
            if !input.shareholderPostalAddress.isEmpty {
                writer.text(input.shareholderPostalAddress)
            }

            writer.section("Aktier")
            writer.keyValue("Aktieslag", value: input.shareClassName)
            writer.keyValue("Antal aktier", value: input.quantity.formatted())
            if let first = input.shareNumberFrom, let last = input.shareNumberTo {
                writer.keyValue(
                    "Aktienummer",
                    value: first == last
                        ? first.formatted()
                        : "\(first.formatted())–\(last.formatted())"
                )
            } else {
                writer.text(
                    "Individuella aktienummer har inte registrerats i NorthBridge.",
                    style: .secondary
                )
            }

            if !input.notes.isEmpty {
                writer.section("Anteckningar")
                writer.text(input.notes)
            }

            writer.section("Kontroll och underskrift")
            writer.text(
                "Dokumentet är administrativt underlag. Behörig företrädare måste kontrollera uppgifterna, bolagets aktiebok, eventuella beslut och tillämpliga formkrav innan ett aktiebrev utfärdas eller undertecknas."
            )
            writer.signatureLine("Behörig styrelseföreträdare")
            writer.signatureLine("Behörig styrelseföreträdare")

            writer.section("Viktig avgränsning")
            writer.text(
                "NorthBridge avgör inte om bolaget ska utfärda aktiebrev och dokumentet utgör inte juridisk rådgivning. Markeringen i appen bevisar inte att ett giltigt original har utfärdats, undertecknats eller överlämnats.",
                style: .secondary
            )
            writer.finish()
        }

        try secureAndValidate(fileURL)
        return fileURL
    }

    static func exportCompanyOverview(_ input: CompanyOverviewPDFInput) throws -> URL {
        let fileURL = try outputURL(
            companyID: input.companyID,
            filename: uniqueFilename(
                stem: "bolagsoversikt-\(input.generatedAt.ISO8601Format().prefix(10))"
            )
        )
        let renderer = makeRenderer(title: "Bolagsöversikt", author: input.companyName)

        try renderer.writePDF(to: fileURL) { context in
            var writer = PDFPageWriter(context: context, title: "BOLAGSÖVERSIKT")
            writer.startPage()
            writer.heading(input.companyName, size: 22)
            writer.text(
                "Organisationsnummer \(formattedOrganisationNumber(input.organisationNumber))",
                style: .secondary
            )
            writer.text(
                "Exporterad \(input.generatedAt.formatted(date: .long, time: .shortened))",
                style: .secondary
            )
            writer.rule()

            writer.section("Bolagsuppgifter")
            writer.keyValue("Status", value: input.status.localizedName)
            if !input.companyType.isEmpty {
                writer.keyValue("Bolagsform", value: input.companyType)
            }
            if !input.registeredOffice.isEmpty {
                writer.keyValue("Säte", value: input.registeredOffice)
            }
            if let incorporationDate = input.incorporationDate {
                writer.keyValue(
                    "Registreringsdatum",
                    value: incorporationDate.formatted(date: .long, time: .omitted)
                )
            }
            if !input.fiscalYear.isEmpty {
                writer.keyValue("Räkenskapsår", value: input.fiscalYear)
            }
            if let shareCapital = input.shareCapital {
                writer.keyValue(
                    "Aktiekapital",
                    value: shareCapital.formatted(
                        .currency(code: input.shareCapitalCurrencyCode)
                    )
                )
            }
            if !input.businessDescription.isEmpty {
                writer.subheading("Verksamhetsbeskrivning")
                writer.text(input.businessDescription)
            }

            writer.section("Registrerad information")
            writer.keyValue("Personer", value: input.peopleCount.formatted())
            writer.keyValue("Aktieägare", value: input.shareholderCount.formatted())
            writer.keyValue("Dokument", value: input.documentCount.formatted())
            writer.keyValue("Styrelsemöten", value: input.meetingCount.formatted())
            writer.keyValue(
                "Fattade beslut",
                value: input.adoptedResolutionCount.formatted()
            )

            writer.section("Kommande deadlines")
            if input.openDeadlines.isEmpty {
                writer.text("Inga öppna deadlines är registrerade.", style: .secondary)
            } else {
                for deadline in input.openDeadlines {
                    writer.subheading(deadline.title)
                    writer.keyValue(
                        "Förfallodatum",
                        value: deadline.dueAt.formatted(date: .long, time: .omitted)
                    )
                    writer.keyValue("Prioritet", value: deadline.priority.localizedName)
                    if let responsibleName = deadline.responsibleName, !responsibleName.isEmpty {
                        writer.keyValue("Ansvarig", value: responsibleName)
                    }
                    writer.spacing(6)
                }
            }

            writer.section("Finansiell ögonblicksbild")
            if input.financialMetrics.isEmpty {
                writer.text("Inga finansiella värden är registrerade.", style: .secondary)
            } else {
                for metric in input.financialMetrics {
                    writer.subheading(metric.title)
                    writer.keyValue(
                        "Värde",
                        value: metric.amount.formatted(.currency(code: metric.currencyCode))
                    )
                    writer.text(
                        "\(metric.valueState.localizedName) · \(metric.sourceName) · \(metric.sourceUpdatedAt.formatted(date: .abbreviated, time: .shortened))",
                        style: .secondary
                    )
                    writer.spacing(6)
                }
            }

            writer.section("Källor och avgränsning")
            writer.keyValue("Bolagskälla", value: input.sourceName)
            writer.keyValue(
                "Källan uppdaterad",
                value: input.sourceUpdatedAt.formatted(date: .long, time: .shortened)
            )
            if let lastSynchronizedAt = input.lastSynchronizedAt {
                writer.keyValue(
                    "Senast synkroniserad",
                    value: lastSynchronizedAt.formatted(date: .long, time: .shortened)
                )
            }
            writer.text(
                "Översikten återger uppgifter registrerade eller synkroniserade i NorthBridge. Den ersätter inte bolagets originalhandlingar och utgör inte juridisk, redovisnings- eller skatterådgivning.",
                style: .secondary
            )
            writer.finish()
        }

        try secureAndValidate(fileURL)
        return fileURL
    }

    private static func makeRenderer(title: String, author: String) -> UIGraphicsPDFRenderer {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextAuthor as String: author,
            kCGPDFContextCreator as String: "NorthBridge"
        ]
        return UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize),
            format: format
        )
    }

    private static func outputURL(companyID: UUID, filename: String) throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root
            .appending(path: "GeneratedDocuments", directoryHint: .isDirectory)
            .appending(path: companyID.uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        return directory.appending(path: filename)
    }

    private static func secureAndValidate(_ fileURL: URL) throws {
        do {
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            throw GovernancePDFExportError.unableToProtectFile
        }

        guard let document = PDFDocument(url: fileURL), document.pageCount > 0 else {
            try? FileManager.default.removeItem(at: fileURL)
            throw GovernancePDFExportError.invalidDocument
        }
    }

    private static func safeFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.lowercased().unicodeScalars.map {
            allowed.contains($0) ? Character(String($0)) : "-"
        }
        let result = String(scalars)
        return result.isEmpty ? UUID().uuidString.lowercased() : result
    }

    private static func uniqueFilename(stem: String) -> String {
        "\(stem)-\(UUID().uuidString.lowercased()).pdf"
    }

    private static func formattedOrganisationNumber(_ digits: String) -> String {
        (try? OrganisationNumber(digits).formatted) ?? digits
    }
}

@MainActor
private struct PDFPageWriter {
    enum TextStyle {
        case body
        case secondary
    }

    private let context: UIGraphicsPDFRendererContext
    private let documentTitle: String
    private var cursorY: CGFloat = 0
    private var pageNumber = 0

    init(context: UIGraphicsPDFRendererContext, title: String) {
        self.context = context
        documentTitle = title
    }

    mutating func startPage() {
        context.beginPage()
        pageNumber += 1
        cursorY = GovernancePDFExporter.pageMargins.top
        drawPageHeader()
    }

    mutating func heading(_ value: String, size: CGFloat) {
        draw(value, font: .systemFont(ofSize: size, weight: .bold), color: .label, spacingAfter: 6)
    }

    mutating func section(_ value: String) {
        ensureSpace(54)
        spacing(18)
        draw(value, font: .systemFont(ofSize: 15, weight: .bold), color: .label, spacingAfter: 7)
    }

    mutating func subheading(_ value: String) {
        ensureSpace(44)
        draw(value, font: .systemFont(ofSize: 12, weight: .semibold), color: .label, spacingAfter: 4)
    }

    mutating func text(_ value: String, style: TextStyle = .body) {
        let color: UIColor = style == .secondary ? .secondaryLabel : .label
        draw(value, font: .systemFont(ofSize: 10.5), color: color, spacingAfter: 5)
    }

    mutating func bullet(_ value: String) {
        draw("•  \(value)", font: .systemFont(ofSize: 10.5), color: .label, spacingAfter: 4)
    }

    mutating func keyValue(_ key: String, value: String) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 4
        let attributed = NSMutableAttributedString(
            string: "\(key): ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 10.5, weight: .semibold),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph
            ]
        )
        attributed.append(
            NSAttributedString(
                string: value,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 10.5),
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: paragraph
                ]
            )
        )
        draw(attributed, spacingAfter: 4)
    }

    mutating func rule() {
        ensureSpace(20)
        spacing(10)
        let width = GovernancePDFExporter.pageSize.width
            - GovernancePDFExporter.pageMargins.left
            - GovernancePDFExporter.pageMargins.right
        let path = UIBezierPath()
        path.move(to: CGPoint(x: GovernancePDFExporter.pageMargins.left, y: cursorY))
        path.addLine(to: CGPoint(x: GovernancePDFExporter.pageMargins.left + width, y: cursorY))
        UIColor.systemBlue.withAlphaComponent(0.55).setStroke()
        path.lineWidth = 1
        path.stroke()
        spacing(12)
    }

    mutating func signatureLine(_ label: String) {
        ensureSpace(66)
        spacing(26)
        let width: CGFloat = 210
        let path = UIBezierPath()
        path.move(to: CGPoint(x: GovernancePDFExporter.pageMargins.left, y: cursorY))
        path.addLine(to: CGPoint(x: GovernancePDFExporter.pageMargins.left + width, y: cursorY))
        UIColor.secondaryLabel.setStroke()
        path.lineWidth = 0.7
        path.stroke()
        spacing(5)
        text(label, style: .secondary)
    }

    mutating func spacing(_ points: CGFloat) {
        cursorY += points
    }

    mutating func finish() {
        drawFooter()
    }

    private mutating func draw(
        _ value: String,
        font: UIFont,
        color: UIColor,
        spacingAfter: CGFloat
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2
        draw(
            NSAttributedString(
                string: value,
                attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph
                ]
            ),
            spacingAfter: spacingAfter
        )
    }

    private mutating func draw(_ attributed: NSAttributedString, spacingAfter: CGFloat) {
        let width = GovernancePDFExporter.pageSize.width
            - GovernancePDFExporter.pageMargins.left
            - GovernancePDFExporter.pageMargins.right
        let constraint = CGSize(width: width, height: .greatestFiniteMagnitude)
        let rect = attributed.boundingRect(
            with: constraint,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        ensureSpace(rect.height + spacingAfter)
        attributed.draw(
            with: CGRect(
                x: GovernancePDFExporter.pageMargins.left,
                y: cursorY,
                width: width,
                height: ceil(rect.height)
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        cursorY += ceil(rect.height) + spacingAfter
    }

    private mutating func ensureSpace(_ height: CGFloat) {
        let limit = GovernancePDFExporter.pageSize.height - GovernancePDFExporter.pageMargins.bottom - 24
        guard cursorY + height > limit else { return }
        drawFooter()
        startPage()
    }

    private mutating func drawPageHeader() {
        let text = NSAttributedString(
            string: documentTitle,
            attributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        text.draw(at: CGPoint(x: GovernancePDFExporter.pageMargins.left, y: 28))
    }

    private func drawFooter() {
        let text = "NorthBridge · Sida \(pageNumber)"
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        attributed.draw(
            at: CGPoint(
                x: GovernancePDFExporter.pageMargins.left,
                y: GovernancePDFExporter.pageSize.height - 32
            )
        )
    }
}
