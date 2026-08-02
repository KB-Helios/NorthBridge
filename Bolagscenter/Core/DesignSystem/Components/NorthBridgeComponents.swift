import Foundation
import SwiftUI

enum NorthBridgeStatusKind: Sendable {
    case neutral
    case positive
    case warning
    case critical
    case informational

    var color: Color {
        switch self {
        case .neutral:
            .secondary
        case .positive:
            .northBridgePositive
        case .warning:
            .northBridgeWarning
        case .critical:
            .northBridgeCritical
        case .informational:
            .northBridgeInformational
        }
    }

    var systemImage: String {
        switch self {
        case .neutral:
            "circle.fill"
        case .positive:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .critical:
            "exclamationmark.octagon.fill"
        case .informational:
            "info.circle.fill"
        }
    }
}

struct NorthBridgeScreen<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let horizontalPadding: CGFloat
    let contentSpacing: CGFloat
    let showsScrollIndicators: Bool
    private let content: Content

    init(
        horizontalPadding: CGFloat = NorthBridgeSpacing.lg,
        contentSpacing: CGFloat = NorthBridgeSpacing.xxl,
        showsScrollIndicators: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalPadding = horizontalPadding
        self.contentSpacing = contentSpacing
        self.showsScrollIndicators = showsScrollIndicators
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: showsScrollIndicators) {
            LazyVStack(alignment: .leading, spacing: contentSpacing) {
                content
            }
            .frame(maxWidth: NorthBridgeMetrics.wideContentWidth, alignment: .leading)
            .padding(.horizontal, resolvedHorizontalPadding)
            .padding(.top, NorthBridgeSpacing.lg)
            .padding(.bottom, NorthBridgeSpacing.huge)
            .frame(maxWidth: .infinity)
        }
        .background(Color.northBridgeBackground.ignoresSafeArea())
    }

    private var resolvedHorizontalPadding: CGFloat {
        horizontalSizeClass == .regular
            ? max(horizontalPadding, NorthBridgeSpacing.xxl)
            : horizontalPadding
    }
}

struct NorthBridgeCompanyHero<Accessory: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let companyName: String
    let organisationNumber: String?
    let role: String?
    let status: NorthBridgeStatusKind
    let statusText: String
    let freshness: String?
    private let accessory: Accessory

    init(
        companyName: String,
        organisationNumber: String? = nil,
        role: String? = nil,
        status: NorthBridgeStatusKind = .neutral,
        statusText: String,
        freshness: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.companyName = companyName
        self.organisationNumber = organisationNumber
        self.role = role
        self.status = status
        self.statusText = statusText
        self.freshness = freshness
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.xl) {
            HStack(alignment: .top, spacing: NorthBridgeSpacing.lg) {
                VStack(alignment: .leading, spacing: NorthBridgeSpacing.sm) {
                    Text(companyName)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if let organisationNumber {
                        Text(organisationNumber)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                accessory
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: NorthBridgeSpacing.md) {
                    heroMetadata
                }
                VStack(alignment: .leading, spacing: NorthBridgeSpacing.sm) {
                    heroMetadata
                }
            }
        }
        .padding(NorthBridgeSpacing.xxl)
        .background { heroBackground }
        .clipShape(
            RoundedRectangle(
                cornerRadius: NorthBridgeRadius.hero,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: NorthBridgeRadius.hero,
                style: .continuous
            )
            .stroke(.white.opacity(0.14), lineWidth: 0.5)
        }
        .shadow(
            color: NorthBridgeElevation.floating.color,
            radius: NorthBridgeElevation.floating.radius,
            x: NorthBridgeElevation.floating.x,
            y: NorthBridgeElevation.floating.y
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var heroMetadata: some View {
        NorthBridgeStatusPill(statusText, kind: status, highContrast: true)
        if let role {
            Label(role, systemImage: "person.crop.circle.badge.checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        if let freshness {
            Label(freshness, systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    @ViewBuilder
    private var heroBackground: some View {
        if #available(iOS 26.0, *), !reduceMotion, !reduceTransparency {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2<Float>(0, 0), SIMD2<Float>(0.5, 0), SIMD2<Float>(1, 0),
                    SIMD2<Float>(0, 0.5), SIMD2<Float>(0.52, 0.46), SIMD2<Float>(1, 0.5),
                    SIMD2<Float>(0, 1), SIMD2<Float>(0.5, 1), SIMD2<Float>(1, 1)
                ],
                colors: [
                    .northBridgeNavy, .northBridgeNavy, .northBridgeBlue,
                    .northBridgeNavy, .northBridgeBlue, .northBridgeCyan.opacity(0.72),
                    .northBridgeNavy, .northBridgeBlue.opacity(0.9), .northBridgeNavy
                ],
                smoothsColors: true
            )
        } else {
            LinearGradient(
                colors: [
                    Color.northBridgeNavy,
                    Color.northBridgeBlue.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

extension NorthBridgeCompanyHero where Accessory == EmptyView {
    init(
        companyName: String,
        organisationNumber: String? = nil,
        role: String? = nil,
        status: NorthBridgeStatusKind = .neutral,
        statusText: String,
        freshness: String? = nil
    ) {
        self.init(
            companyName: companyName,
            organisationNumber: organisationNumber,
            role: role,
            status: status,
            statusText: statusText,
            freshness: freshness
        ) {
            EmptyView()
        }
    }
}

struct NorthBridgeMetricTile: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    let tint: Color
    let footnote: String?

    init(
        title: LocalizedStringKey,
        value: String,
        systemImage: String,
        tint: Color = .northBridgeBlue,
        footnote: String? = nil
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
        self.footnote = footnote
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(NorthBridgeTypography.compactFigure)
                .foregroundStyle(Color.northBridgeTextPrimary)
                .contentTransition(.numericText())
                .fixedSize(horizontal: false, vertical: true)

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(Color.northBridgeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NorthBridgeSpacing.lg)
        .northBridgeCardSurface()
        .accessibilityElement(children: .combine)
    }
}

struct NorthBridgeActionCard: View {
    let title: LocalizedStringKey
    let detail: String
    let systemImage: String
    let actionTitle: LocalizedStringKey
    let action: () -> Void

    init(
        title: LocalizedStringKey,
        detail: String,
        systemImage: String,
        actionTitle: LocalizedStringKey,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.lg) {
            HStack(alignment: .top, spacing: NorthBridgeSpacing.md) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.northBridgeBlue)
                    .frame(
                        width: NorthBridgeMetrics.minimumTarget,
                        height: NorthBridgeMetrics.minimumTarget
                    )
                    .background(Color.northBridgeBlue.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                    Text(title)
                        .font(NorthBridgeTypography.cardTitle)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.northBridgeTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(NorthBridgeSpacing.xl)
        .northBridgeCardSurface()
    }
}

struct NorthBridgeCommandCard: View {
    let title: LocalizedStringKey
    let detail: String
    let systemImage: String
    let tint: Color
    let badge: String?

    init(
        title: LocalizedStringKey,
        detail: String,
        systemImage: String,
        tint: Color = .northBridgeBlue,
        badge: String? = nil
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.tint = tint
        self.badge = badge
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            HStack(alignment: .center) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(
                        width: NorthBridgeMetrics.minimumTarget,
                        height: NorthBridgeMetrics.minimumTarget
                    )
                    .background(tint.opacity(0.1), in: Circle())
                Spacer(minLength: NorthBridgeSpacing.sm)
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, NorthBridgeSpacing.sm)
                        .padding(.vertical, NorthBridgeSpacing.xs)
                        .background(tint.opacity(0.1), in: Capsule())
                }
            }

            Text(title)
                .font(NorthBridgeTypography.cardTitle)
                .foregroundStyle(Color.northBridgeTextPrimary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.northBridgeTextSecondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NorthBridgeSpacing.lg)
        .northBridgeCardSurface()
        .contentShape(
            RoundedRectangle(
                cornerRadius: NorthBridgeRadius.card,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
    }
}

struct NorthBridgeSectionHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: NorthBridgeSpacing.md) {
            VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                Text(title)
                    .font(NorthBridgeTypography.sectionTitle)
                    .foregroundStyle(Color.northBridgeTextPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.northBridgeTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: NorthBridgeMetrics.minimumTarget)
            }
        }
    }
}

struct NorthBridgeFilterChip: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let isSelected: Bool
    let count: Int?
    let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        isSelected: Bool,
        count: Int? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.count = count
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: NorthBridgeSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                if let count {
                    Text(count, format: .number)
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.primary.opacity(0.08), in: Capsule())
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.northBridgeTextPrimary)
            .padding(.horizontal, NorthBridgeSpacing.md)
            .frame(minHeight: NorthBridgeMetrics.minimumTarget)
            .background(
                isSelected ? Color.northBridgeBlue : Color.northBridgeSurface,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : Color.northBridgeHairline,
                        lineWidth: 0.5
                    )
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct NorthBridgeStatusPill: View {
    let text: String
    let kind: NorthBridgeStatusKind
    let highContrast: Bool

    init(
        _ text: String,
        kind: NorthBridgeStatusKind,
        highContrast: Bool = false
    ) {
        self.text = text
        self.kind = kind
        self.highContrast = highContrast
    }

    var body: some View {
        Label(text, systemImage: kind.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(highContrast ? Color.white : kind.color)
            .padding(.horizontal, NorthBridgeSpacing.sm)
            .padding(.vertical, 6)
            .background(
                highContrast ? Color.white.opacity(0.14) : kind.color.opacity(0.11),
                in: Capsule()
            )
            .overlay {
                if highContrast {
                    Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5)
                }
            }
            .accessibilityElement(children: .combine)
    }
}

struct NorthBridgeTimelineRow: View {
    let systemImage: String
    let tint: Color
    let title: String
    let detail: String?
    let timestamp: String?
    let isLast: Bool

    init(
        systemImage: String,
        tint: Color = .northBridgeInformational,
        title: String,
        detail: String? = nil,
        timestamp: String? = nil,
        isLast: Bool = false
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self.detail = detail
        self.timestamp = timestamp
        self.isLast = isLast
    }

    var body: some View {
        HStack(alignment: .top, spacing: NorthBridgeSpacing.md) {
            VStack(spacing: 0) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.11), in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(Color.northBridgeHairline)
                        .frame(width: 1)
                        .frame(minHeight: NorthBridgeSpacing.xxl)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: NorthBridgeSpacing.sm) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.northBridgeTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let timestamp {
                        Text(timestamp)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.northBridgeTextTertiary)
                    }
                }
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.northBridgeTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, isLast ? 0 : NorthBridgeSpacing.lg)
        }
        .accessibilityElement(children: .combine)
    }
}

struct NorthBridgeSettingsRow: View {
    let title: LocalizedStringKey
    let subtitle: String?
    let systemImage: String
    let tint: Color
    let value: String?
    let showsChevron: Bool

    init(
        _ title: LocalizedStringKey,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color = .northBridgeBlue,
        value: String? = nil,
        showsChevron: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.value = value
        self.showsChevron = showsChevron
    }

    var body: some View {
        HStack(spacing: NorthBridgeSpacing.md) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.northBridgeTextPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.northBridgeTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Color.northBridgeTextSecondary)
            }
            if showsChevron {
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.northBridgeTextTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: NorthBridgeMetrics.minimumTarget)
        .contentShape(Rectangle())
    }
}

struct NorthBridgeEmptyState: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let compact: Bool
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    init(
        systemImage: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        compact: Bool = false,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.compact = compact
        self.actionTitle = actionTitle
        self.action = action
    }

    @ViewBuilder
    var body: some View {
        if compact {
            compactBody
        } else {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                Text(message)
            } actions: {
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(NorthBridgeSpacing.xl)
        }
    }

    private var compactBody: some View {
        HStack(alignment: .top, spacing: NorthBridgeSpacing.md) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.northBridgeBlue)
                .frame(
                    width: NorthBridgeMetrics.minimumTarget,
                    height: NorthBridgeMetrics.minimumTarget
                )
                .background(Color.northBridgeBlue.opacity(0.1), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.northBridgeTextSecondary)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: NorthBridgeMetrics.minimumTarget)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(NorthBridgeSpacing.lg)
        .northBridgeCardSurface()
        .accessibilityElement(children: .contain)
    }
}

struct NorthBridgeGlassIconButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    let accessibilityIdentifier: String?
    let action: () -> Void

    init(
        systemImage: String,
        accessibilityLabel: LocalizedStringKey,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            control.buttonStyle(.glass)
        } else {
            control.buttonStyle(.bordered)
        }
    }

    private var control: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(
                    minWidth: NorthBridgeMetrics.minimumTarget,
                    minHeight: NorthBridgeMetrics.minimumTarget
                )
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct NorthBridgeCompanyContext: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
}

struct CompanyContextMenu: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let companies: [NorthBridgeCompanyContext]
    let selectedCompanyID: UUID?
    let canAddCompany: Bool
    let prefersCompactLabel: Bool
    let onSelect: (UUID) -> Void
    let onAddCompany: () -> Void

    private var selectedCompany: NorthBridgeCompanyContext? {
        companies.first { $0.id == selectedCompanyID }
    }

    var body: some View {
        Menu {
            if companies.isEmpty {
                Text("Inga tillgängliga bolag")
            } else {
                ForEach(companies) { company in
                    Button {
                        onSelect(company.id)
                    } label: {
                        if selectedCompanyID == company.id {
                            Label(company.name, systemImage: "checkmark")
                        } else {
                            Text(company.name)
                        }
                    }
                }
            }

            Divider()

            Button(action: onAddCompany) {
                Label(
                    canAddCompany ? "Lägg till bolag" : "Uppgradera för fler bolag",
                    systemImage: canAddCompany ? "plus.circle" : "creditcard"
                )
            }
        } label: {
            HStack(spacing: NorthBridgeSpacing.xs) {
                Image(systemName: "building.2.fill")
                    .foregroundStyle(Color.northBridgeBlue)
                if !usesCompactToolbarLabel {
                    Text(selectedCompany?.name ?? String(localized: "Välj bolag"))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.northBridgeTextTertiary)
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: NorthBridgeMetrics.minimumTarget)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("company.switcher")
        .accessibilityLabel("Aktivt bolag")
        .accessibilityValue(selectedCompany?.name ?? String(localized: "Inget bolag valt"))
        .accessibilityHint("Öppnar menyn för att byta bolag")
    }

    private var usesCompactToolbarLabel: Bool {
        prefersCompactLabel
            || dynamicTypeSize.isAccessibilitySize
    }
}

#Preview("Components") {
    NorthBridgeScreen {
        NorthBridgeCompanyHero(
            companyName: "NorthBridge Demo AB",
            organisationNumber: "559123-4567",
            role: "Administratör",
            status: .positive,
            statusText: "Aktivt",
            freshness: "Synkat nyss"
        )

        NorthBridgeSectionHeader(
            "Bolagsöversikt",
            subtitle: "Det viktigaste just nu"
        )

        HStack(alignment: .top, spacing: NorthBridgeSpacing.md) {
            NorthBridgeMetricTile(
                title: "Likviditet",
                value: "1 240 000 kr",
                systemImage: "banknote",
                footnote: "Uppdaterad idag"
            )
            NorthBridgeMetricTile(
                title: "Öppna åtgärder",
                value: "3",
                systemImage: "checklist",
                tint: .northBridgeWarning,
                footnote: "En förfaller snart"
            )
        }
    }
}

#Preview("Warning and empty") {
    VStack(spacing: NorthBridgeSpacing.xxl) {
        NorthBridgeStatusPill("Kräver åtgärd", kind: .warning)
        NorthBridgeEmptyState(
            systemImage: "checkmark.seal",
            title: "Allt är i ordning",
            message: "Inga öppna åtgärder eller varningar just nu.",
            compact: true
        )
    }
    .padding()
    .background(Color.northBridgeBackground)
}

#Preview("Dark") {
    NorthBridgeScreen {
        NorthBridgeCompanyHero(
            companyName: "Norra Kommanditbolaget",
            role: "Styrelseledamot",
            status: .warning,
            statusText: "Granska uppgifter",
            freshness: "Synkat igår"
        )
        NorthBridgeCommandCard(
            title: "Deadlines",
            detail: "Två kommande bolagshändelser",
            systemImage: "calendar.badge.clock",
            tint: .northBridgeWarning,
            badge: "2"
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Accessibility text") {
    NorthBridgeEmptyState(
        systemImage: "doc.text.magnifyingglass",
        title: "Inga dokument hittades",
        message: "Prova ett annat filter eller importera ett dokument.",
        compact: true,
        actionTitle: "Importera"
    ) {}
    .padding()
    .environment(\.dynamicTypeSize, .accessibility3)
}
