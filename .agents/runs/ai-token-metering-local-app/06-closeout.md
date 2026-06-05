# Closeout: AI Token Metering Local App Bridge

## Shipped

- Local Swift token usage event model, sanitizer, file-backed store, and HTTP bridge.
- Native app local token dashboard backed by the app-owned `TokenUsageStore`.
- Local-only app bridge bound to `127.0.0.1:48731`.
- App startup wiring in `AppDelegate`.
- Preferences Token Metering section showing the original product state model:
  unauthenticated local-only, authenticated cloud aggregate after explicit
  enablement, and separate cloud detailed token-only opt-in.
- Status menu and app menu actions to open the native local token dashboard.
- The existing Spill Panel AI section now includes a compact local token
  metering summary; the separate native dashboard remains a detail action.
- Web dashboard reframed as the future signed-in cloud preview rather than the
  installed local dashboard.
- Collapsible web dashboard detail panels for session trace and token-only
  contract details.
- Feature-scoped React refactor so cloud preview UI sections live under
  `features/tokenMeteringDashboard/components`.

## Changed Files

- `Sources/Spill/App/AppDelegate.swift`
- `Sources/Spill/MenuBar/StatusItemController.swift`
- `Sources/Spill/Preferences/PreferencesView.swift`
- `Sources/Spill/Preferences/PreferencesWindowController.swift`
- `Sources/Spill/Preferences/TokenMeteringPreferencesSection.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardView.swift`
- `Sources/Spill/TokenMetering/TokenMeteringDashboardWindowController.swift`
- `Sources/Spill/TokenMetering/TokenMeteringPresentationModel.swift`
- `Sources/Spill/TokenMetering/TokenUsageDashboardStore.swift`
- `Sources/Spill/TokenMetering/TokenUsageBridgeServer.swift`
- `Sources/Spill/TokenMetering/TokenUsageEvent.swift`
- `Sources/Spill/TokenMetering/TokenUsageStore.swift`
- `Tests/SpillTests/TokenUsageStoreTests.swift`
- `web/src/App.tsx`
- `web/src/features/tokenMeteringDashboard/components/*.tsx`
- `web/test/syncSafeUsage.test.ts`

## Verification

- `swift test`: passed; 262 tests.
- `./scripts/build-app.sh`: passed.
- `./scripts/verify-status-click-smoke.sh`: passed; status item primary click
  opened the existing Spill Panel.
- `npm test` from `web/`: passed; 4 sync-safe sanitizer tests.
- `npm run build` from `web/`: passed.
- `curl -sS http://127.0.0.1:48731/v1/usage/health`: returned local app bridge OK.
- `curl -sS http://127.0.0.1:48731/v1/usage/events`: returned schema-versioned safe envelope.
- `git diff --check`: passed.
- VibeGuard audit: passed; Overall Ready, no findings.

## Residual Risks

- Production auth, Supabase database, and cloud ingestion are not implemented in this local-app slice.
- Automatic token extraction from real AI providers is still a follow-up; the
  local dashboard currently reads token-only events written to the app store.
- Visual browser screenshot verification remains a follow-up for the web cloud
  preview; automated web tests cover the cloud sync-safe sanitizer.

## Follow-up Tasks

- Add Supabase Auth/Postgres/RLS in a separate server-backed slice.
- Add upload queue and explicit cloud opt-in after server validation exists.
- Add browser visual smoke or Playwright checks for the dashboard layout.

## Docs Updated

- [x] PRD
- [x] ARD
- [x] task breakdown
- [x] verification
- [ ] README
