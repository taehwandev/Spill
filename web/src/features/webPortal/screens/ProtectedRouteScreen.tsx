import { AuthControls } from "../components/AuthControls";
import { MaterialIcon } from "../components/MaterialIcon";
import type {
  SpillAuthProvider,
  SpillAuthProviderOption,
  SpillAuthState
} from "../model/spillAuth";
import type { PortalRoute, ProtectedPortalRoute } from "../routes";

export function ProtectedRouteScreen({
  auth,
  authProviders,
  route,
  onNavigate,
  onSignIn,
  onSignOut
}: {
  auth: SpillAuthState;
  authProviders: readonly SpillAuthProviderOption[];
  route: ProtectedPortalRoute;
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  const isSignedIn = auth.status === "signed_in";
  const isAdminRoute = route === "admin";
  const title = isSignedIn && isAdminRoute
    ? "Access unavailable"
    : auth.status === "checking"
      ? "Checking account"
      : "Sign in to continue";
  const detail = isSignedIn && isAdminRoute
    ? "This page is not available for this account."
    : "This page is available after account connection.";

  return (
    <div className="protectedPage">
      <header className="protectedHeader">
        <button className="landingBrand" onClick={() => onNavigate("onboarding")} type="button">
          <span className="appIcon">
            <MaterialIcon filled name="fluid_med" />
          </span>
          <strong>Spill</strong>
        </button>
      </header>

      <main className="protectedMain">
        <section className="portalCard protectedPanel" aria-label={title}>
          <span className="protectedIcon">
            <MaterialIcon name={isSignedIn && isAdminRoute ? "lock" : "account_circle"} />
          </span>
          <h1>{title}</h1>
          <p>{detail}</p>
          <div className="protectedActions">
            <AuthControls
              providers={authProviders}
              state={auth}
              onSignIn={onSignIn}
              onSignOut={onSignOut}
            />
            {isSignedIn ? (
              <button className="primaryAction small" onClick={() => onNavigate("dashboard")} type="button">
                Open Dashboard
              </button>
            ) : (
              <button className="secondaryAction small" onClick={() => onNavigate("onboarding")} type="button">
                Back to home
              </button>
            )}
          </div>
        </section>
      </main>
    </div>
  );
}
