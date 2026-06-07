import {
  DeviceAccessBlock,
  GeneralSettingsBlock,
  LocalOnlyContentBlock
} from "../blocks/SettingsBlocks";
import { AppChrome } from "../components/AppChrome";
import type {
  SpillAuthProvider,
  SpillAuthProviderOption,
  SpillAuthState,
  SpillDeviceAccessState
} from "../model/spillAuth";
import type { PortalRoute } from "../routes";

export function SettingsScreen({
  auth,
  authProviders,
  devices,
  onNavigate,
  onRefreshDevices,
  onRevokeDevice,
  onSignIn,
  onSignOut
}: {
  auth: SpillAuthState;
  authProviders: readonly SpillAuthProviderOption[];
  devices: SpillDeviceAccessState;
  onNavigate: (route: PortalRoute) => void;
  onRefreshDevices: () => void;
  onRevokeDevice: (deviceId: string) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  return (
    <AppChrome
      activeRoute="settings"
      auth={auth}
      authProviders={authProviders}
      onNavigate={onNavigate}
      onSignIn={onSignIn}
      onSignOut={onSignOut}
    >
      <div className="pageHeader">
        <div>
          <h1>Settings</h1>
          <p>Manage app preferences and privacy.</p>
        </div>
      </div>

      <div className="settingsStack">
        <GeneralSettingsBlock />
        <DeviceAccessBlock
          auth={auth}
          devices={devices}
          onRefreshDevices={onRefreshDevices}
          onRevokeDevice={onRevokeDevice}
        />
        <LocalOnlyContentBlock />
      </div>
    </AppChrome>
  );
}
