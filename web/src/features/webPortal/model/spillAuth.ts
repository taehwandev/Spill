import { createClient, type Provider, type Session, type SupabaseClient } from "@supabase/supabase-js";
import type {
  PrivateUsageRelayConfig,
  SpillViewer
} from "./privateUsageRelay";

export type SpillAuthProvider = "github" | "google";

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

export const SPILL_AUTH_PROVIDERS: readonly {
  id: SpillAuthProvider;
  label: string;
}[] = [
  { id: "github", label: "GitHub" },
  { id: "google", label: "Google" }
];

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
