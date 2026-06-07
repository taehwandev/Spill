import { useCallback, useEffect, useMemo, useState } from "react";
import { buildDashboardModel } from "../tokenMeteringDashboard/dashboardModel";
import { demoUsageEvents } from "../tokenMeteringDashboard/demoUsage";
import type { AuthProviderId } from "./model/syncSecurityPolicy";
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

  const dashboard = useMemo(() => buildDashboardModel(demoUsageEvents), []);

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

  const handleAuth = useCallback((provider: AuthProviderId) => {
    void provider;
    navigate("dashboard");
  }, [navigate]);

  if (route === "dashboard") {
    return <PortalDashboardPage dashboard={dashboard} onNavigate={navigate} />;
  }

  if (route === "settings") {
    return <SettingsPage onNavigate={navigate} />;
  }

  return (
    <OnboardingPage
      copiedInstall={copiedInstall}
      dashboard={dashboard}
      onAuth={handleAuth}
      onCopyInstall={copyInstall}
      onNavigate={navigate}
    />
  );
}
