# Feature Intake

## Feature ID

`provider-model-foundation`

## Request

Create the planning run artifacts for a plain provider model foundation in Spill. The feature should define the product and architecture groundwork for `SpillStatusItem`, `SpillAction`, provider protocols, and integration boundaries without changing current UI behavior. This run is documentation-only at intake time and must not edit source code or global docs.

## User Problem

Spill is moving toward a provider-backed panel model, but the shared model layer needs to be explicit before UI and provider work continue. Without this foundation, future providers risk each inventing incompatible item/action shapes, threading rules, identity semantics, and failure handling. A small plain model layer makes future status, pinned action, and capability providers easier to implement and verify independently.

## Target User

- Developers implementing Spill providers and panel features.
- Reviewers who need stable contracts for future provider tasks.
- Spill users indirectly, through fewer regressions when provider-backed features are added.

## Proposed Product Shape

No visible product change in this feature. The app should launch, show the existing status item, open and close the existing Spill panel, and preserve current menu bar item behavior exactly as before. The only intended product outcome is a source-level foundation that future UI and providers can consume.

## Necessity Assessment

Decision: `build`

### Rationale

The provider model foundation is necessary before adding multiple status/action providers because it defines the lowest-level contract that all providers will share. This is a small, low-risk investment if kept plain and UI-neutral. It reduces churn in later UI work because views can depend on stable `SpillStatusItem` and `SpillAction` values instead of provider-specific structs.

### Why Now

Existing run artifacts already point toward `SpillStatusItem`, `SpillAction`, and provider placeholders, but the codebase currently has concrete menu bar scanner snapshots rather than a general provider model. Adding the foundation first allows future agents to work in parallel on providers and views with less cross-file conflict.

### Cost of Not Building

- Provider implementations may diverge on identity, display labels, disabled states, and error handling.
- UI code may become coupled to specific scanner or system APIs.
- Later refactors would touch more files and carry greater regression risk.

## Constraints

- macOS/public API constraints: use public Swift/AppKit/Foundation APIs only; no private macOS APIs.
- permission constraints: model definitions must not request Accessibility, Screen Recording, network, or file permissions.
- distribution constraints: keep types compatible with the current Swift Package app target.
- performance constraints: model construction should be cheap; providers should support async or cached reads without forcing polling behavior.
- collaboration constraints: do not revert or overwrite unrelated work; future builders must keep write scopes narrow.

## Non-goals

- No UI redesign.
- No new provider implementations with real system, AI, or window behavior.
- No changes to menu bar trigger behavior.
- No changes to preferences, persistence, login item behavior, or scanner behavior.
- No global documentation edits as part of this planning run.

## Open Questions

- UI mapping is deferred until the Stitch panel design is implemented.
- Real provider actor isolation may need refinement once system, AI, and window providers exist.

## Decision

Status: `accepted`

Reason: The feature is needed as a narrow, source-level foundation for future provider work and can be designed with no user-visible behavior change.
