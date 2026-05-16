# ARD: Pinned Actions UI

## Decision D1: Reuse Selected Item Keys As Pins

Use `SpillSettings.selectedItemKeys` as the pin source. The app already persists selected menu bar items, and reusing that state avoids a second storage path for the same user intent.

Rejected alternative: add a new pinned action store. That would duplicate selection state and create migration questions before the action model needs it.

## Decision D2: Keep Pinned Items In The Main Action Row

Render pinned actions first in the existing horizontal action scroller, then render the current display-mode actions excluding duplicates.

Rationale: the panel has strict vertical space. A separate pinned section would make the compact panel harder to keep under the layout smoke threshold.

## Decision D3: Pin Toggle Lives On The Action Tile

Each `SpillActionButton` owns a small overlay pin button. The primary tile button handles execution, while the overlay handles pin and unpin.

Rationale: this keeps pinning discoverable without adding text-heavy controls. Disabled execution state applies only to the main action button so users can still unpin disabled or stale items.

## Decision D4: Header Carries Action Feedback

Successful and failed action results update the header subtitle with a short message and tint. This avoids adding another row while making click outcomes visible.

## Decision D5: Bundle Identifier Enables App Activation Fallback

Extend `SpillActionKind.menuBarItem` to carry the source bundle identifier. `MenuBarActionAdapter` maps the value from `MenuBarItemSnapshot.bundleIdentifier`.

Execution order:

1. Recover source snapshot ID and try `AXMenuBarItemScanner.pressItem(withID:)`.
2. If that fails, recover the bundle identifier and activate a running app.
3. If the app is not running but is installed, open it through `NSWorkspace`.
4. Otherwise return a visible failure result.

## Public API Boundary

This feature uses SwiftUI, AppKit, Accessibility through the existing scanner, and `NSWorkspace`. It does not use private menu bar APIs.

## Verification

- Unit tests cover action kind mapping and source bundle identifier recovery.
- Unit tests cover existing settings persistence used by pinned keys.
- Smoke checks verify panel construction and runtime startup.
