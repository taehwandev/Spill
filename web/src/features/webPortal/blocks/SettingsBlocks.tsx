import { ConnectedDeviceList } from "../components/ConnectedDeviceList";
import { MaterialIcon } from "../components/MaterialIcon";
import { SecurityControlGrid } from "../components/SecurityControlGrid";
import {
  authProviders,
  syncDepthOptions
} from "../model/syncSecurityPolicy";

export function GeneralSettingsBlock() {
  return (
    <section className="portalCard settingsSection">
      <div className="settingsSectionHeader">
        <MaterialIcon name="tune" />
        <h2>General</h2>
      </div>

      <div className="settingsRows">
        <div className="settingsRow">
          <div>
            <strong>Launch at Login</strong>
            <p>Automatically start Spill when you log into your system.</p>
          </div>
          <label className="switchControl">
            <input defaultChecked type="checkbox" />
            <span />
          </label>
        </div>
        <div className="settingsRow">
          <div>
            <strong>App Theme</strong>
            <p>Choose your preferred visual style for the application.</p>
          </div>
          <div className="segmentedPill" aria-label="Theme">
            <button className="active" type="button">Light</button>
            <button type="button">Dark</button>
            <button type="button">System</button>
          </div>
        </div>
      </div>
    </section>
  );
}

export function LoginProvidersBlock() {
  return (
    <section className="portalCard settingsSection">
      <div className="settingsSectionHeader withAction">
        <div>
          <MaterialIcon name="account_circle" />
          <h2>Login Providers</h2>
        </div>
        <span className="requiredPill">Server session required</span>
      </div>

      <div className="providerGrid">
        {authProviders.map((provider) => (
          <article className="providerCard" key={provider.id}>
            <strong>{provider.shortLabel}</strong>
            <span>{provider.status}</span>
            <p>{provider.detail}</p>
            <button type="button">{provider.label}</button>
          </article>
        ))}
      </div>
    </section>
  );
}

export function SyncPrivacyBlock() {
  return (
    <section className="portalCard settingsSection">
      <div className="settingsSectionHeader withAction">
        <div>
          <MaterialIcon name="security" />
          <h2>Sync & Privacy</h2>
        </div>
        <span className="requiredPill">Encrypted</span>
      </div>

      <div className="syncDepthGrid" aria-label="Cloud sync depth">
        {syncDepthOptions.map((option) => (
          <button
            className={option.id === "cloud_aggregate" ? "syncDepth active" : "syncDepth"}
            key={option.id}
            type="button"
          >
            <MaterialIcon filled={option.id === "cloud_aggregate"} name={option.icon} />
            <strong>{option.label}</strong>
            <span>{option.description}</span>
          </button>
        ))}
      </div>

      <SecurityControlGrid />
    </section>
  );
}

export function ConnectedDevicesBlock() {
  return (
    <section className="portalCard settingsSection">
      <div className="settingsSectionHeader withAction">
        <div>
          <MaterialIcon name="devices" />
          <h2>Connected Devices</h2>
        </div>
        <button className="dangerTextButton" type="button">Revoke All</button>
      </div>

      <ConnectedDeviceList />
    </section>
  );
}

export function LocalOnlyContentBlock() {
  return (
    <section className="portalCard settingsSection">
      <div className="settingsSectionHeader">
        <MaterialIcon name="terminal" />
        <h2>Local-only Content</h2>
      </div>

      <div className="localOnlyGrid">
        <article>
          <strong>Prompts</strong>
          <p>Never synced. Prompt text stays on the device and is excluded from web DTOs.</p>
        </article>
        <article>
          <strong>Responses</strong>
          <p>Never synced. Generated output content is not uploaded or shown here.</p>
        </article>
        <article>
          <strong>Logs & Source</strong>
          <p>Never synced. Commands, file paths, logs, diffs, and source content are blocked.</p>
        </article>
      </div>
    </section>
  );
}
