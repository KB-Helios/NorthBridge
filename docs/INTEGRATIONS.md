# Integration status

| Integration | Status | Notes |
| --- | --- | --- |
| Local SwiftData | Active | Production store starts empty; source timestamps are required. |
| Typed backend transport | Active in source | URLSession actor with DTO decoding, retries, token-refresh hook, rate limits, ETags, cache policy, pagination, cancellation, idempotency keys, optimistic concurrency, and a protected offline mutation queue. Requires an injected HTTPS base URL. |
| Connectivity state | Active | Network framework monitoring exposes an explicit offline banner; deterministic UI coverage forces this state without changing Release behavior. |
| Keychain / LocalAuthentication | Active | Local session key and automatic device lock foundation. |
| Document import | Active | PDF/image import, protected offline copy, on-device OCR, metadata confirmation, version and audit event. |
| VisionKit scanner | Active on supported devices | Native document camera; camera hardware is unavailable in Simulator. |
| Vision OCR | Active | Accurate on-device OCR with Swedish and English language guidance. |
| PDFKit | Active | Document viewing plus validation of generated board minutes, shareholder registers, and company overviews. |
| Board and ownership | Active locally | Persistent meetings, decisions, actions, immutable share transactions, historical share-certificate records, validation, revocation, and protected PDF exports. |
| WidgetKit | Active in source | Next deadline, pending actions, Bolagspuls factors, and available liquidity. Sensitive values are opt-in and require signing/app-group provisioning. |
| App Intents | Active in source | Show/create deadline, open company, create meeting, scan document, add action, and ask Bolagsassistenten. |
| APNs | Configurable | Push entitlement and current-token forwarding are wired without persisting or logging the token. Authenticated backend registration, provider credentials, and physical-device acceptance remain required. |
| Integration center | Active locally | Shows honest states, opens official HTTPS services, and records external completion only with protected supporting evidence and an audit event. |
| Bolagsverket | Awaiting API access | Typed company-registry protocol and backend DTO adapter exist; no scraping or simulated verification. |
| Skatteverket | Awaiting API access | Requires supported API, agreement, credentials, and backend adapter configuration. |
| Verksamt.se | External workflow active | Opens the official service and can record completion with evidence; never claims automatic submission. |
| SCB | Not configured | Adapter and applicable dataset selection remain. |
| Fortnox / Visma / Bokio | Awaiting credentials and commercial review | OAuth with PKCE where supported; no secrets in app. |
| Open banking | Awaiting approved provider | A licensed provider and consent flow are required. |
| BankID | Not configured | Architecture preparation only; the app must not imitate BankID. |
| StoreKit 2 | Active in source | Product loading, verified purchase/restore, transaction updates, entitlement cache, grace period, retry, expiry, and revocation. Matching App Store Connect products remain required. |
| Bolagsassistenten | Active on device | Grounded local engine with record citations, fact/calculation/suggestion labels, refusal on missing data, and confirmation-gated agenda drafts. External AI is disabled. |
