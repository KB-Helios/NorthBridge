# iOS 27 readiness

NorthBridge is written in Swift 6 language mode with complete strict-concurrency
checking. The deployment target remains iOS 26 so a single binary can support
both iOS 26 and iOS 27.

## Already applied

- `UILaunchScreen` is present. This is required for apps built with the iOS 27
  SDK.
- iPad declares portrait, upside-down portrait, landscape left, and landscape
  right so the app remains continuously resizable on iOS 27.
- The app does not use deprecated `UIApplication` status-bar accessors.
- SwiftUI owns navigation, presentation, safe areas, Dynamic Type, and system
  materials so the refreshed iOS 27 appearance is adopted without hard-coded
  UIKit geometry.
- Critical document export uses `topBarPinnedTrailing` when compiled with
  Swift 6.4 / the iOS 27 SDK and retains the iOS 26 toolbar placement otherwise.
- All new asynchronous services are checked under Swift 6 strict concurrency.
- The generated project declares Xcode 27 compatibility. The current validation
  host is macOS 27 with Xcode 27, Swift 6.4, and iOS 27/26.5 simulator runtimes.
- Native Liquid Glass is centralized behind reusable availability-checked
  surfaces. Dense tables and document content intentionally remain opaque.
- A production 1024-by-1024 app icon is wired through the asset catalog.

## Automated beta validation complete

The final source was regenerated with XcodeGen 2.46 and validated on macOS 27,
Xcode 27 beta 4, and Swift 6.4:

- iPhone 17 Pro, iOS 27.0: **84 of 84 tests passed**, with zero failures,
  skips, expected failures, or runtime warnings.
- iPhone 17 Pro, iOS 26.5: **84 of 84 tests passed**, with zero failures,
  skips, expected failures, or runtime warnings.
- The warning-free Release simulator app was installed and launched on the
  iOS 27 iPhone 17 Pro simulator.
- A Release arm64 device archive was produced with bundle identifier
  `com.kbhelios.northbridge` and deployment target iOS 26.0.

The UI suite covers onboarding, company creation and switching, meeting and
decision creation, document import, shareholder and share-certificate flows,
offline and expired-session states, portable-data and PDF exports,
accessibility, and largest Dynamic Type.

## Physical-device acceptance pending

A paid Apple Developer team must sign the archive before it can run on a stock
iPhone. After signing, verify sign-in, app lock, camera scanning, document
import/export, notifications, widgets, App Intents, StoreKit, background
refresh, rotation, Dynamic Type, dark mode, and VoiceOver on the user's iPhone
17 Pro running the iOS 27 beta. Exact artifact and signing instructions are in
`dist/README.md`.

iOS 27 APIs are beta and must be revalidated against each Xcode/iOS seed and the
final SDK before App Store release.
