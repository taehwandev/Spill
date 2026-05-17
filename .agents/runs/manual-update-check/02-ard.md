# Detailed ARD: Manual Update Check

## Architecture Summary

Use a static JSON manifest hosted as a GitHub Releases latest asset. The app owns
a small update checker service that loads and decodes the manifest on demand,
falls back to the GitHub latest release API only when the manifest asset is
missing, compares dotted numeric versions against the bundle version, and exposes
presentation state through an `UpdateCheckStore` for Preferences and menu
actions.

## Decisions

### D1: Static Release Manifest

Decision: Host `update.json` as a release asset and fetch it from the stable
latest release download URL. If that URL returns `404`, load the public GitHub
latest release API and derive minimal update metadata from the release tag and
macOS download asset.

Rationale: This needs no custom server, aligns update metadata with releases,
and avoids GitHub API response/rate-limit coupling for normal checks. The 404
fallback keeps older public releases usable when they were published before
`update.json` upload was added.

Alternatives considered: GitHub Releases API as the primary source was rejected
because the app would need to parse API responses and handle API-specific limits
for every check. Sparkle was deferred until signed/notarized updates are ready.

### D2: Manual Only

Decision: Run the update check only after a user action.

Rationale: MVP should avoid background network traffic and keep privacy behavior
obvious.

### D3: Terminal Command Copy, Not Shell Execution

Decision: Treat the public Terminal install command as the primary update action
for available updates. The app copies the command to the pasteboard and leaves
execution to the user in Terminal.

Rationale: Direct distribution is not yet Sparkle-backed. Copying a visible
Terminal command keeps the update path inspectable and avoids the trust,
permission, and failure-mode risks of silently running shell commands from the
app.

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
  -> if 404, GitHub latest release API
  -> UpdateChecker
  -> UpdateCheckStore
  -> Preferences / compact panel / menu action
  -> NSPasteboard copies install command or NSWorkspace opens download URL
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: unchanged.
- Network: one HTTPS manifest request per manual check.
- File system: release script writes `update.json` into release artifacts.
- Pasteboard: only on explicit command-copy action.
- Shell execution: none.

## Failure Modes

- Manifest request fails with 404: derive update metadata from latest release.
- Manifest and fallback request fail: show retryable failure state.
- Command copy fails: button state remains available; no installer is executed.
- Manifest version is malformed: show failure state.
- Current bundle version is unavailable in development builds: compare as
  `0.0.0` and display that value.
- Update requires newer macOS: show the available version but disable install
  action.

## Performance Notes

- No timer or background polling.
- JSON payload is tiny and decoded once per manual action.
- Menu actions reuse the same store instead of creating duplicate work.
- Panel update UI is a single compact row and is only present when an available
  update is known.

## Test Strategy

### Automated

- `UpdateCheckerTests` for version comparison, available, up-to-date,
  unsupported macOS outcomes, and the missing-manifest fallback.
- `UpdateCheckStoreTests` for initial idle state and Terminal command copy.
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

- The 404 fallback cannot recover manifest-only metadata such as exact build
  numbers; older releases without `update.json` use conservative defaults until
  the first updated release ships.
- Future Sparkle support will need a separate signed appcast and should not
  reuse this manifest as a security boundary.
