import { createClient, type Provider, type Session, type SupabaseClient } from "@supabase/supabase-js";
import type {
  PrivateUsageRelayConfig,
  RemotePrivateUsageDevice,
  SpillViewer
} from "./privateUsageRelay";

export type SpillAuthProvider = "github" | "google";
export type SpillAuthProviderConfigEnv = {
  readonly VITE_SPILL_AUTH_PROVIDERS?: string;
};
export type SpillAuthProviderOption = {
  readonly id: SpillAuthProvider;
  readonly label: string;
};

export type SpillAuthState =
  | {
      status: "unconfigured";
      pendingProvider: null;
      viewer: null;
    }
  | {
      status: "checking";
      pendingProvider: null;
      viewer: null;
    }
  | {
      status: "signed_out";
      pendingProvider: SpillAuthProvider | null;
      viewer: null;
    }
  | {
      status: "signed_in";
      pendingProvider: null;
      viewer: SpillViewer;
    }
  | {
      status: "error";
      pendingProvider: null;
      viewer: null;
    };

export type SpillDeviceAccessState =
  | {
      status: "unavailable";
      devices: RemotePrivateUsageDevice[];
      revokingDeviceId: null;
    }
  | {
      status: "loading";
      devices: RemotePrivateUsageDevice[];
      revokingDeviceId: string | null;
    }
  | {
      status: "ready";
      devices: RemotePrivateUsageDevice[];
      revokingDeviceId: string | null;
    }
  | {
      status: "error";
      devices: RemotePrivateUsageDevice[];
      revokingDeviceId: null;
    };

export const SPILL_AUTH_PROVIDERS: readonly SpillAuthProviderOption[] = [
  { id: "github", label: "GitHub" },
  { id: "google", label: "Google" }
];

const supportedProviderIds = new Set<SpillAuthProvider>(
  SPILL_AUTH_PROVIDERS.map((provider) => provider.id)
);

export function spillAuthProvidersFromEnv(
  env: SpillAuthProviderConfigEnv
): readonly SpillAuthProviderOption[] {
  const raw = env.VITE_SPILL_AUTH_PROVIDERS?.trim();

  if (!raw) {
    return SPILL_AUTH_PROVIDERS;
  }

  const enabled = new Set(
    raw
      .split(",")
      .map((provider) => provider.trim().toLowerCase())
      .filter((provider): provider is SpillAuthProvider =>
        supportedProviderIds.has(provider as SpillAuthProvider)
      )
  );

  const providers = SPILL_AUTH_PROVIDERS.filter((provider) => enabled.has(provider.id));
  return providers.length > 0 ? providers : SPILL_AUTH_PROVIDERS;
}

export function createSpillAuthClient({
  config,
  publishableKey
}: {
  config: PrivateUsageRelayConfig;
  publishableKey?: string;
}): SupabaseClient | null {
  const key = publishableKey?.trim();
  if (config.status !== "configured" || !key) {
    return null;
  }

  return createClient(config.supabaseUrl, key, {
    auth: {
      autoRefreshToken: true,
      detectSessionInUrl: true,
      flowType: "pkce",
      persistSession: true
    }
  });
}

export function authCallbackUrl(origin: string): string {
  return `${origin.replace(/\/$/, "")}/auth/callback`;
}

export function isAuthCallbackUrl(location: Location): boolean {
  return location.pathname === "/auth/callback" && new URLSearchParams(location.search).has("code");
}

export function providerToSupabaseProvider(provider: SpillAuthProvider): Provider {
  return provider;
}

export function isSignedInSession(session: Session | null): session is Session {
  return Boolean(session?.access_token);
}
