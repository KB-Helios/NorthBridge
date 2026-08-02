# NorthBridge 0.2.0

NorthBridge 0.2.0 redesigns the app as a calm, native command center for
Swedish limited companies while preserving the existing production data,
security, export, and offline boundaries.

## Highlights

- Five native workspaces: Overview, Finance, Company, Documents, and Search.
- Semantic color, typography, spacing, shape, shadow, material, and motion
  tokens shared across the app.
- Selective iOS Liquid Glass for navigation and high-value controls, with
  opaque content surfaces retained for legibility.
- Responsive phone and iPad layouts, light and dark appearance, comfortable or
  compact dashboard density, financial privacy blur, and list/grid document
  preferences.
- Four onboarding chapters and ten guided steps with an owned, reduced-motion
  aware liquid-swipe transition.
- Deterministic visual coverage for the core workspaces, healthy-empty data,
  activity, settings, dark mode, largest Dynamic Type, and onboarding motion.

## Verification

- Xcode 27 beta 4, Swift 6.4, XcodeGen 2.46.0, and Pow 1.0.6.
- iPhone 17 Pro / iOS 27.0: 91 of 91 tests passed; zero runtime warnings.
- iPhone 17 Pro / iOS 26.5: 91 of 91 tests passed; zero runtime warnings.
- iPad mini (A17 Pro) / iOS 27.0: adaptive primary-workspace and settings flow
  passed; zero runtime warnings.

## Distribution boundary

The attached IPA is an unsigned development handoff produced without an Apple
Developer certificate or provisioning profile. It is not installable on a
stock iPhone until it is signed by the intended Apple Developer team. Camera,
physical-device VoiceOver, StoreKit sandbox, APNs/background delivery, and
final iOS 27 seed acceptance remain device or service gates.
