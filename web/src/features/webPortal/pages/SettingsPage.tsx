import type {
  SpillAuthProvider,
  SpillAuthProviderOption,
  SpillAuthState,
  SpillDeviceAccessState
} from "../model/spillAuth";
import type { PortalRoute } from "../routes";
import { SettingsScreen } from "../screens/SettingsScreen";

export function SettingsPage(props: {
  auth: SpillAuthState;
  authProviders: readonly SpillAuthProviderOption[];
  devices: SpillDeviceAccessState;
  onNavigate: (route: PortalRoute) => void;
  onRefreshDevices: () => void;
  onRevokeDevice: (deviceId: string) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  return <SettingsScreen {...props} />;
}
