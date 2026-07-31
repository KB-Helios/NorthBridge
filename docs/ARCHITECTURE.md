# NorthBridge architecture

NorthBridge is a native Swift 6 and SwiftUI application targeting iOS 26 and
prepared for iOS 27. The durable project definition is `project.yml`; the
generated Xcode project is checked in for direct opening and must be regenerated
with XcodeGen whenever sources change.

## Boundaries

- `App` owns composition, the five-tab shell, per-tab navigation, lifecycle, and intent handoff.
- `Core` contains design-system, logging, authentication, account lifecycle,
  security, notifications, background refresh, StoreKit subscriptions,
  persistence, typed networking, and integration infrastructure.
- `Domain` contains validated value types, roles, permissions, and SwiftData persistence records.
- `Features` own user-visible workflows and may depend on domain policies through explicit environment injection.
- `Shared` contains the minimal Codable surface shared with WidgetKit.
- `BolagscenterWidget` is a separate extension with app-group access and complete data protection.

SwiftData records do not double as API DTOs. Provider adapters will map typed DTOs into domain inputs before a main-actor persistence service writes them. Official-source metadata always carries source and update time.

## State and concurrency

- `AppEnvironment`, navigation, SwiftData views, and local UI mutations are main-actor isolated.
- Keychain access is serialized by an actor.
- StoreKit entitlement observation and notification scheduling cross actor
  boundaries through Sendable snapshots; UI state remains main-actor isolated.
- Shared mutable provider state will use actors.
- `HTTPClient` is an actor using structured `URLSession` calls, typed generic requests, request identifiers, authentication hooks, one-time token refresh, cancellation, bounded retry, rate-limit handling, pagination envelopes, cache policy, and ETag revalidation.
- Configured clients use a Keychain-backed access-token actor and the protected
  offline queue; local account deletion clears queued payloads before purging
  data.
- Mutations receive stable idempotency keys and optional `If-Match` revisions.
  Offline mutations can enter a complete-file-protected persistent actor queue;
  reconnecting triggers replay with the original body, headers, authentication
  requirement, idempotency key, and revision. HTTP 409/412 responses remain
  blocked for explicit conflict resolution rather than overwriting newer state.
- Network calls propagate Swedish, actionable typed errors; transport and decoding failures are never swallowed.
- Strict concurrency checking is enabled in all configurations.

## Navigation

Each tab has its own `NavigationStack` and `RouterPath`. Company changes reset every tab history. App Intents and widget URLs hand off through one central route translation in `AppEnvironment`.

## Persistence and migration

`BolagscenterSchemaV1` is the explicit SwiftData `VersionedSchema`. It includes
accounts, companies, memberships, responsibilities, invitations, registrations, people, board
mandates, meetings, attendance, agenda items, resolutions, actions,
shareholders, share classes, immutable share transactions, historical
share-certificate registrations, documents and versions, deadlines, deadline
reminders/supporting documents/action events,
financial metrics and plans, integrations, audit events, and notification
preferences.

`BolagscenterMigrationPlan` is installed when the `ModelContainer` opens. UUIDs are stable identities and enumerations are persisted as raw strings so cases can be added without changing the storage shape. Any storage-shape change after the first release must introduce a new `VersionedSchema` and an explicit migration stage; version 1 must never be edited after it ships.

The ownership ledger is event sourced: current holdings are derived from immutable issuance, transfer, redemption, and correction records. Existing history is never overwritten. Share certificates do not mutate holdings; they are separately validated, revocable historical records.

Deadline rules are presentation-independent definitions with stable IDs,
versions, effective dates, official HTTPS sources, deterministic date
calculation, duplicate prevention, and Swift Testing coverage.

## Governance and documents

- Board meetings own separately persisted attendance, agenda, resolution, and action records.
- Board and ownership mutations pass through domain role checks and produce audit events.
- Board minutes, shareholder registers, share-certificate drafts, and company
  overviews are rendered as protected PDFs, verified with PDFKit, entered in the
  document vault where applicable, and versioned. Repeated vault exports update
  one document record while preserving each PDF at a unique immutable URL; users
  can open and share any recorded version.
- VisionKit scans physical pages. Vision OCR runs on-device; suggested title, category, organisation numbers, and dates remain non-authoritative until the user approves metadata.
- Imported and generated files are copied into Application Support with complete file protection and viewed with PDFKit or native image rendering.
- Bolagsassistenten has an on-device deterministic mode. It retrieves only the
  selected company records, labels facts/calculations/suggestions, cites every
  result, and requires confirmation plus domain permission before persisting an
  agenda draft.

## iOS 27 presentation

Native `GlassEffectContainer`, `glassEffect`, and glass button styles are
centralized in the design system and guarded by availability. Glass is reserved
for the company switcher, high-level executive surfaces, assistant prompts, and
primary onboarding actions; document bodies, tables, and dense financial
content retain opaque surfaces for readability and accessibility.

## Backend boundary

The app consumes DTOs through typed service protocols and maps them to domain values. SwiftData records are not decoded directly from APIs. Development, staging, and production use separate `.xcconfig` files; an HTTPS backend URL must be injected at build time and no provider secret is stored in source.

Official adapters have explicit disconnected, unauthorized, unavailable, rate-limited, failed, and stale states. When a supported API is unavailable, the app opens the official service externally and stores the user's completion note plus protected supporting evidence without claiming automatic submission.

No production seed data is installed. Deterministic UI-test fixtures are
compiled only in `DEBUG`, require explicit `-ui-testing-*` launch arguments,
and use an in-memory SwiftData store. The Release build contains neither the
fixture seeder nor its launch-mode hooks.
