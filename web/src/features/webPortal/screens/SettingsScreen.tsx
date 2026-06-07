import {
  ConnectedDevicesBlock,
  GeneralSettingsBlock,
  LocalOnlyContentBlock,
  LoginProvidersBlock,
  SyncPrivacyBlock
} from "../blocks/SettingsBlocks";
import { AppChrome } from "../components/AppChrome";
import type { PortalRoute } from "../routes";

export function SettingsScreen({
  onNavigate
}: {
  onNavigate: (route: PortalRoute) => void;
}) {
  return (
    <AppChrome activeRoute="settings" onNavigate={onNavigate}>
      <div className="pageHeader">
        <div>
          <h1>Settings</h1>
          <p>Manage auth providers, sync depth, privacy controls, and connected hardware.</p>
        </div>
      </div>

      <div className="settingsStack">
        <GeneralSettingsBlock />
        <LoginProvidersBlock />
        <SyncPrivacyBlock />
        <ConnectedDevicesBlock />
        <LocalOnlyContentBlock />
      </div>

      <footer className="settingsFooter">
        <button type="button">Discard Changes</button>
        <button className="primaryAction" type="button">Save Preferences</button>
      </footer>
    </AppChrome>
  );
}
