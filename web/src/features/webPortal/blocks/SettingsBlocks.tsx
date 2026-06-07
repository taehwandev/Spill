import { MaterialIcon } from "../components/MaterialIcon";

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
