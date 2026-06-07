import type React from "react";
import { connectedDevices } from "../model/syncSecurityPolicy";
import type { PortalRoute } from "../routes";
import { MaterialIcon } from "./MaterialIcon";

export function AppChrome({
  activeRoute,
  children,
  onNavigate
}: {
  activeRoute: Exclude<PortalRoute, "onboarding">;
  children: React.ReactNode;
  onNavigate: (route: PortalRoute) => void;
}) {
  return (
    <div className="appChrome">
      <aside className="sideNav" aria-label="Spill web navigation">
        <button
          className="sideBrand"
          onClick={() => onNavigate("onboarding")}
          type="button"
        >
          <span className="brandGlyph">
            <MaterialIcon filled name="fluid_med" />
          </span>
          <span>
            <strong>Spill</strong>
            <small>AI Monitoring</small>
          </span>
        </button>

        <nav className="sideNavItems">
          <button
            className={`sideNavItem ${activeRoute === "dashboard" ? "active" : ""}`}
            onClick={() => onNavigate("dashboard")}
            type="button"
          >
            <MaterialIcon name="dashboard" />
            Dashboard
          </button>
          <button
            className={`sideNavItem ${activeRoute === "settings" ? "active" : ""}`}
            onClick={() => onNavigate("settings")}
            type="button"
          >
            <MaterialIcon filled={activeRoute === "settings"} name="settings" />
            Settings
          </button>
        </nav>

        <div className="sideProfile">
          <MaterialIcon name="account_circle" />
          <span>
            <strong>GitHub Profile</strong>
            <small>OAuth pending</small>
          </span>
        </div>
      </aside>

      <header className="topBar">
        <div className="topStatus">
          <span className="statusDot" aria-hidden="true" />
          <strong>Local Sync: Active</strong>
          <span>Devices: {connectedDevices.length}</span>
        </div>
        <div className="topActions">
          <button aria-label="Refresh dashboard" type="button">
            <MaterialIcon name="refresh" />
          </button>
          <button aria-label="Copy sync invite" type="button">
            <MaterialIcon name="content_copy" />
          </button>
          <span className="avatarBadge" aria-label="Signed in preview user">
            SP
          </span>
        </div>
      </header>

      <main className="workspace">{children}</main>
    </div>
  );
}
