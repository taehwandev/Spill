import test from "node:test";
import assert from "node:assert/strict";
import {
  assertNoUnsafeDeviceProfileKeys,
  authProviders,
  connectedDevices,
  syncTransportControls
} from "../src/features/webPortal/model/syncSecurityPolicy.ts";

test("web portal models Google and GitHub as planned auth providers", () => {
  assert.deepEqual(authProviders.map((provider) => provider.id).sort(), [
    "github",
    "google"
  ]);
  assert.equal(authProviders.every((provider) => provider.status === "planned"), true);
});

test("cloud sync policy requires HTTPS and E2EE controls", () => {
  const requiredControls = new Map(
    syncTransportControls.map((control) => [control.id, control])
  );

  assert.equal(requiredControls.get("https")?.required, true);
  assert.equal(requiredControls.get("e2ee")?.required, true);
  assert.equal(requiredControls.get("payload")?.value, "Token-only");
});

test("connected device display models expose only safe public fields", () => {
  for (const device of connectedDevices) {
    assert.deepEqual(assertNoUnsafeDeviceProfileKeys(device), []);
  }
});
