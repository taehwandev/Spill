import type { PortalRoute } from "../routes";
import { SettingsScreen } from "../screens/SettingsScreen";

export function SettingsPage(props: {
  onNavigate: (route: PortalRoute) => void;
}) {
  return <SettingsScreen {...props} />;
}
