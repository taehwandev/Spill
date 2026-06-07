import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const repoRoot = new URL("../../", import.meta.url);

const webPortalRenderFiles = [
  "src/features/webPortal/WebPortal.tsx",
  "src/features/webPortal/pages/OnboardingPage.tsx",
  "src/features/webPortal/pages/PortalDashboardPage.tsx",
  "src/features/webPortal/pages/SettingsPage.tsx",
  "src/features/webPortal/screens/OnboardingScreen.tsx",
  "src/features/webPortal/screens/DashboardScreen.tsx",
  "src/features/webPortal/screens/SettingsScreen.tsx",
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
  /safe enum/i
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
