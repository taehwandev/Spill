import type React from "react";
import { AuthControls } from "./AuthControls";
import type { SpillAuthProvider, SpillAuthState } from "../model/spillAuth";
import type { PortalRoute } from "../routes";
import { MaterialIcon } from "./MaterialIcon";

export function AppChrome({
  activeRoute,
  auth,
  children,
  onNavigate,
  onSignIn,
  onSignOut
}: {
  activeRoute: Exclude<PortalRoute, "onboarding">;
  auth: SpillAuthState;
  children: React.ReactNode;
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  const profileTitle = auth.status === "signed_in"
    ? "Account Connected"
    : "Local Dashboard";
  const profileDetail = auth.status === "signed_in" && auth.viewer.role === "admin"
    ? "Admin access enabled"
    : auth.status === "signed_in"
      ? "Signed in"
      : "No account required";

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
            <small>Local Usage</small>
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
            <strong>{profileTitle}</strong>
            <small>{profileDetail}</small>
          </span>
        </div>
      </aside>

      <header className="topBar">
        <div className="topStatus">
          <span className="statusDot" aria-hidden="true" />
          <strong>Local Usage</strong>
          <span>Content stays on this device</span>
        </div>
        <div className="topActions">
          <AuthControls state={auth} onSignIn={onSignIn} onSignOut={onSignOut} />
          <button aria-label="Refresh dashboard" type="button">
            <MaterialIcon name="refresh" />
          </button>
          <span className="avatarBadge" aria-label="Spill dashboard">
            SP
          </span>
        </div>
      </header>

      <main className="workspace">{children}</main>
    </div>
  );
}
