# Known limitations

This file describes the current product boundary honestly. A limitation must not be represented in the UI as an active integration.

- No Swedish authority, BankID, banking, or accounting provider credentials are configured. Manually entered company data remains marked unverified.
- Server authentication, remote collaboration, token refresh, cross-device
  account deletion, remote-notification delivery, and remote synchronization
  require a backend deployment. APNs entitlement wiring, current-token
  forwarding, local account deletion, portable local data export, and
  company-overview PDF export are implemented.
- VisionKit scanning requires a supported physical iPhone or iPad camera and cannot be accepted on Simulator alone.
- OCR suggestions can be wrong. Extracted metadata is never authoritative until the user confirms it.
- Board templates are drafting assistance, not legal advice. Generated minutes,
  shareholder-register, share-certificate, and company-overview PDFs require
  human verification. A share-certificate status in the app does not prove that
  a legally valid original was decided, signed, or delivered.
- Financial values are local manual records until a configured provider supplies source-backed data.
- StoreKit 2 product loading, verified purchases, restore, transaction updates,
  status, grace periods, expiry, and protected entitlement caching are
  implemented. The three product identifiers still need matching App Store
  Connect products and sandbox pricing before purchase acceptance can pass.
- Bolagsassistenten currently uses its grounded on-device deterministic engine
  and sends no company data externally. External AI remains intentionally
  disabled until provider selection and per-request consent are implemented.
- The final source and full 91-test simulator suite have been validated with
  Xcode 27 on both iOS 27.0 and iOS 26.5. The adaptive primary-workspace flow
  also passed on an iPad mini simulator running iOS 27.0. A physical iOS 27
  beta iPhone and a paid Apple signing team remain required for device-only
  acceptance; see `IOS_27_READINESS.md` and `dist/README.md`.
- The protected offline mutation queue, reconnect replay, idempotency, and typed
  conflict states are implemented at the transport boundary. A configured
  backend is still required to accept replay and produce server-side conflict
  payloads.
- Automated accessibility and largest-Dynamic-Type audits passed, but simulator
  evidence does not replace pending physical-device camera, dark-mode,
  VoiceOver, StoreKit sandbox, APNs/background-delivery, and broad physical
  device/rotation acceptance.
- Source, checksums, and verified preview artifacts are published in the public
  `KB-Helios/NorthBridge` repository. Tagged builds publish an unsigned IPA as
  a pre-release development handoff—not a substitute for Apple Developer
  signing or TestFlight.
