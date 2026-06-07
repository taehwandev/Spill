import {
  type SpillAuthProvider,
  type SpillAuthProviderOption,
  type SpillAuthState
} from "../model/spillAuth";
import { MaterialIcon } from "./MaterialIcon";

export function AuthControls({
  providers,
  state,
  onSignIn,
  onSignOut
}: {
  providers: readonly SpillAuthProviderOption[];
  state: SpillAuthState;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  if (state.status === "unconfigured") {
    return (
      <div className="authControls compact">
        <span>Sign in unavailable</span>
      </div>
    );
  }

  if (state.status === "checking") {
    return (
      <div className="authControls compact">
        <MaterialIcon name="sync" />
        <span>Checking account</span>
      </div>
    );
  }

  if (state.status === "signed_in") {
    return (
      <div className="authControls compact">
        <span>{state.viewer.role === "admin" ? "Admin access" : "Account connected"}</span>
        <button className="secondaryAction small" onClick={onSignOut} type="button">
          Sign out
        </button>
      </div>
    );
  }

  if (state.status === "error") {
    return (
      <div className="authControls">
        <span>Sign in failed</span>
        {providers.map((provider) => (
          <button
            className="secondaryAction small"
            key={provider.id}
            onClick={() => onSignIn(provider.id)}
            type="button"
          >
            {provider.label}
          </button>
        ))}
      </div>
    );
  }

  return (
    <div className="authControls">
      {providers.map((provider) => (
        <button
          className="secondaryAction small"
          disabled={state.pendingProvider !== null}
          key={provider.id}
          onClick={() => onSignIn(provider.id)}
          type="button"
        >
          {state.pendingProvider === provider.id ? "Opening..." : `Sign in with ${provider.label}`}
        </button>
      ))}
    </div>
  );
}
