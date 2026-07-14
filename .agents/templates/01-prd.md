# Detailed PRD: <Feature Name>

## PRD Authoring Gate

Do not author this PRD until `00-intake.md` has `Decision: build` and all clarifying questions are resolved. If intent, scope, value, UI behavior, feasibility, permissions, or distribution impact is unclear, return to `00-intake.md`, ask the maintainer, and stop here.

## Summary

One paragraph describing the feature.

## Resolved Inputs

- maintainer decisions:
- repo-researched facts:
- assumptions:

## Goals

- 

## Non-goals

- 

## User Stories

- As a user, I want to ...

## UX Requirements

### Entry Point

How does the user find/use it?

### Layout

What appears in the compact panel?

### States

- loading:
- empty:
- unavailable:
- permission required:
- success:
- failure:

## Functional Requirements

1. 

## Settings And Surface Acceptance

If the feature changes settings or user-visible configuration, carry the accepted
impact map from `00-intake.md` into observable requirements.

- persistence/default/migration behavior:
- propagation and update-latency contract:
- behavior when a receiving process or surface is closed, open, stale, or unavailable:

| Surface | Expected observable result | Acceptance evidence |
| --- | --- | --- |
| Preferences |  |  |
| Compact Spill Panel / general dashboard |  |  |
| Separate AI Token Metering dashboard helper |  |  |
| Clock-adjacent AI menu-bar glance |  |  |
| Other dashboard, menu-bar, web, sync, or agent-facing surface |  |  |

## Behavior Scenarios

### Main Path

Given <starting state>
When <user action or system event>
Then <observable result>

### Relevant Edge States

Given <empty, unavailable, permission-required, success, or failure state>
When <user action or system event>
Then <observable result>

## Acceptance Criteria

- 

## Metrics

- perceived latency:
- reliability:
- resource use:

## Rollout

- MVP:
- later:

## References

- 
