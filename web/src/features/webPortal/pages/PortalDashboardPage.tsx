import type { DashboardModel } from "../../tokenMeteringDashboard/dashboardModel";
import type { SpillAuthProvider, SpillAuthState } from "../model/spillAuth";
import type { PortalRoute } from "../routes";
import { DashboardScreen } from "../screens/DashboardScreen";

export function PortalDashboardPage(props: {
  auth: SpillAuthState;
  dashboard: DashboardModel;
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  return <DashboardScreen {...props} />;
}
