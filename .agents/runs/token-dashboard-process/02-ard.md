# Detailed ARD: Token Dashboard Process Surface

## Architecture Summary

The local token dashboard is hosted by a bundled helper app,
`Spill Token Dashboard.app`, inside the main Spill app bundle. The main menu bar
app remains the process that owns the status item, compact panel, preferences,
adapter setup, ingestion loop, and update wiring. The helper process owns only
the detailed token dashboard window and reads the same app-owned local token
store.

## Decisions

### D1: Bundled Helper App

Decision:

Build a secondary `.app` bundle under `Spill.app/Contents/Applications/` and
launch it through `NSWorkspace`.

Rationale:

This gives the dashboard normal app focus, window, and Command-Q behavior
without turning the always-on menu bar utility into a foreground app.

Alternatives considered:

- In-process dashboard window. Rejected as the final shape because Command-Q and
  focus semantics remain tied to the main menu bar app.
- XPC service. Rejected for this slice because a service still needs a window
  host and adds IPC complexity before the dashboard needs it.

### D2: Shared Local Store, No Ingestion Ownership

Decision:

The helper reads the existing local token usage store and may refresh dashboard
state, but it does not install adapters, run hook setup, own token ingestion, or
start cloud sync.

Rationale:

The dashboard is a read-oriented analytics surface. Keeping ingestion in the
main app avoids duplicate collectors and preserves the token-only privacy
boundary.

Alternatives considered:

- Let the helper run a full app delegate. Rejected because it would duplicate
  menu bar, scanner, bridge server, hotkey, and ingestion side effects.

### D3: Explicit Main-App Handoff For Preferences

Decision:

Dashboard preference actions are forwarded to the main app through a narrow
local notification/request path.

Rationale:

The main app owns preferences and setup flows. The helper can ask for the token
metering settings surface without mutating broader app lifecycle state.

## Modules Affected

- `Sources/Spill/App/SpillMain.swift`
- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardProcess.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardLauncher.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardAppDelegate.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardWindowController.swift`
- `Sources/Spill/Settings/SpillSettings.swift`
- `scripts/build-app.sh`
- `scripts/verify-runtime-smoke.sh`
- `Tests/SpillTests/TokenUsageStoreTests.swift`

## New Types / APIs

```swift
enum TokenMeteringDashboardProcess
final class TokenMeteringDashboardLauncher
final class TokenMeteringDashboardAppDelegate
```

## Data Flow

```text
menu bar AI action -> main AppDelegate -> TokenMeteringDashboardLauncher
  -> bundled helper app -> TokenMeteringDashboardAppDelegate
  -> TokenUsageDashboardStore -> app-owned local token store
```

Preferences handoff:

```text
dashboard helper action -> local preference request notification
  -> main app AppDelegate -> Preferences token metering tab
```

## Permissions

- Accessibility: unchanged; helper does not own window actions or menu bar
  scanning.
- Screen Recording: unchanged; not used.
- Network: unchanged; helper does not add cloud sync or auth.
- File system: helper reads the app-owned local token usage store and bundled
  resources only.

## Failure Modes

- Helper bundle missing: launcher falls back to the in-process dashboard window.
- Helper launch failure: launcher reports failure to its completion path and the
  main app can use the fallback.
- Main app not running when helper asks for preferences: helper opens the main
  app URL and posts the preference request again.
- Settings changed in the main app: helper observes settings-change
  notifications and reloads supported display settings.

## Performance Notes

- The helper process is launched only when the user opens the detailed
  dashboard.
- The main menu bar app keeps the compact panel and ingestion loop independent
  from dashboard window rendering.
- The helper avoids status item, menu bar scanner, hotkey, bridge server, and
  panel initialization.

## Test Strategy

### Automated

- `swift test`
- `python3 .agents/scripts/workflow.py runtime-smoke`
- `scripts/verify-runtime-smoke.sh`
- Contract tests in `TokenUsageStoreTests` for helper process routing, launch
  contracts, build script bundle paths, and helper URL resolution.

### Manual

- Open the local token dashboard from the menu bar.
- Close the dashboard and confirm the Spill menu bar item remains.
- Use Command-Q while the dashboard is focused and confirm only the dashboard
  helper exits.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| AI dashboard entry routing | builder | `StatusItemController`, `AppDelegate`, preferences wiring | yes |
| Helper process boundary | builder | `TokenMeteringDashboardProcess`, launcher, helper delegate | no |
| Packaging and smoke verification | builder | `scripts/build-app.sh`, `scripts/verify-runtime-smoke.sh`, tests | no |

## Risks

- App bundle structure changes can break notarization or Sparkle updates if the
  helper bundle is not signed and packaged with the main app.
- Helper/main preference handoff depends on local notification timing.
- A future cloud dashboard must not reuse this helper to bypass the local-only
  token privacy boundary.
