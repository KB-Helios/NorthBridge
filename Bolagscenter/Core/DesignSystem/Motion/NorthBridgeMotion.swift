import SwiftUI

enum NorthBridgeMotion {
    static let liquidSwipeDuration: TimeInterval = 0.46
    static let reducedMotionDuration: TimeInterval = 0.18

    static var liquidSwipe: Animation {
        .smooth(duration: liquidSwipeDuration)
    }

    static var reduced: Animation {
        .easeOut(duration: reducedMotionDuration)
    }

    static var selection: Animation {
        .snappy(duration: 0.24)
    }
}
