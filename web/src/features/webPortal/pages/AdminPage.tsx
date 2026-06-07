import type {
  SpillAuthProvider,
  SpillAuthProviderOption,
  SpillAuthState
} from "../model/spillAuth";
import type { PortalRoute } from "../routes";
import { AdminScreen } from "../screens/AdminScreen";

export function AdminPage(props: {
  auth: SpillAuthState;
  authProviders: readonly SpillAuthProviderOption[];
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  return <AdminScreen {...props} />;
}
