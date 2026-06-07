import { useCallback, useEffect, useMemo, useState } from "react";
import {
  buildPortalDashboardPreviewModel,
  buildPortalDashboardPreviewView
} from "./model/dashboardPreview";
import { useSpillAuth } from "./hooks/useSpillAuth";
import { AdminPage } from "./pages/AdminPage";
import { OnboardingPage } from "./pages/OnboardingPage";
import { PortalDashboardPage } from "./pages/PortalDashboardPage";
import { SettingsPage } from "./pages/SettingsPage";
import { ProtectedRouteScreen } from "./screens/ProtectedRouteScreen";
import {
  isProtectedPortalRoute,
  parsePortalRoute,
  portalRoutePath,
  type PortalRoute
} from "./routes";

function currentRoute(): PortalRoute {
  if (typeof window === "undefined") {
    return "onboarding";
  }

  return parsePortalRoute(window.location.hash);
}

function replacePortalRoute(route: PortalRoute) {
  window.history.replaceState(null, "", `/#${portalRoutePath(route)}`);
}

export function WebPortal() {
  const [route, setRoute] = useState<PortalRoute>(() => currentRoute());
  const [copiedInstall, setCopiedInstall] = useState(false);

  const dashboardPreview = useMemo(() => buildPortalDashboardPreviewModel(), []);
  const onboardingDashboard = useMemo(() => buildPortalDashboardPreviewView({
    aiToolId: dashboardPreview.defaultAiToolId,
    dateId: dashboardPreview.defaultDateId,
    scopeId: dashboardPreview.defaultScopeId
  }).dashboard, [dashboardPreview]);
  const onAuthReady = useCallback(() => {
    replacePortalRoute("dashboard");
    setRoute("dashboard");
  }, []);
  const auth = useSpillAuth({ onAuthReady });

  useEffect(() => {
    const onHashChange = () => setRoute(currentRoute());
    window.addEventListener("hashchange", onHashChange);
    return () => window.removeEventListener("hashchange", onHashChange);
  }, []);

  const navigate = useCallback((nextRoute: PortalRoute) => {
    const nextPath = portalRoutePath(nextRoute);
    if (window.location.hash !== `#${nextPath}`) {
      window.location.hash = nextPath;
    }
    setRoute(nextRoute);
  }, []);

  const copyInstall = useCallback(async () => {
    const command = '/bin/bash -c "$(curl -fsSL https://spill.thdev.app/install.sh)"';
    if (navigator.clipboard) {
      await navigator.clipboard.writeText(command);
    }
    setCopiedInstall(true);
    window.setTimeout(() => setCopiedInstall(false), 1800);
  }, []);

  if (isProtectedPortalRoute(route)) {
    if (auth.state.status !== "signed_in") {
      return (
        <ProtectedRouteScreen
          auth={auth.state}
          authProviders={auth.providers}
          route={route}
          onNavigate={navigate}
          onSignIn={auth.signIn}
          onSignOut={auth.signOut}
        />
      );
    }

    if (route === "admin" && auth.state.viewer.role !== "admin") {
      return (
        <ProtectedRouteScreen
          auth={auth.state}
          authProviders={auth.providers}
          route={route}
          onNavigate={navigate}
          onSignIn={auth.signIn}
          onSignOut={auth.signOut}
        />
      );
    }
  }

  if (route === "dashboard") {
    return (
      <PortalDashboardPage
        auth={auth.state}
        authProviders={auth.providers}
        dashboardPreview={dashboardPreview}
        onNavigate={navigate}
        onSignIn={auth.signIn}
        onSignOut={auth.signOut}
      />
    );
  }

  if (route === "settings") {
    return (
      <SettingsPage
        auth={auth.state}
        authProviders={auth.providers}
        devices={auth.devices}
        onNavigate={navigate}
        onRefreshDevices={auth.refreshDevices}
        onRevokeDevice={auth.revokeDevice}
        onSignIn={auth.signIn}
        onSignOut={auth.signOut}
      />
    );
  }

  if (route === "admin") {
    return (
      <AdminPage
        auth={auth.state}
        authProviders={auth.providers}
        onNavigate={navigate}
        onSignIn={auth.signIn}
        onSignOut={auth.signOut}
      />
    );
  }

  return (
    <OnboardingPage
      auth={auth.state}
      authProviders={auth.providers}
      copiedInstall={copiedInstall}
      dashboard={onboardingDashboard}
      onCopyInstall={copyInstall}
      onNavigate={navigate}
      onSignIn={auth.signIn}
      onSignOut={auth.signOut}
    />
  );
}
