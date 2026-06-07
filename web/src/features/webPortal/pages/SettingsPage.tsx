import type { SpillAuthProvider, SpillAuthState } from "../model/spillAuth";
import type { PortalRoute } from "../routes";
import { SettingsScreen } from "../screens/SettingsScreen";

export function SettingsPage(props: {
  auth: SpillAuthState;
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  return <SettingsScreen {...props} />;
}
