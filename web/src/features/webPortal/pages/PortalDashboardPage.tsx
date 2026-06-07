import type { DashboardModel } from "../../tokenMeteringDashboard/dashboardModel";
import type { PortalRoute } from "../routes";
import { DashboardScreen } from "../screens/DashboardScreen";

export function PortalDashboardPage(props: {
  dashboard: DashboardModel;
  onNavigate: (route: PortalRoute) => void;
}) {
  return <DashboardScreen {...props} />;
}
