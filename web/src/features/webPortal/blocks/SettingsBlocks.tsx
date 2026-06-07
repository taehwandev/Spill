import { MaterialIcon } from "../components/MaterialIcon";
import type {
  SpillAuthState,
  SpillDeviceAccessState
} from "../model/spillAuth";

function formatDeviceDate(value: string | null): string {
  if (!value) {
    return "Not yet";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "Unavailable";
  }

  return new Intl.DateTimeFormat(undefined, {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(date);
}

function deviceLabel(index: number): string {
  return `Mac ${index + 1}`;
}

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
          <p>Prompt text stays on the device.</p>
        </article>
        <article>
          <strong>Responses</strong>
          <p>Generated output content is not uploaded or shown here.</p>
        </article>
        <article>
          <strong>Logs & Source</strong>
          <p>Commands, file paths, logs, diffs, and source content stay local.</p>
        </article>
      </div>
    </section>
  );
}

export function DeviceAccessBlock({
  auth,
  devices,
  onRefreshDevices,
  onRevokeDevice
}: {
  auth: SpillAuthState;
  devices: SpillDeviceAccessState;
  onRefreshDevices: () => void;
  onRevokeDevice: (deviceId: string) => void;
}) {
  const signedIn = auth.status === "signed_in";
  const loading = devices.status === "loading";
  const canRefresh = signedIn && !loading;

  return (
    <section className="portalCard settingsSection">
      <div className="settingsSectionHeader withAction">
        <div>
          <MaterialIcon name="devices" />
          <h2>Mac Access</h2>
        </div>
        <button
          className="secondaryAction small"
          disabled={!canRefresh}
          onClick={onRefreshDevices}
          type="button"
        >
          Refresh
        </button>
      </div>

      {!signedIn ? (
        <div className="settingsRow">
          <div>
            <strong>Sign in required</strong>
            <p>Mac access controls are available after account sign in.</p>
          </div>
        </div>
      ) : devices.status === "error" ? (
        <div className="settingsRow">
          <div>
            <strong>Unable to load Macs</strong>
            <p>Try again after refreshing your account session.</p>
          </div>
        </div>
      ) : devices.devices.length === 0 ? (
        <div className="settingsRow">
          <div>
            <strong>No Macs connected</strong>
            <p>Connect the desktop app to manage Mac access from here.</p>
          </div>
        </div>
      ) : (
        <div className="deviceList compact" aria-label="Mac access list">
          {devices.devices.map((device, index) => {
            const revoked = Boolean(device.revoked_at);
            const revoking = devices.revokingDeviceId === device.id;

            return (
              <article className={`deviceItem ${revoked ? "revoked" : ""}`} key={device.id}>
                <span className="appIcon">
                  <MaterialIcon name="laptop_mac" />
                </span>
                <div className="deviceBody">
                  <div className="deviceTitleRow">
                    <strong>{deviceLabel(index)}</strong>
                    <span>{revoked ? "Disconnected" : "Active"}</span>
                  </div>
                  <small>Last backup: {formatDeviceDate(device.last_upload_at)}</small>
                </div>
                <div className="deviceMetric">
                  {revoked ? (
                    <span>{formatDeviceDate(device.revoked_at)}</span>
                  ) : (
                    <button
                      className="dangerTextButton"
                      disabled={revoking}
                      onClick={() => onRevokeDevice(device.id)}
                      type="button"
                    >
                      {revoking ? "Disconnecting" : "Disconnect"}
                    </button>
                  )}
                </div>
              </article>
            );
          })}
        </div>
      )}
    </section>
  );
}
