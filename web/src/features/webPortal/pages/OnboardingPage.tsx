import type { DashboardModel } from "../../tokenMeteringDashboard/dashboardModel";
import type { AuthProviderId } from "../model/syncSecurityPolicy";
import type { PortalRoute } from "../routes";
import { OnboardingScreen } from "../screens/OnboardingScreen";

export function OnboardingPage(props: {
  copiedInstall: boolean;
  dashboard: DashboardModel;
  onAuth: (provider: AuthProviderId) => void;
  onCopyInstall: () => void;
  onNavigate: (route: PortalRoute) => void;
}) {
  return <OnboardingScreen {...props} />;
}
