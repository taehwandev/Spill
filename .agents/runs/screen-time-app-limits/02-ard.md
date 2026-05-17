# Detailed ARD: Screen Time App Limits Compatibility

## Architecture Summary

Use a small public-API adapter to open Screen Time settings and keep the
compatibility behavior as guidance rather than automation. Screen Time remains a
system-enforced user setting outside Spill's control.

## Decisions

### D1: Settings Link Instead of Bypass

Decision:

Open Screen Time settings with `NSWorkspace` and document user configuration.

Rationale:

Apple's Screen Time controls are explicitly user/guardian-managed. Spill should
not try to defeat them or request unrelated Screen Time control entitlements.

Alternatives considered:

- Poll for active shields: no stable public AppKit API and adds runtime noise.
- Add Screen Time entitlements: inappropriate for a menu bar utility and still
  would not let Spill bypass user limits.
- Draw above the shield: unsupported and contrary to the purpose of Screen Time.

### D2: README as Source for Blocked-State Recovery

Decision:

Put the recovery path in README because a Screen Time shield can prevent users
from reaching in-app preferences.

Rationale:

If Spill itself is blocked, in-app guidance is inaccessible. External docs must
carry the critical recovery steps.

## Modules Affected

- `Sources/Spill/App/ScreenTimeSettings.swift`
- `Sources/Spill/Preferences/GeneralPreferencesSection.swift`
- `.agents/scripts/workflow.py`
- `.agents/README.md`
- `README.md`
- `.agents/runs/screen-time-app-limits/*`

## New Types / APIs

```swift
enum ScreenTimeSettings {
    static func open()
}
```

## Data Flow

```text
Preferences button -> ScreenTimeSettings.open() -> NSWorkspace -> System Settings
```

## Permissions

- Accessibility: unchanged.
- Screen Recording: unchanged.
- Screen Time: no entitlement requested.
- Network: unchanged.
- File system: unchanged.

## Failure Modes

- Spill is blocked by Screen Time: user must configure Always Allowed or remove
  the limit from System Settings.
- Launcher app is blocked by Screen Time: launch Spill independently from
  Finder/Applications after clearing the shield.
- Settings URL changes: README still provides manual navigation.

## Performance Notes

- No polling.
- No background work.
- One settings-open action only when the user presses the button.

## Test Strategy

### Automated

- `swift test`
- `swift build`
- `./scripts/build-app.sh`
- `./scripts/verify-status-click-smoke.sh`
- `python3 .agents/scripts/workflow.py verify`
- `git diff --check`

### Manual

- Open Preferences and press Open Screen Time.
- Confirm README explains App Limits, Downtime, Always Allowed, and independent
  app launch.

## Implementation Split

| Task | Owner | Files | Can run parallel? |
| --- | --- | --- | --- |
| Settings adapter | builder | `Sources/Spill/App/ScreenTimeSettings.swift` | yes |
| Preferences guidance | builder | `Sources/Spill/Preferences/GeneralPreferencesSection.swift` | no |
| Docs | builder | `README.md` | yes |
| Verification | verifier | command checks | no |

## Risks

- Apple does not document every System Settings deep link as stable. The README
  includes manual navigation as fallback.
- Users can still block Spill intentionally; Spill must respect that.
