# ARD: Status Detail Menu Bar

## Decision D1: Keep One Status Item

Use the existing Spill status item and switch it between icon-only and variable-length icon-plus-text modes.

Rationale: this preserves the single-trigger architecture and avoids adding more menu bar crowding by default than the user explicitly enables.

## Decision D2: Persist Menu Bar Status Items Separately

Add `SpillMenuBarStatusItem` for CPU and memory visibility. This is separate from panel status module visibility because a user may want a value in the menu bar even if they hide the corresponding panel module.

## Decision D3: Share Stores Between Panel And Status Item

Move `SystemStatusStore` and `AIStatusStore` ownership to `AppDelegate` and inject them into the panel controller and status item controller.

Rationale: the panel and menu bar should render the same readings instead of sampling independently.

## Decision D4: Refresh Menu Bar Values On A Timer

Start a lightweight refresh loop when any menu bar status item is enabled. The loop uses `settings.refreshInterval` and stops when all menu bar status items are disabled.

## Decision D5: Detail Popovers Live On The Status Pills

Attach SwiftUI popovers to the compact status controls. The popovers show provider-specific detail rows and the menu bar visibility toggle for CPU and memory.

## Decision D6: GPU Uses Public Metal Device Metadata

Add `SystemGPUProvider` using `MTLCopyAllDevices()` and `MTLDevice` metadata. This reports device availability and recommended working-set budget when available, but does not claim live GPU utilization because macOS does not expose a simple public per-system GPU utilization API for this app scope.

## Public API Boundary

The feature uses AppKit `NSStatusItem`, SwiftUI popovers, Combine observation, and existing public system providers. It does not add private APIs or extra permissions.

## Verification

- Settings tests cover persisted menu bar status items.
- Summary tests cover menu bar title formatting and filtering of unsupported glance values.
- Existing provider tests cover detailed status data.
