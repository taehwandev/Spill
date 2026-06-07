import type { DashboardModel } from "../../tokenMeteringDashboard/dashboardModel";
import type { SpillAuthProvider, SpillAuthState } from "../model/spillAuth";
import type { PortalRoute } from "../routes";
import { OnboardingScreen } from "../screens/OnboardingScreen";

export function OnboardingPage(props: {
  auth: SpillAuthState;
  copiedInstall: boolean;
  dashboard: DashboardModel;
  onCopyInstall: () => void;
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  return <OnboardingScreen {...props} />;
}
