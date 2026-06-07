import type {
  SpillAuthProvider,
  SpillAuthProviderOption,
  SpillAuthState
} from "../model/spillAuth";
import type { PortalDashboardPreviewModel } from "../model/dashboardPreview";
import type { PortalRoute } from "../routes";
import { DashboardScreen } from "../screens/DashboardScreen";

export function PortalDashboardPage(props: {
  auth: SpillAuthState;
  authProviders: readonly SpillAuthProviderOption[];
  dashboardPreview: PortalDashboardPreviewModel;
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  return <DashboardScreen {...props} />;
}
