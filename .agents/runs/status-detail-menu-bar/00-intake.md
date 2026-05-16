# Intake: Status Detail Menu Bar

## Request

Make CPU, memory, GPU, network, and AI status more useful than simple compact labels. The panel should reveal detailed readings when a status is clicked, and CPU and memory values should be visible directly in the menu bar without opening the panel.

## Why Now

The panel has real providers, but the visible UI still compresses those providers into one short value each. Users need both a glanceable menu bar summary and a way to inspect the underlying details without going to Preferences.

## Necessity

Decision: `build`

### Reasoning

This builds on existing provider state and settings. It does not require private APIs, external network calls, or new permissions. The feature makes the existing system and AI providers materially more useful.

### Cost Of Skipping

CPU and memory remain decorative percentages, AI remains hidden behind a panel click, and users cannot choose which values deserve menu bar space.

## Users

- Users who want CPU and memory visible while working.
- Users with crowded menu bars who need per-status on/off control.
- Contributors verifying provider readings beyond the compact value.

## Scope

- Add menu bar visibility settings for CPU and memory.
- Render selected values in the existing Spill status item.
- Refresh menu bar status values on a timer.
- Add click detail popovers for system and AI status pills.
- Add public Metal-based GPU availability details.
- Add deterministic tests for settings and menu bar summary formatting.

## Non-Goals

- No new private menu bar APIs.
- No second status item.
- No secret display for OpenAI configuration.
- No network bandwidth metering in this slice.
