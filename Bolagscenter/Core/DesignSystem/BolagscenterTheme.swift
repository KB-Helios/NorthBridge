import SwiftUI

extension Color {
    static let northBridgeBlue = Color(red: 0.03, green: 0.34, blue: 0.88)
    static let northBridgeNavy = Color(red: 0.01, green: 0.08, blue: 0.22)
    static let bolagscenterBlue = northBridgeBlue
    static let appBackground = Color(uiColor: .systemGroupedBackground)
    static let appSurface = Color(uiColor: .secondarySystemGroupedBackground)
    static let graphite = Color(red: 0.12, green: 0.13, blue: 0.15)
}

struct NorthBridgeBrandLockup: View {
    var maxWidth: CGFloat = 360

    var body: some View {
        Image("NorthBridgeWordmark")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: maxWidth)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .accessibilityLabel("NorthBridge")
    }
}

struct LiquidGlassEffectGroup<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(
        spacing: CGFloat = 20,
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
        cornerRadius: CGFloat = 18,
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
}

enum AppSpacing {
    static let compact: CGFloat = 8
    static let standard: CGFloat = 16
    static let section: CGFloat = 24
}

struct StatusBadge: View {
    let text: String
    let kind: Kind

    enum Kind {
        case neutral
        case positive
        case warning
        case critical

        var color: Color {
            switch self {
            case .neutral: .secondary
            case .positive: .green
            case .warning: .orange
            case .critical: .red
            }
        }
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(kind.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(kind.color.opacity(0.12), in: Capsule())
            .accessibilityLabel(text)
    }
}

struct SectionHeading: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
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
    }
}

struct SourceFooter: View {
    let source: String
    let updatedAt: Date
    var stale = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: stale ? "clock.badge.exclamationmark" : "checkmark.seal")
            Text("Källa: \(source) · \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        .font(.caption)
        .foregroundStyle(stale ? Color.orange : Color.secondary)
        .accessibilityElement(children: .combine)
    }
}
