import SwiftUI

/// A compact, owned wave mask used only for major onboarding transitions.
/// Concept attribution: Exyte's MIT-licensed LiquidSwipe example
/// (https://github.com/exyte/LiquidSwipe). This path implementation is an
/// independent NorthBridge design and does not use its sampled point table,
/// drag architecture, or source code.
struct NorthBridgeLiquidSwipeShape: Shape {
    var progress: CGFloat
    let edge: HorizontalEdge

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clampedProgress = min(max(progress, 0), 1)
        let revealedWidth = rect.width * clampedProgress
        let waveStrength = sin(clampedProgress * .pi)
        let waveDepth = min(46, rect.width * 0.11) * waveStrength
        let midpoint = rect.midY
        let upperControlY = rect.minY + (rect.height * 0.24)
        let lowerControlY = rect.maxY - (rect.height * 0.24)

        var path = Path()
        switch edge {
        case .trailing:
            let boundaryX = rect.maxX - revealedWidth
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: boundaryX, y: rect.maxY))
            path.addCurve(
                to: CGPoint(x: boundaryX - waveDepth, y: midpoint),
                control1: CGPoint(x: boundaryX, y: lowerControlY),
                control2: CGPoint(x: boundaryX - waveDepth, y: midpoint + rect.height * 0.14)
            )
            path.addCurve(
                to: CGPoint(x: boundaryX, y: rect.minY),
                control1: CGPoint(x: boundaryX - waveDepth, y: midpoint - rect.height * 0.14),
                control2: CGPoint(x: boundaryX, y: upperControlY)
            )
        case .leading:
            let boundaryX = rect.minX + revealedWidth
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: boundaryX, y: rect.maxY))
            path.addCurve(
                to: CGPoint(x: boundaryX + waveDepth, y: midpoint),
                control1: CGPoint(x: boundaryX, y: lowerControlY),
                control2: CGPoint(x: boundaryX + waveDepth, y: midpoint + rect.height * 0.14)
            )
            path.addCurve(
                to: CGPoint(x: boundaryX, y: rect.minY),
                control1: CGPoint(x: boundaryX + waveDepth, y: midpoint - rect.height * 0.14),
                control2: CGPoint(x: boundaryX, y: upperControlY)
            )
        }
        path.closeSubpath()
        return path
    }
}
