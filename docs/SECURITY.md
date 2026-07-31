# Security model

## Implemented

- Keychain values use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- The local session is typed, Keychain-backed, expires after twelve hours, is
  revalidated whenever the app becomes active, and rejects malformed storage.
- The optional device lock uses `deviceOwnerAuthentication`, allowing Face ID or the device passcode.
- Onboarding verifies device ownership before enabling app lock, then keeps the
  verified foreground session open until the app next backgrounds.
- The app locks when it enters the background.
- Imported documents are copied into Application Support with atomic writes and complete file protection.
- Scanned pages are converted to a protected local PDF. Vision OCR is performed on-device and no scanned content is transmitted.
- Generated board minutes, shareholder registers, share-certificate drafts, and
  company overviews use complete file protection and are validated before
  sharing or being added to the vault.
- Widget data uses an app group, the widget entitlement requests
  `NSFileProtectionComplete`, and deadline/action/finance details remain hidden
  unless the user explicitly opts in. Visible values are privacy-sensitive.
- Offline mutation bodies are stored atomically with complete file protection.
  Each queued operation has a stable idempotency key; conflicts remain blocked
  for explicit resolution. Permanent local account deletion clears the queue
  before deleting records.
- APNs device tokens are forwarded from the current system callback directly to
  the authenticated registration boundary. They are not persisted, placed in
  the offline mutation queue, or written to logs. The exact system authorization
  state is forwarded, and explicit logout/account deletion attempts to revoke
  the installation before credentials are removed.
- Role permissions are enforced before persistence mutations, not only hidden in views.
- Company selection and mutation attribution use the authenticated account's
  active memberships; they never infer identity from fetch ordering.
- Secure logout removes session and access/refresh token slots from Keychain.
- Configured backend calls use a Keychain-backed token provider with one-time
  refresh and optional refresh-token rotation; tokens are never logged.
- Account deletion requires typed e-mail confirmation plus fresh device-owner
  authentication. Sole-user company records and app-owned document files are
  purged; generated PDF directories, portable exports, deferred mutation
  payloads, and widget snapshots are cleared. Shared companies remain for other
  active members and corporate audit events are anonymized.
- Portable account export is written with complete file protection. It includes
  account and authorized company records while requiring document binaries to
  be explicitly shared from their protected document view.
- Audit events record company, deadline, finance, document, board, decision, action, and ownership mutations and exports.
- OSLog messages never interpolate company data publicly; error details are privacy-masked.

## Authentication boundary

The current onboarding creates a secure local workspace and uses device-owner
authentication for local sign-in. It does not claim server authentication or
BankID. The client-side bearer-token and refresh boundary is implemented, but
backend sign-in, remote session revocation, cross-device account deletion, and
BankID require a configured backend and an approved Swedish BankID provider.
Provider secrets must never ship in the app.

## Remaining security work

- Backend-issued sign-in tokens and server-side session revocation.
- Server-coordinated account deletion and export across remote provider data.
- App Attest/device-risk policy, if selected.
- External security review, privacy manifest audit, and penetration testing before release.
