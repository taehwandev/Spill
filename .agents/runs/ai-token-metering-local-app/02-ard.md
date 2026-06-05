# Detailed ARD: Local App Token Metering Bridge

## Architecture Summary

Add a `TokenMetering` ownership boundary to the Swift app. It contains the safe
usage event model, sanitizer, file-backed local store, and a loopback-only HTTP
bridge. The macOS app also owns the local dashboard: a SwiftUI window reads the
same app-owned store and renders token aggregates without requiring a browser,
Vite dev server, web workspace, or cloud account.

Preferences and the status menu expose the token metering entry point without
turning the native panel into a dashboard. They present the product state model:
local-only is active without login, cloud aggregate requires future login plus
explicit enablement, and cloud detailed requires a separate future token-only
opt-in.

## Decisions

### D1: App-Owned Local Store

Decision:

Persist token events in `~/Library/Application Support/Spill/token-metering`.

Rationale:

The app must be the source of local data. Application Support follows existing
cache/store patterns in the app and keeps data local to the machine.

### D2: Native Local Dashboard Reads The Store

Decision:

Show a compact Token Metering summary inside the existing Spill Panel AI
section. A native Token Metering dashboard window remains available from that
summary's detail action, Preferences, and the status menu. The dashboard reads
`TokenUsageStore` directly and renders totals, task breakdowns, source hotspots,
session rows, empty state, refresh, clear, and local test-event actions.

Rationale:

The local product experience must work from the installed app. A browser-based
local dashboard would require shipping or running the web workspace and would
confuse the boundary between local-only usage and authenticated cloud sync.
Token metering is AI usage state, so the first visible local surface belongs in
the existing AI section instead of replacing the panel or forcing users through
Preferences.

### D3: Loopback Bridge

Decision:

Expose safe local usage data over `127.0.0.1` only.

Rationale:

The bridge can support development tools and future reviewed sync helpers
without exposing a public listener. It is not the user-facing local dashboard.

### D4: Reject Unknown And Forbidden Fields

Decision:

The Swift bridge rejects payloads that include forbidden content keys or fields
outside the allowlist.

Rationale:

The app boundary must be stricter than the UI. This prevents accidental content
capture before any future cloud work.

### D5: Preferences As The Native Entry Point

Decision:

Add a Token Metering Preferences section and lightweight menu actions for opening
the native local dashboard.

Rationale:

Users need to discover and use local token metering from inside the app.
Preferences can show the local/login/cloud opt-in contract without adding upload
code or expanding the compact panel into a large dashboard.

## Modules Affected

- `Sources/Spill/TokenMetering/`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Preferences/`
- `Tests/SpillTests/`

## New Types / APIs

```swift
struct TokenUsageEvent: Codable, Equatable, Sendable
final class TokenUsageStore: @unchecked Sendable
final class TokenUsageBridgeServer: @unchecked Sendable
final class TokenUsageDashboardStore: ObservableObject
final class TokenMeteringDashboardWindowController
struct TokenMeteringDashboardView: View
struct TokenMeteringModeStatus: Identifiable, Equatable
```

Local bridge routes:

```text
GET     /v1/usage/health
GET     /v1/usage/events
POST    /v1/usage/events
DELETE  /v1/usage/events
OPTIONS *
```

## Data Flow

```text
safe local integration or dashboard test event
  -> TokenUsageSanitizer
  -> TokenUsageStore
  -> TokenUsageDashboardStore
  -> TokenMeteringDashboardView
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: unchanged.
- Network: loopback-only listener on `127.0.0.1`; no external host.
- File system: Application Support JSON store.

## Failure Modes

- Port unavailable: app keeps running and local dashboard continues reading the
  store directly.
- Corrupt local file: store returns empty events and can rewrite on next save.
- Forbidden payload: bridge returns `400` and does not persist.
- Empty store: dashboard shows a zero-token state inside the app.

## Test Strategy

### Automated

- Swift tests for event validation and store load/save/append/clear.
- Swift tests for local dashboard aggregation/presentation model.
- `swift test`
- `npm test`
- `npm run build`
- VibeGuard before and after edits.

### Manual

- Launch app and confirm local bridge health responds.
- Open the native local token dashboard from the status menu and Preferences.

## Risks

- This still does not automatically read third-party AI usage. It creates the
  trusted local ingestion/storage surface first.
- Local loopback access is visible to local processes, so payload must remain
  token-only and content-free.
