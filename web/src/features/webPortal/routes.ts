export type PortalRoute = "onboarding" | "dashboard" | "settings";

const routePaths = {
  onboarding: "/",
  dashboard: "/dashboard",
  settings: "/settings"
} as const satisfies Record<PortalRoute, string>;

export function portalHref(route: PortalRoute): string {
  return `#${routePaths[route]}`;
}

export function parsePortalRoute(hash: string): PortalRoute {
  const normalized = hash.replace(/^#/, "") || "/";

  if (normalized === routePaths.dashboard || normalized === "dashboard") {
    return "dashboard";
  }

  if (normalized === routePaths.settings || normalized === "settings") {
    return "settings";
  }

  return "onboarding";
}

export function portalRoutePath(route: PortalRoute): string {
  return routePaths[route];
}
