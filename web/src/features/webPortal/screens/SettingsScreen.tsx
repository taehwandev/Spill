import {
  GeneralSettingsBlock,
  LocalOnlyContentBlock
} from "../blocks/SettingsBlocks";
import { AppChrome } from "../components/AppChrome";
import type { SpillAuthProvider, SpillAuthState } from "../model/spillAuth";
import type { PortalRoute } from "../routes";

export function SettingsScreen({
  auth,
  onNavigate,
  onSignIn,
  onSignOut
}: {
  auth: SpillAuthState;
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  return (
    <AppChrome
      activeRoute="settings"
      auth={auth}
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
        <LocalOnlyContentBlock />
      </div>
    </AppChrome>
  );
}
