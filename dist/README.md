# NorthBridge v0.1.0 validation artifacts

These checked-in artifacts are the historical v0.1.0 validation baseline. They
were built on macOS 27 with Xcode 27 beta 4 and Swift 6.4 and passed 84 of 84
tests on iPhone 17 Pro with iOS 27.0 and another 84 of 84 tests on iPhone 17 Pro
with iOS 26.5.

They do not contain the v0.2 design refresh. Current tagged releases are built
from the tag by GitHub Actions and published as GitHub pre-release assets with
their own checksum manifest and installation note.

## Files

- `NorthBridge-iOS27-Simulator.app.zip` is the warning-free Release app for an
  arm64/x86_64 iOS simulator. It cannot run on a physical iPhone.
- `NorthBridge-unsigned.xcarchive.zip` is the warning-free Release arm64 device
  archive. This is the preferred input for Apple Development, Ad Hoc, or App
  Store/TestFlight signing.
- `NorthBridge-unsigned.ipa` contains the same unsigned arm64 device app in IPA
  layout. It is **not installable on a stock iPhone until it is signed with a
  valid provisioning profile**.
- `NorthBridge-Release-Smoke.png` records the Release build running on the iOS
  27 iPhone 17 Pro simulator.

## SHA-256

```text
f36af4a4278a820bafdecb77c672f49527cd9208424008aae7287f44d3207f1a  NorthBridge-iOS27-Simulator.app.zip
b85b15477f7868e17ae76e2650329a155db2bbca2465b6e0c760ef36a0d77294  NorthBridge-unsigned.ipa
86072ec4c9013410be7da896955a72af33f948df6fb9198fece2c1bd1408c466  NorthBridge-unsigned.xcarchive.zip
d4ae94ef34ef6019083338419251ee40f4343f2293e2f15194dc0e9e2b1657ff  NorthBridge-Release-Smoke.png
```

## Install on an iPhone 17 Pro running iOS 27 beta

1. On a Mac with Xcode 27, sign in to the paid Apple Developer account that
   owns the intended App ID.
2. Open `Bolagscenter.xcodeproj`, select the `Bolagscenter` target, open
   **Signing & Capabilities**, enable automatic signing, and select the team.
   Repeat for `BolagscenterWidget`. Register
   `com.kbhelios.northbridge`, `com.kbhelios.northbridge.widget`, and App Group
   `group.com.kbhelios.northbridge` for that team.
3. Connect and trust the iPhone, enable Developer Mode, select it as the run
   destination, and press Run. Xcode will create a Development provisioning
   profile and install the signed app.
4. For TestFlight or Ad Hoc distribution, create a signed archive in Xcode's
   Organizer and choose **Distribute App**. The included unsigned archive can
   also be re-signed/exported once the certificates and profiles are available.

The build runner had no Apple signing identity or provisioning profile, so it
could not truthfully produce a directly installable IPA. Do not rename the
unsigned IPA as signed or attempt to install it without completing these steps.
