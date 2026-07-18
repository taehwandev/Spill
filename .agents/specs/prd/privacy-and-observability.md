# Privacy And Observability PRD

## Document Contract

- Status: active
- Audience: product, privacy, engineering, QA, and release maintainers
- Purpose: define product telemetry and diagnostics boundaries outside token event collection
- Source of truth: this document owns product telemetry and observability policy
- Related: [Spill PRD index](../prd.md), [Spill ARD](../ard.md),
  [Local Token Collection](token-metering/local-collection.md)

## Telemetry Policy

Requirements:

- Telemetry is optional and must not be required for app functionality.
- The default open-source build should send no telemetry unless an app telemetry
  key is explicitly configured.
- Telemetry events may include only coarse product events and safe enum/string
  props such as panel opened, setting changed, update check result, or pin
  toggled.
- Telemetry must never include prompts, responses, commands, file paths, repo
  names, branch names, terminal output, logs, diffs, source content, environment
  values, secrets, token payloads, local aliases, or raw usage events.
- Users and test environments must have a clear opt-out path.

Acceptance:

- The PRD states what telemetry may and may not collect.
- Telemetry remains content-free and separate from token usage metering.
- Smoke tests can disable telemetry.

## Open Coverage Decisions

Product review must define the missing user and data-lifecycle contracts before
they are treated as released product policy:

- Crash and unclean-exit diagnostics, including consent, redaction, sampling,
  retention, and opt-out behavior.
- Local token usage retention and whether end users receive delete or export controls.
- The relationship between legal/privacy links and the configured telemetry,
  crash reporting, and Private Usage Upload features.

## Verification

- Verify telemetry-disabled builds send no product telemetry.
- Verify allowlists reject content-like values and token event payloads.
- Verify any accepted crash-diagnostic contract separately from product
  telemetry and token metering.
