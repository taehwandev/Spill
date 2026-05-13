# ARD: Source Folder Layout

## Decision

Use responsibility-based folders under `Sources/Spill` without changing package targets or Swift symbols.

## Rationale

SwiftPM compiles Swift files recursively under the target source directory. Moving files into subfolders is enough to create clearer ownership boundaries without changing `Package.swift`.

## Layout

```text
Sources/Spill/
├─ Accessibility/
├─ App/
├─ MenuBar/
├─ Panel/
├─ Preferences/
└─ Settings/
```

## Module Boundaries

### App

Owns app startup, app delegate behavior, and process lifecycle helpers.

### Accessibility

Owns AX constants, AX element reading, permission state, and permission diagnostics.

### MenuBar

Owns the visible status item trigger, best-effort menu bar scanning, menu bar item snapshots, and notch geometry.

### Panel

Owns the Spill panel window/controller, layout, metrics, and panel-facing SwiftUI views.

### Preferences

Owns the preferences window and settings UI sections.

### Settings

Owns persistent user settings and small settings enums.

## Verification Strategy

- Confirm files moved into the expected folders.
- Run `swift build`.
- Run workflow docs, readiness, and language gates.

## Risks

- Some generated tooling may assume flat files. Current SwiftPM usage does not.
- A moved file can be missed. Verify with `find Sources/Spill -type f`.

## Rollback

Move files back to `Sources/Spill` if SwiftPM or tooling fails unexpectedly.
