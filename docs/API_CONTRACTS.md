# Backend API contracts

The native app talks only to an HTTPS backend selected by the build configuration. Provider credentials and database implementation details remain server-side. All dates use ISO 8601 and all identifiers are opaque UUID strings unless a domain type explicitly says otherwise.

Every response should include `X-Request-ID`. Read endpoints should use `ETag` and honor `If-None-Match`. Rate-limited responses use HTTP 429 and `Retry-After`.

Every POST, PUT, PATCH, and DELETE must accept an `Idempotency-Key` and return
the original committed result when the key is replayed. Versioned mutations use
`If-Match`. A stale revision returns HTTP 412 with the current `ETag`; a semantic
merge conflict returns HTTP 409 with `X-Resource-Version` and a typed conflict
payload. The client keeps these mutations blocked for explicit resolution.

## Authentication

`POST /v1/auth/sessions`

```json
{
  "email": "anvandare@example.se",
  "proof": {
    "type": "provider_assertion",
    "value": "<short-lived-provider-assertion>"
  },
  "device": {
    "installation_id": "opaque-installation-id"
  }
}
```

```json
{
  "access_token": "<short-lived-token>",
  "refresh_token": "<rotating-token>",
  "expires_at": "2026-08-01T10:30:00Z",
  "account": {
    "id": "9db1ef99-102c-4d56-a9de-8cc4028f2e10",
    "display_name": "Anna Andersson",
    "email": "anvandare@example.se"
  }
}
```

Refresh uses `POST /v1/auth/sessions/refresh`:

```json
{
  "refresh_token": "<rotating-token>"
}
```

```json
{
  "access_token": "<new-short-lived-token>",
  "refresh_token": "<new-rotating-token>"
}
```

The native token provider reads both values from Keychain, retries the original
request only once after a 401, and stores a rotated refresh token when supplied.
Logout uses `DELETE /v1/auth/sessions/current`. Refresh tokens must rotate and
server-side revocation is authoritative.

## Companies and roles

`GET /v1/companies/{organisation_number}` returns source-backed registry data:

```json
{
  "organisationNumber": "5560160680",
  "registeredName": "Exempelbolaget AB",
  "status": "active",
  "registeredOffice": "Stockholm",
  "sourceName": "Configured registry provider",
  "sourceUpdatedAt": "2026-07-31T09:15:00Z"
}
```

`GET /v1/companies?cursor={cursor}` uses:

```json
{
  "items": [],
  "nextCursor": null
}
```

Membership mutation endpoints must enforce the same role matrix server-side as the iOS domain policy and append an audit event atomically.

## Documents

`POST /v1/companies/{company_id}/documents/uploads` creates a short-lived upload authorization. Metadata is committed separately only after client confirmation. The backend must never mark OCR suggestions authoritative without a confirmation field and confirming account identifier.

## Audit events

`GET /v1/companies/{company_id}/audit-events?cursor={cursor}` is append-only. Events include actor, action, entity type, entity ID, timestamp, and a localized-safe summary. Clients cannot update or delete audit events.

## Integrations

`GET /v1/companies/{company_id}/integrations` returns explicit states:

```json
{
  "items": [
    {
      "providerIdentifier": "bolagsverket",
      "state": "disconnected",
      "lastAttemptedAt": null,
      "lastSuccessfulAt": null,
      "lastErrorCode": null
    }
  ],
  "nextCursor": null
}
```

OAuth providers use Authorization Code with PKCE where supported. Provider secrets never enter the mobile app.

## Notifications, subscriptions, and AI retrieval

`PUT /v1/notification-installations/{installation_id}` associates the
authenticated account with an APNs installation only after notification consent:

```json
{
  "platform": "ios",
  "apns_token": "<lowercase-hex-device-token>",
  "apns_environment": "sandbox",
  "authorization": "authorized",
  "shows_sensitive_details": false,
  "app_version": "0.2.0",
  "locale": "sv-SE"
}
```

```json
{
  "installation_id": "opaque-installation-id",
  "registered_at": "2026-07-31T10:30:00Z",
  "status": "active"
}
```

The server derives the account from the bearer token, encrypts the APNs token at
rest, never includes it in logs, and invalidates it when APNs reports that it is
no longer valid. `authorization` is one of `authorized`, `provisional`,
`ephemeral`, `denied`, or `unknown`.

`DELETE /v1/notification-installations/{installation_id}` revokes the
installation on logout, notification opt-out, or account deletion and returns
the same receipt shape with `"status": "removed"`.
The app asks APNs for the current token after authorization and on later
launches, then forwards that callback directly to this backend boundary without
persisting the token or placing it in the offline queue. Upload remains disabled
until authenticated backend registration is configured.

- Subscription entitlement responses are server observations only; StoreKit 2 signed transactions remain the device verification input.
- AI retrieval endpoints require per-request consent, company scope, authorization filtering, exact citation identifiers, and a declared processing mode. Mutations require a separate confirmed command.

## Error envelope

```json
{
  "error": {
    "code": "integration_unauthorized",
    "message": "Provider authorization has expired",
    "request_id": "9e34be67-fc84-469d-8ddd-d9c4ccbd0a6f",
    "retryable": false
  }
}
```

The app maps status and stable error codes to actionable Swedish copy. Raw provider messages must not be shown directly when they can contain sensitive information.
