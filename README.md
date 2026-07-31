# NorthBridge

Native iOS command center for Swedish limited companies, built with Swift 6, SwiftUI, SwiftData, Observation, App Intents, WidgetKit, and Apple security frameworks.

The public product and installed app are named **NorthBridge**. The Xcode
project, target, Swift module, and schema types retain their internal
`Bolagscenter` names. Release-facing identifiers use
`com.kbhelios.northbridge`, including the widget, App Group, background task,
Keychain service, subscriptions, and logs.

## Generate and build

Requirements: macOS 27 (or a compatible Apple Silicon host), Xcode 27 beta or
newer, and XcodeGen 2.46 or newer. The app uses Swift 6 language mode with
complete strict-concurrency checking, builds against the iOS 27 SDK, and keeps
iOS 26 as its deployment floor.

```sh
xcodegen generate
xcodebuild -project Bolagscenter.xcodeproj -scheme Bolagscenter -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' build
xcodebuild -project Bolagscenter.xcodeproj -scheme Bolagscenter -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' test
```

The repository includes both `project.yml` and the generated `Bolagscenter.xcodeproj`. Regenerate after adding source files, then commit both so the checked-in Xcode project and declarative source remain aligned.

The production app starts without company fixtures. UI tests use a separate
in-memory store and deterministic `DEBUG`-only fixtures selected by explicit
`-ui-testing-*` launch arguments; none of that fixture code is compiled into
Release builds. See `docs/INTEGRATIONS.md`
for the honest integration boundary, `docs/API_CONTRACTS.md` for backend
contracts, `docs/SECURITY.md` for current security coverage,
`docs/IOS_27_READINESS.md` for the beta compatibility gate, and
`docs/KNOWN_LIMITATIONS.md` for unresolved release work.

## Verified artifacts

The `dist` directory contains the warning-free Release simulator build, an
unsigned arm64 device archive/IPA, a Release smoke screenshot, checksums, and
the exact Apple-signing steps. The unsigned IPA cannot be installed on a stock
iPhone until an Apple Developer team signs it; see `dist/README.md`.

The verified source and downloadable preview artifacts are published in the
[KB-Helios/NorthBridge](https://github.com/KB-Helios/NorthBridge) repository.
