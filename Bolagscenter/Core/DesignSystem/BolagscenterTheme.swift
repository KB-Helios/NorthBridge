import SwiftUI

// MARK: - Semantic color roles

extension Color {
    static let northBridgeBlue = Color(red: 0.03, green: 0.34, blue: 0.88)
    static let northBridgeNavy = Color(red: 0.01, green: 0.08, blue: 0.22)
    static let northBridgeCyan = Color(red: 0.11, green: 0.72, blue: 0.92)

    static let northBridgeBackground = Color(uiColor: .systemGroupedBackground)
    static let northBridgeSurface = Color(uiColor: .secondarySystemGroupedBackground)
    static let northBridgeRaisedSurface = Color(uiColor: .systemBackground)
    static let northBridgeRecessedSurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let northBridgeGlassTint = northBridgeBlue.opacity(0.08)

    static let northBridgeTextPrimary = Color.primary
    static let northBridgeTextSecondary = Color.secondary
    static let northBridgeTextTertiary = Color(uiColor: .tertiaryLabel)

    static let northBridgePositive = Color(uiColor: .systemGreen)
    static let northBridgeWarning = Color(uiColor: .systemOrange)
    static let northBridgeCritical = Color(uiColor: .systemRed)
    static let northBridgeInformational = Color(uiColor: .systemCyan)
    static let northBridgeHairline = Color(uiColor: .separator).opacity(0.48)
    static let northBridgeSeparator = Color(uiColor: .separator)

    // Compatibility roles retained while feature screens move to semantic names.
    static let bolagscenterBlue = northBridgeBlue
    static let appBackground = northBridgeBackground
    static let appSurface = northBridgeSurface
    static let graphite = Color(red: 0.12, green: 0.13, blue: 0.15)
}

// MARK: - Layout and type tokens

enum NorthBridgeSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let huge: CGFloat = 40
}

enum NorthBridgeRadius {
    static let control: CGFloat = 12
    static let card: CGFloat = 18
    static let hero: CGFloat = 26
    static let sheet: CGFloat = 30
}

enum NorthBridgeTypography {
    static let screenTitle = Font.largeTitle.weight(.bold)
    static let sectionTitle = Font.title3.weight(.semibold)
    static let cardTitle = Font.headline
    static let body = Font.body
    static let caption = Font.caption
    static let financialFigure = Font.system(.title, design: .rounded, weight: .bold).monospacedDigit()
    static let compactFigure = Font.system(.headline, design: .rounded, weight: .semibold).monospacedDigit()
}

struct NorthBridgeElevation: Sendable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let card = NorthBridgeElevation(
        color: .black.opacity(0.07),
        radius: 18,
        x: 0,
        y: 8
    )
    static let floating = NorthBridgeElevation(
        color: .black.opacity(0.12),
        radius: 28,
        x: 0,
        y: 14
    )
}

enum NorthBridgeMetrics {
    static let minimumTarget: CGFloat = 44
    static let readableContentWidth: CGFloat = 760
    static let wideContentWidth: CGFloat = 1_080
}

// Compatibility spacing used by existing feature views.
enum AppSpacing {
    static let compact = NorthBridgeSpacing.sm
    static let standard = NorthBridgeSpacing.lg
    static let section = NorthBridgeSpacing.xxl
}

// MARK: - Brand and surfaces

struct NorthBridgeBrandLockup: View {
    var maxWidth: CGFloat = 360

    var body: some View {
        Image("NorthBridgeWordmark")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: maxWidth)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: NorthBridgeRadius.hero,
                    style: .continuous
                )
            )
            .accessibilityLabel("NorthBridge")
    }
}

struct LiquidGlassEffectGroup<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(
        spacing: CGFloat = NorthBridgeSpacing.xl,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    @ViewBuilder
    func bolagscenterGlassSurface(
        cornerRadius: CGFloat = NorthBridgeRadius.card,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                glassEffect(
                    .regular
                        .tint(tint)
                        .interactive(interactive),
                    in: .rect(cornerRadius: cornerRadius)
                )
            } else {
                glassEffect(
                    .regular.interactive(interactive),
                    in: .rect(cornerRadius: cornerRadius)
                )
            }
        } else {
            background(
                .ultraThinMaterial,
                in: RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
        }
    }

    @ViewBuilder
    func bolagscenterGlassCircle(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                glassEffect(
                    .regular
                        .tint(tint)
                        .interactive(interactive),
                    in: .circle
                )
            } else {
                glassEffect(
                    .regular.interactive(interactive),
                    in: .circle
                )
            }
        } else {
            background(.ultraThinMaterial, in: Circle())
        }
    }

    func northBridgeCardSurface(
        radius: CGFloat = NorthBridgeRadius.card,
        elevation: NorthBridgeElevation = .card
    ) -> some View {
        background(
            Color.northBridgeRaisedSurface,
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.northBridgeHairline, lineWidth: 0.5)
        }
        .shadow(
            color: elevation.color,
            radius: elevation.radius,
            x: elevation.x,
            y: elevation.y
        )
    }
}

// MARK: - Compatibility components

struct StatusBadge: View {
    let text: String
    let kind: Kind

    enum Kind {
        case neutral
        case positive
        case warning
        case critical

        var statusKind: NorthBridgeStatusKind {
            switch self {
            case .neutral: .neutral
            case .positive: .positive
            case .warning: .warning
            case .critical: .critical
            }
        }
    }

    var body: some View {
        NorthBridgeStatusPill(text, kind: kind.statusKind)
    }
}

struct SectionHeading: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        NorthBridgeSectionHeader(
            title,
            actionTitle: actionTitle,
            action: action
        )
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        NorthBridgeEmptyState(
            systemImage: systemImage,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
    }
}

struct SourceFooter: View {
    let source: String
    let updatedAt: Date
    var stale = false

    var body: some View {
        HStack(spacing: NorthBridgeSpacing.sm) {
            Image(systemName: stale ? "clock.badge.exclamationmark" : "checkmark.seal")
            Text(
                "Källa: \(source) · \(updatedAt.formatted(date: .abbreviated, time: .shortened))"
            )
        }
        .font(NorthBridgeTypography.caption)
        .foregroundStyle(stale ? Color.northBridgeWarning : Color.northBridgeTextSecondary)
        .accessibilityElement(children: .combine)
    }
}
