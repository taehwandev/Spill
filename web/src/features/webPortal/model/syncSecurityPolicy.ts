import type { SyncMode } from "../../tokenMeteringDashboard/syncSafeUsage";

export type AuthProviderId = "github" | "google";

export type AuthProviderViewModel = {
  id: AuthProviderId;
  label: string;
  shortLabel: string;
  status: "planned";
  detail: string;
};

export type TransportControl = {
  id: "https" | "e2ee" | "session" | "payload";
  label: string;
  value: string;
  detail: string;
  required: boolean;
};

export type SyncDepthOption = {
  id: SyncMode;
  label: string;
  icon: string;
  description: string;
};

export type ConnectedDeviceViewModel = {
  id: string;
  displayName: string;
  deviceType: "mac" | "iphone" | "desktop";
  platform: string;
  status: "online" | "idle" | "revoked";
  lastSeenLabel: string;
  syncMode: SyncMode;
  dataScope: string;
  keyStatus: string;
  totalTokensLabel: string;
};

export const authProviders = [
  {
    id: "github",
    label: "Login with GitHub",
    shortLabel: "GitHub",
    status: "planned",
    detail: "OAuth callback will create an HTTP-only server session."
  },
  {
    id: "google",
    label: "Login with Google",
    shortLabel: "Google",
    status: "planned",
    detail: "Google sign-in shares the same server-side session boundary."
  }
] as const satisfies readonly AuthProviderViewModel[];

export const syncTransportControls = [
  {
    id: "https",
    label: "HTTPS",
    value: "Required",
    detail: "All cloud sync endpoints must reject non-TLS production traffic.",
    required: true
  },
  {
    id: "e2ee",
    label: "E2EE",
    value: "Required",
    detail: "Token aggregates are encrypted before leaving the trusted device.",
    required: true
  },
  {
    id: "session",
    label: "Session",
    value: "HTTP-only",
    detail: "OAuth secrets and refresh material stay outside the browser bundle.",
    required: true
  },
  {
    id: "payload",
    label: "Payload",
    value: "Token-only",
    detail: "Prompts, responses, logs, commands, and source content are excluded.",
    required: true
  }
] as const satisfies readonly TransportControl[];

export const syncDepthOptions = [
  {
    id: "local_only",
    label: "Local-only",
    icon: "lock",
    description: "Do not send token usage events to cloud storage."
  },
  {
    id: "cloud_aggregate",
    label: "Aggregate",
    icon: "cloud_done",
    description: "Sync account-level totals, tool breakdowns, and safe enums."
  },
  {
    id: "cloud_detailed",
    label: "Detailed",
    icon: "analytics",
    description: "Sync allowlisted span records without content-bearing fields."
  }
] as const satisfies readonly SyncDepthOption[];

export const connectedDevices = [
  {
    id: "device_preview_macbook",
    displayName: "MacBook Pro M3 Max",
    deviceType: "mac",
    platform: "macOS 15",
    status: "online",
    lastSeenLabel: "2 mins ago",
    syncMode: "cloud_aggregate",
    dataScope: "Aggregate token totals",
    keyStatus: "Device key active",
    totalTokensLabel: "842K"
  },
  {
    id: "device_preview_studio",
    displayName: "Mac Studio",
    deviceType: "desktop",
    platform: "macOS 14",
    status: "idle",
    lastSeenLabel: "4 hours ago",
    syncMode: "cloud_aggregate",
    dataScope: "Aggregate token totals",
    keyStatus: "Device key active",
    totalTokensLabel: "318K"
  },
  {
    id: "device_preview_phone",
    displayName: "iPhone 15 Pro",
    deviceType: "iphone",
    platform: "iOS 18",
    status: "idle",
    lastSeenLabel: "Yesterday",
    syncMode: "local_only",
    dataScope: "No cloud upload",
    keyStatus: "Awaiting approval",
    totalTokensLabel: "0"
  }
] as const satisfies readonly ConnectedDeviceViewModel[];

export const safeDeviceProfileKeys = [
  "id",
  "displayName",
  "deviceType",
  "platform",
  "status",
  "lastSeenLabel",
  "syncMode",
  "dataScope",
  "keyStatus",
  "totalTokensLabel"
] as const;

export function syncModeLabel(mode: SyncMode): string {
  return syncDepthOptions.find((option) => option.id === mode)?.label ?? "Local-only";
}

export function assertNoUnsafeDeviceProfileKeys(
  device: Record<string, unknown>
): string[] {
  return Object.keys(device).filter(
    (key) => !(safeDeviceProfileKeys as readonly string[]).includes(key)
  );
}
