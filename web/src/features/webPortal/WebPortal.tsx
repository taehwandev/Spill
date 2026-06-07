import { useCallback, useEffect, useMemo, useState } from "react";
import { buildDashboardModel } from "../tokenMeteringDashboard/dashboardModel";
import { useSpillAuth } from "./hooks/useSpillAuth";
import { OnboardingPage } from "./pages/OnboardingPage";
import { PortalDashboardPage } from "./pages/PortalDashboardPage";
import { SettingsPage } from "./pages/SettingsPage";
import {
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

export function WebPortal() {
  const [route, setRoute] = useState<PortalRoute>(() => currentRoute());
  const [copiedInstall, setCopiedInstall] = useState(false);

  const dashboard = useMemo(() => buildDashboardModel([]), []);
  const onAuthReady = useCallback(() => setRoute(currentRoute()), []);
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

  if (route === "dashboard") {
    return (
      <PortalDashboardPage
        auth={auth.state}
        dashboard={dashboard}
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
        onNavigate={navigate}
        onSignIn={auth.signIn}
        onSignOut={auth.signOut}
      />
    );
  }

  return (
    <OnboardingPage
      auth={auth.state}
      copiedInstall={copiedInstall}
      dashboard={dashboard}
      onCopyInstall={copyInstall}
      onNavigate={navigate}
      onSignIn={auth.signIn}
      onSignOut={auth.signOut}
    />
  );
}
