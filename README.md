# Spill

Spill is an open-source compact control tray for macOS. It keeps one visible menu bar trigger and opens a small native panel for useful system state, AI tool state, pinned actions, and focused window controls.

## Current status

This repository currently contains an MVP shell:

- menu bar status item
- click-to-toggle floating Spill Bar
- right-click menu with preferences and quit actions
- SwiftUI preferences window
- Accessibility permission status and diagnostics
- Launch at Login wiring for packaged `.app` builds
- Accessibility-based menu bar extra scanner using `AXExtrasMenuBar`
- best-effort `AXPress` action for detected items
- automatic rescanning when apps, Spaces, or displays change
- optional `Control + Option + Space` global shortcut
- display mode for notch candidates or all detected items
- selectable detected items with persisted Spill Bar inclusion
- app-icon based labels for detected menu bar items

The current Spill Bar can detect some visible menu bar extras when Accessibility permission is granted. This is best-effort behavior. Spill does not promise to recover every item hidden behind the notch or forcibly rearrange other apps' menu bar items.

## Important macOS constraint

macOS does not provide a public API that reliably enumerates, hides, resizes, reorders, clones, or reparents every third-party menu bar extra. `NSStatusBar` works for Spill's own item. Other apps' items live in their own processes, and deep control usually requires Accessibility observation, user-approved automation, or private implementation details.

For an open-source app, the practical direction is:

1. Use public AppKit/SwiftUI for the Spill UI.
2. Ask for Accessibility permission only when needed.
3. Detect visible menu bar items conservatively.
4. Build first-party compact controls instead of relying on fragile spacer behavior.
5. Avoid private APIs until there is a clearly documented reason and risk.

The current scanner is intentionally conservative. It prefers `AXExtrasMenuBar` and only falls back to `AXMenuBar` for Apple system menu-bar hosts, because scanning every app's normal menu bar would incorrectly collect File/Edit/View menu items.

## Requirements

- macOS 14 or newer
- Xcode 26 or newer, or a compatible Swift toolchain

## Run

```bash
swift run Spill
```

During early development the app uses a normal Dock app activation policy so the preferences window is easier to recover while debugging. The status item still appears in the menu bar.

## Build

```bash
swift build
```

To create a local `.app` bundle:

```bash
./scripts/build-app.sh
open .build/Spill.app
```

During development, avoid rebuilding the `.app` while testing Accessibility permission. macOS can treat a newly rebuilt local app as a new permission target.

## Verify

Run deterministic checks:

```bash
python3 .agents/scripts/workflow.py verify
```

Run the bundled app smoke test:

```bash
python3 .agents/scripts/workflow.py runtime-smoke
```

The runtime smoke test builds `.build/Spill.app`, launches the app in `SPILL_SMOKE_TEST` mode, verifies startup readiness, and confirms clean shutdown without opening Preferences or requesting Accessibility permission.

## Roadmap

| Phase | Goal | Scope |
| --- | --- | --- |
| 1 | Product reset | Single visible trigger, no spacer dependency, compact tray direction |
| 2 | Panel shell | System, AI, pinned action, and window action sections |
| 3 | Provider models | Plain model types and provider boundaries |
| 4 | System and AI status | Lightweight local status providers with conservative refresh |
| 5 | Actions | Pinned actions and focused-window quick actions |
| 6 | Preferences | Strip toggles, permission diagnostics, launch at login, optional hotkey |
| 7 | Distribution | Signed app bundle, notarization path, releases, contribution guide |

## License

MIT. See [LICENSE](LICENSE).
