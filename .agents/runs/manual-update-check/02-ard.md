# Detailed ARD: Manual Update Check

## Architecture Summary

Use a static JSON manifest hosted as a GitHub Releases latest asset. The app owns
a small update checker service that loads and decodes the manifest on demand,
compares dotted numeric versions against the bundle version, and exposes
presentation state through an `UpdateCheckStore` for Preferences and menu
actions.

## Decisions

### D1: Static Release Manifest

Decision: Host `update.json` as a release asset and fetch it from the stable
latest release download URL.

Rationale: This needs no custom server, aligns update metadata with releases,
and avoids GitHub API response/rate-limit coupling in the app.

Alternatives considered: GitHub Releases API was rejected because the app would
need to parse API responses and handle API-specific limits. Sparkle was deferred
until signed/notarized updates are ready.

### D2: Manual Only

Decision: Run the update check only after a user action.

Rationale: MVP should avoid background network traffic and keep privacy behavior
obvious.

## Modules Affected

- `Sources/Spill/App`
- `Sources/Spill/MenuBar`
- `Sources/Spill/Preferences`
- `Tests/SpillTests`
- `.github/workflows/release.yml`
- `scripts/package-release.sh`
- `README.md`

## New Types / APIs

```swift
struct UpdateManifest: Decodable, Equatable
struct UpdateChecker
@MainActor final class UpdateCheckStore: ObservableObject
```

## Data Flow

```text
GitHub Release update.json
  -> UpdateChecker
  -> UpdateCheckStore
  -> Preferences / menu action
  -> NSWorkspace opens download URL
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: unchanged.
- Network: one HTTPS manifest request per manual check.
- File system: release script writes `update.json` into release artifacts.

## Failure Modes

- Manifest request fails: show retryable failure state.
- Manifest version is malformed: show failure state.
- Current bundle version is unavailable in development builds: compare as
  `0.0.0` and display that value.
- Update requires newer macOS: show the available version but disable install
  action.

## Performance Notes

- No timer or background polling.
- JSON payload is tiny and decoded once per manual action.
- Menu actions reuse the same store instead of creating duplicate work.

## Test Strategy

### Automated

- `UpdateCheckerTests` for version comparison, available, up-to-date, and
  unsupported macOS outcomes.
- Workflow YAML parse.
- Shell syntax check for release script.

### Manual

- Launch the packaged app and verify Preferences/menu entry points.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Manifest packaging | builder | `scripts/package-release.sh`, `.github/workflows/release.yml`, `README.md` | yes |
| App checker/store | builder | `Sources/Spill/App`, `Tests/SpillTests` | yes |
| Preferences/menu UI | builder | `Sources/Spill/Preferences`, `Sources/Spill/MenuBar`, `Sources/Spill/App/AppDelegate.swift` | after store |

## Risks

- The latest release asset URL must include `update.json`; older releases without
  it produce a visible failure until the first updated release ships.
- Future Sparkle support will need a separate signed appcast and should not
  reuse this manifest as a security boundary.
