import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const repoRoot = new URL("../../", import.meta.url);

const webPortalRenderFiles = [
  "src/features/webPortal/WebPortal.tsx",
  "src/features/webPortal/pages/AdminPage.tsx",
  "src/features/webPortal/pages/OnboardingPage.tsx",
  "src/features/webPortal/pages/PortalDashboardPage.tsx",
  "src/features/webPortal/pages/SettingsPage.tsx",
  "src/features/webPortal/screens/OnboardingScreen.tsx",
  "src/features/webPortal/screens/AdminScreen.tsx",
  "src/features/webPortal/screens/DashboardScreen.tsx",
  "src/features/webPortal/screens/SettingsScreen.tsx",
  "src/features/webPortal/screens/ProtectedRouteScreen.tsx",
  "src/features/webPortal/blocks/OnboardingBlocks.tsx",
  "src/features/webPortal/blocks/DashboardBlocks.tsx",
  "src/features/webPortal/blocks/SettingsBlocks.tsx",
  "src/features/webPortal/components/AuthControls.tsx",
  "src/features/webPortal/components/AppChrome.tsx"
];

const forbiddenUserFacingTerms = [
  /backend/i,
  /relay/i,
  /supabase/i,
  /VITE_/,
  /server session/i,
  /sync security contract/i,
  /cloud sync cannot ship/i,
  /connected devices/i,
  /trusted device/i,
  /desktop app required/i,
  /oauth pending/i,
  /preview user/i,
  /view demo/i,
  /demoUsage/i,
  /token-only cloud contract/i,
  /server-ready/i,
  /HTTP-only/,
  /E2EE/,
  /safe enum/i,
  /Account connection unavailable/i
];

const emailShapedValue = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i;

test("web portal render files do not expose backend setup or placeholder implementation copy", () => {
  for (const relativePath of webPortalRenderFiles) {
    const source = readFileSync(new URL(`web/${relativePath}`, repoRoot), "utf8");

    for (const forbiddenTerm of forbiddenUserFacingTerms) {
      assert.equal(
        forbiddenTerm.test(source),
        false,
        `${relativePath} exposes ${forbiddenTerm}`
      );
    }
  }
});

test("web source does not expose admin bootstrap identity or server-only admin secret names", () => {
  const sourceFiles = [
    ...webPortalRenderFiles,
    "src/features/webPortal/hooks/useSpillAuth.ts",
    "src/features/webPortal/model/privateUsageRelay.ts",
    "src/features/webPortal/model/spillAuth.ts"
  ];

  for (const relativePath of sourceFiles) {
    const source = readFileSync(new URL(`web/${relativePath}`, repoRoot), "utf8");

    assert.doesNotMatch(source, /SPILL_ADMIN_EMAIL/);
    assert.doesNotMatch(source, emailShapedValue);
  }
});

test("admin navigation and route rendering are gated by viewer role", () => {
  const appChrome = readFileSync(
    new URL("web/src/features/webPortal/components/AppChrome.tsx", repoRoot),
    "utf8"
  );
  const adminScreen = readFileSync(
    new URL("web/src/features/webPortal/screens/AdminScreen.tsx", repoRoot),
    "utf8"
  );

  assert.match(appChrome, /auth\.status === "signed_in" && auth\.viewer\.role === "admin"/);
  assert.match(adminScreen, /auth\.status === "signed_in" && auth\.viewer\.role === "admin"/);
  assert.doesNotMatch(appChrome, /SPILL_ADMIN_EMAIL/);
  assert.doesNotMatch(adminScreen, /SPILL_ADMIN_EMAIL/);
});

test("protected portal routes do not render page content without account access", () => {
  const routes = readFileSync(
    new URL("web/src/features/webPortal/routes.ts", repoRoot),
    "utf8"
  );
  const webPortal = readFileSync(
    new URL("web/src/features/webPortal/WebPortal.tsx", repoRoot),
    "utf8"
  );
  const protectedRouteScreen = readFileSync(
    new URL("web/src/features/webPortal/screens/ProtectedRouteScreen.tsx", repoRoot),
    "utf8"
  );

  assert.match(routes, /export function isProtectedPortalRoute/);
  assert.match(webPortal, /isProtectedPortalRoute\(route\)/);
  assert.match(webPortal, /auth\.state\.status !== "signed_in"/);
  assert.match(webPortal, /route === "admin" && auth\.state\.viewer\.role !== "admin"/);
  assert.match(webPortal, /<ProtectedRouteScreen/);
  assert.match(protectedRouteScreen, /Sign in to continue/);
  assert.doesNotMatch(protectedRouteScreen, /Supabase|VITE_|SPILL_ADMIN_EMAIL/);
});

test("auth controls use configured providers instead of a fixed render list", () => {
  const authControls = readFileSync(
    new URL("web/src/features/webPortal/components/AuthControls.tsx", repoRoot),
    "utf8"
  );
  const useSpillAuth = readFileSync(
    new URL("web/src/features/webPortal/hooks/useSpillAuth.ts", repoRoot),
    "utf8"
  );
  const webPortal = readFileSync(
    new URL("web/src/features/webPortal/WebPortal.tsx", repoRoot),
    "utf8"
  );

  assert.match(useSpillAuth, /spillAuthProvidersFromEnv\(import\.meta\.env\)/);
  assert.match(webPortal, /authProviders=\{auth\.providers\}/);
  assert.match(authControls, /providers\.map/);
  assert.doesNotMatch(authControls, /SPILL_AUTH_PROVIDERS/);
});

test("successful OAuth callback opens dashboard without exposing provider internals", () => {
  const webPortal = readFileSync(
    new URL("web/src/features/webPortal/WebPortal.tsx", repoRoot),
    "utf8"
  );
  const useSpillAuth = readFileSync(
    new URL("web/src/features/webPortal/hooks/useSpillAuth.ts", repoRoot),
    "utf8"
  );

  assert.match(webPortal, /replacePortalRoute\("dashboard"\)/);
  assert.match(useSpillAuth, /shouldOpenDashboardAfterSignInRef\.current = true/);
  assert.match(useSpillAuth, /onAuthReady\(\)/);
  assert.doesNotMatch(webPortal, /supabase/i);
});

test("dashboard preview renders period and AI filters with PC comparison cards", () => {
  const dashboardScreen = readFileSync(
    new URL("web/src/features/webPortal/screens/DashboardScreen.tsx", repoRoot),
    "utf8"
  );
  const dashboardBlocks = readFileSync(
    new URL("web/src/features/webPortal/blocks/DashboardBlocks.tsx", repoRoot),
    "utf8"
  );

  assert.match(dashboardScreen, /selectedDateId/);
  assert.match(dashboardScreen, /selectedAiToolId/);
  assert.match(dashboardScreen, /selectedScopeId/);
  assert.match(dashboardScreen, /buildPortalDashboardPreviewView/);
  assert.doesNotMatch(dashboardScreen, /dashboardPreview\.scopes\.map/);
  assert.match(dashboardBlocks, /All Macs/);
  assert.match(dashboardBlocks, /device\.aiToolBreakdown\.map/);
});
