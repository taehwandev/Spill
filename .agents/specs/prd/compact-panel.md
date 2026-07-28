# Compact Panel PRD

## Document Contract

- Status: active
- Audience: product, design, engineering, and QA
- Purpose: define the compact Spill Panel composition and interaction contract
- Source of truth: this document owns panel layout, sections, and panel-level UX
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md),
  [System Status](system-status.md), [AI Status](ai-status.md)

## Requirements

- Native `NSPanel`, non-activating where appropriate.
- Appears under the notch when notch geometry is available, otherwise under or
  near the trigger.
- Glass tray style.
- The glass backdrop is clipped at the visual-effect boundary to the same
  continuous rounded outline as the visible panel border. No rectangular
  translucent material may remain in the four outer corners.
- Height target: 120-180px for MVP.
- Sections:
  - Status Strip
  - AI Strip
  - Pinned Actions
  - Window Actions
  - Detected Items, optionally collapsed
- The AI Strip includes the token metering summary as one compact AI usage
  affordance, not a separate dashboard embedded in the panel.
- AI process state distinguishes tool availability from process activity:
  installed tools with no matching process are `Ready`, tools with one or more
  matching local processes are `Running`, and CPU/memory/process counts explain
  current activity without a separate threshold-based `Active` judgment.
- AI process cards aggregate all matching processes for the tool. Detail
  popovers should show the aggregate process count, CPU percentage, memory, and
  a short per-process list because Codex, Claude Code, Antigravity/AGY, and
  Ollama can each involve multiple local processes.
- AI process CPU should represent recent activity rather than process-lifetime
  average CPU. Memory should align with the user-facing Activity Monitor
  memory footprint concept when the platform exposes it, while still degrading
  safely when a process disappears or cannot be sampled.

## Acceptance

- Panel opens within 1 second.
- Text and icons do not overlap.
- Panel does not feel like a full dashboard.
- The token summary can open the local token dashboard helper.
- AI status should not imply that a tool is actively generating solely because
  a process exists. The UI should show `Running` plus CPU/memory detail instead
  of a vague active count.
- The panel's four outer corners remain fully transparent outside the rounded
  tray outline in light and dark appearance and after a live panel resize.

## Verification

- Verify notch and non-notch placement paths.
- Verify compact layout for loading, empty, unavailable, and populated sections.
- Verify the panel opens the detailed token dashboard instead of embedding it.
- Verify the visual-effect mask follows panel size changes and visually inspect
  that no rectangular backdrop remains outside the rounded border.
