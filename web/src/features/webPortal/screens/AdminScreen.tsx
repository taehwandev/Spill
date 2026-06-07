import { AppChrome } from "../components/AppChrome";
import { MaterialIcon } from "../components/MaterialIcon";
import type {
  SpillAuthProvider,
  SpillAuthProviderOption,
  SpillAuthState
} from "../model/spillAuth";
import type { PortalRoute } from "../routes";

export function AdminScreen({
  auth,
  authProviders,
  onNavigate,
  onSignIn,
  onSignOut
}: {
  auth: SpillAuthState;
  authProviders: readonly SpillAuthProviderOption[];
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  const isAdmin = auth.status === "signed_in" && auth.viewer.role === "admin";

  return (
    <AppChrome
      activeRoute="admin"
      auth={auth}
      authProviders={authProviders}
      onNavigate={onNavigate}
      onSignIn={onSignIn}
      onSignOut={onSignOut}
    >
      <div className="pageHeader">
        <div>
          <h1>{isAdmin ? "Administration" : "Access Unavailable"}</h1>
          <p>{isAdmin ? "Account controls and access policy." : "This area is limited to account administrators."}</p>
        </div>
      </div>

      {isAdmin ? (
        <section className="adminGrid" aria-label="Administration controls">
          <article className="portalCard adminPanel">
            <MaterialIcon name="verified_user" />
            <div>
              <h2>Account Access</h2>
              <p>Role changes and device actions are checked at the account boundary.</p>
            </div>
          </article>
          <article className="portalCard adminPanel">
            <MaterialIcon name="devices" />
            <div>
              <h2>Mac Access</h2>
              <p>Each Mac uses a separate access credential that can be disconnected independently.</p>
            </div>
          </article>
        </section>
      ) : (
        <section className="portalCard adminPanel denied">
          <MaterialIcon name="lock" />
          <div>
            <h2>Not Available</h2>
            <p>Sign in with an administrator account to continue.</p>
          </div>
        </section>
      )}
    </AppChrome>
  );
}
