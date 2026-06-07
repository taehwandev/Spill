import { useCallback, useEffect, useMemo, useState } from "react";
import {
  buildPrivateUsageRelayConfig,
  createPrivateUsageRelayClient
} from "../model/privateUsageRelay";
import {
  authCallbackUrl,
  createSpillAuthClient,
  isAuthCallbackUrl,
  isSignedInSession,
  providerToSupabaseProvider,
  type SpillAuthProvider,
  type SpillAuthState
} from "../model/spillAuth";

export function useSpillAuth({
  onAuthReady
}: {
  onAuthReady: () => void;
}) {
  const config = useMemo(() => buildPrivateUsageRelayConfig(import.meta.env), []);
  const relayClient = useMemo(() => createPrivateUsageRelayClient({
    relayFunctionUrl: config.relayFunctionUrl
  }), [config.relayFunctionUrl]);
  const authClient = useMemo(() => createSpillAuthClient({
    config,
    publishableKey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY
  }), [config]);
  const [state, setState] = useState<SpillAuthState>(() => (
    authClient
      ? { status: "checking", pendingProvider: null, viewer: null }
      : { status: "unconfigured", pendingProvider: null, viewer: null }
  ));

  const loadViewer = useCallback(async (accessToken: string) => {
    const viewer = await relayClient.getViewer(accessToken);

    if (!viewer.ok) {
      setState({ status: "error", pendingProvider: null, viewer: null });
      return;
    }

    setState({
      status: "signed_in",
      pendingProvider: null,
      viewer: viewer.data
    });
  }, [relayClient]);

  useEffect(() => {
    let active = true;

    if (!authClient) {
      setState({ status: "unconfigured", pendingProvider: null, viewer: null });
      return;
    }

    const client = authClient;

    async function bootstrapAuth() {
      try {
        if (isAuthCallbackUrl(window.location)) {
          const code = new URLSearchParams(window.location.search).get("code");
          if (code) {
            const { error } = await client.auth.exchangeCodeForSession(code);
            if (error) {
              throw error;
            }
            window.history.replaceState(null, "", "/#/dashboard");
            onAuthReady();
          }
        }

        const { data } = await client.auth.getSession();
        if (!active) return;

        if (!isSignedInSession(data.session)) {
          setState({ status: "signed_out", pendingProvider: null, viewer: null });
          return;
        }

        await loadViewer(data.session.access_token);
      } catch {
        if (active) {
          setState({ status: "error", pendingProvider: null, viewer: null });
        }
      }
    }

    void bootstrapAuth();

    const { data: listener } = authClient.auth.onAuthStateChange((_event, session) => {
      if (!isSignedInSession(session)) {
        setState({ status: "signed_out", pendingProvider: null, viewer: null });
        return;
      }

      void loadViewer(session.access_token);
    });

    return () => {
      active = false;
      listener.subscription.unsubscribe();
    };
  }, [authClient, loadViewer, onAuthReady]);

  const signIn = useCallback(async (provider: SpillAuthProvider) => {
    if (!authClient) {
      setState({ status: "unconfigured", pendingProvider: null, viewer: null });
      return;
    }

    setState({ status: "signed_out", pendingProvider: provider, viewer: null });
    const { error } = await authClient.auth.signInWithOAuth({
      provider: providerToSupabaseProvider(provider),
      options: {
        redirectTo: authCallbackUrl(window.location.origin)
      }
    });

    if (error) {
      setState({ status: "error", pendingProvider: null, viewer: null });
    }
  }, [authClient]);

  const signOut = useCallback(async () => {
    if (!authClient) {
      return;
    }

    await authClient.auth.signOut();
    setState({ status: "signed_out", pendingProvider: null, viewer: null });
  }, [authClient]);

  return {
    config,
    signIn,
    signOut,
    state
  };
}
