import { useCallback, useEffect, useMemo, useRef, useState } from "react";
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
  spillAuthProvidersFromEnv,
  type SpillAuthProvider,
  type SpillDeviceAccessState,
  type SpillAuthState
} from "../model/spillAuth";

const unavailableDevices: SpillDeviceAccessState = {
  status: "unavailable",
  devices: [],
  revokingDeviceId: null
};

export function useSpillAuth({
  onAuthReady
}: {
  onAuthReady: () => void;
}) {
  const config = useMemo(() => buildPrivateUsageRelayConfig(import.meta.env), []);
  const providers = useMemo(() => spillAuthProvidersFromEnv(import.meta.env), []);
  const enabledProviderIds = useMemo(
    () => new Set(providers.map((provider) => provider.id)),
    [providers]
  );
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
  const accessTokenRef = useRef<string | null>(null);
  const shouldOpenDashboardAfterSignInRef = useRef(false);
  const [devices, setDevices] = useState<SpillDeviceAccessState>(unavailableDevices);

  const loadDevicesForToken = useCallback(async (accessToken: string) => {
    setDevices((current) => ({
      status: "loading",
      devices: current.devices,
      revokingDeviceId: null
    }));

    const result = await relayClient.listDevices(accessToken);

    if (!result.ok) {
      setDevices((current) => ({
        status: "error",
        devices: current.devices,
        revokingDeviceId: null
      }));
      return;
    }

    setDevices({
      status: "ready",
      devices: result.data.devices,
      revokingDeviceId: null
    });
  }, [relayClient]);

  const loadViewer = useCallback(async (accessToken: string) => {
    accessTokenRef.current = accessToken;
    const viewer = await relayClient.getViewer(accessToken);

    if (!viewer.ok) {
      accessTokenRef.current = null;
      shouldOpenDashboardAfterSignInRef.current = false;
      setState({ status: "error", pendingProvider: null, viewer: null });
      setDevices(unavailableDevices);
      return;
    }

    setState({
      status: "signed_in",
      pendingProvider: null,
      viewer: viewer.data
    });
    if (shouldOpenDashboardAfterSignInRef.current) {
      shouldOpenDashboardAfterSignInRef.current = false;
      onAuthReady();
    }
    void loadDevicesForToken(accessToken);
  }, [loadDevicesForToken, onAuthReady, relayClient]);

  const clearSignedInState = useCallback(() => {
    accessTokenRef.current = null;
    shouldOpenDashboardAfterSignInRef.current = false;
    setState({ status: "signed_out", pendingProvider: null, viewer: null });
    setDevices(unavailableDevices);
  }, []);

  useEffect(() => {
    let active = true;

    if (!authClient) {
      setState({ status: "unconfigured", pendingProvider: null, viewer: null });
      setDevices(unavailableDevices);
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
            shouldOpenDashboardAfterSignInRef.current = true;
          }
        }

        const { data } = await client.auth.getSession();
        if (!active) return;

        if (!isSignedInSession(data.session)) {
          clearSignedInState();
          return;
        }

        await loadViewer(data.session.access_token);
      } catch {
        if (active) {
          setState({ status: "error", pendingProvider: null, viewer: null });
          setDevices(unavailableDevices);
        }
      }
    }

    void bootstrapAuth();

    const { data: listener } = authClient.auth.onAuthStateChange((_event, session) => {
      if (!isSignedInSession(session)) {
        clearSignedInState();
        return;
      }

      void loadViewer(session.access_token);
    });

    return () => {
      active = false;
      listener.subscription.unsubscribe();
    };
  }, [authClient, clearSignedInState, loadViewer, onAuthReady]);

  const signIn = useCallback(async (provider: SpillAuthProvider) => {
    if (!authClient) {
      setState({ status: "unconfigured", pendingProvider: null, viewer: null });
      return;
    }
    if (!enabledProviderIds.has(provider)) {
      return;
    }

    setState({ status: "signed_out", pendingProvider: provider, viewer: null });
    setDevices(unavailableDevices);
    const { error } = await authClient.auth.signInWithOAuth({
      provider: providerToSupabaseProvider(provider),
      options: {
        redirectTo: authCallbackUrl(window.location.origin)
      }
    });

    if (error) {
      setState({ status: "error", pendingProvider: null, viewer: null });
    }
  }, [authClient, enabledProviderIds]);

  const signOut = useCallback(async () => {
    if (!authClient) {
      return;
    }

    await authClient.auth.signOut();
    clearSignedInState();
  }, [authClient, clearSignedInState]);

  const refreshDevices = useCallback(async () => {
    const accessToken = accessTokenRef.current;
    if (!accessToken) {
      setDevices(unavailableDevices);
      return;
    }

    await loadDevicesForToken(accessToken);
  }, [loadDevicesForToken]);

  const revokeDevice = useCallback(async (deviceId: string) => {
    const accessToken = accessTokenRef.current;
    if (!accessToken) {
      setDevices(unavailableDevices);
      return;
    }

    setDevices((current) => ({
      status: current.status === "ready" ? "ready" : "loading",
      devices: current.devices,
      revokingDeviceId: deviceId
    }));

    const result = await relayClient.revokeDevice(accessToken, {
      device_id: deviceId
    });

    if (!result.ok) {
      setDevices((current) => ({
        status: "error",
        devices: current.devices,
        revokingDeviceId: null
      }));
      return;
    }

    setDevices((current) => ({
      status: "ready",
      devices: current.devices.map((device) => (
        device.id === result.data.device_id
          ? { ...device, revoked_at: result.data.revoked_at }
          : device
      )),
      revokingDeviceId: null
    }));
  }, [relayClient]);

  return {
    config,
    devices,
    providers,
    refreshDevices,
    revokeDevice,
    signIn,
    signOut,
    state
  };
}
