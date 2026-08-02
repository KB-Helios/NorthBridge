import SwiftUI

private struct NorthBridgeLiquidSwipeRevealModifier: AnimatableModifier {
    var progress: CGFloat
    let edge: HorizontalEdge

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.mask {
            NorthBridgeLiquidSwipeShape(progress: progress, edge: edge)
        }
    }
}

extension AnyTransition {
    static func northBridgeLiquidSwipe(from edge: HorizontalEdge) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: NorthBridgeLiquidSwipeRevealModifier(progress: 0, edge: edge),
                identity: NorthBridgeLiquidSwipeRevealModifier(progress: 1, edge: edge)
            ),
            removal: .opacity
        )
    }

    static func northBridgeReducedMotion(from edge: HorizontalEdge) -> AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: edge.northBridgeNavigationEdge)),
            removal: .opacity
        )
    }
}

extension HorizontalEdge {
    var northBridgeNavigationEdge: Edge {
        switch self {
        case .leading: .leading
        case .trailing: .trailing
        }
    }
}
