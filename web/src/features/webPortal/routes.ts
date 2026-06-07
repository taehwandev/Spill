export type PortalRoute = "onboarding" | "dashboard" | "settings" | "admin";
export type ProtectedPortalRoute = Exclude<PortalRoute, "onboarding">;

const routePaths = {
  onboarding: "/",
  dashboard: "/dashboard",
  settings: "/settings",
  admin: "/admin"
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

  if (normalized === routePaths.admin || normalized === "admin") {
    return "admin";
  }

  return "onboarding";
}

export function portalRoutePath(route: PortalRoute): string {
  return routePaths[route];
}

export function isProtectedPortalRoute(route: PortalRoute): route is ProtectedPortalRoute {
  return route !== "onboarding";
}
