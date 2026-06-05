import type { DashboardModel } from "../dashboardModel";
import type { SyncMode } from "../syncSafeUsage";
import { CollapsiblePanel } from "./CollapsiblePanel";

export function PrivacySettings({
  dashboard,
  syncMode
}: {
  dashboard: DashboardModel;
  syncMode: SyncMode;
}) {
  const rows = [
    {
      label: "Local-only mode",
      state: syncMode === "local_only" ? "Active" : "Available",
      detail: "Sends nothing. Full detail remains on this computer."
    },
    {
      label: "Cloud aggregate",
      state: syncMode === "cloud_aggregate" ? "Demo selected" : "Future opt-in",
      detail: "Would send totals, timestamps, model ids, and latency only."
    },
    {
      label: "Cloud detailed",
      state: syncMode === "cloud_detailed" ? "Demo selected" : "Separate opt-in",
      detail: "Would send numeric counts plus task and source enum labels."
    }
  ];

  return (
    <CollapsiblePanel
      description="Local detail first, cloud sync only by explicit opt-in"
      id="settings"
      title="Token-Only Contract"
    >
      <div className="settingsList">
        {rows.map((row) => (
          <div className="settingsRow" key={row.label}>
            <div>
              <strong>{row.label}</strong>
              <p>{row.detail}</p>
            </div>
            <span>{row.state}</span>
          </div>
        ))}
      </div>

      <div className="auditBlock">
        <div>
          <strong>Sanitizer status</strong>
          <p>
            {dashboard.privacyAudit.eventsPrepared} sync-safe events prepared /
            {dashboard.privacyAudit.allowedFieldCount} allowed fields emitted /
            {dashboard.privacyAudit.emittedFieldsSafe ? " safe output" : " review needed"}
          </p>
        </div>
        <span className={dashboard.privacyAudit.emittedFieldsSafe ? "okBadge" : "warnBadge"}>
          {dashboard.privacyAudit.emittedFieldsSafe ? "Allowlist pass" : "Check"}
        </span>
      </div>

      <div className="forbiddenBlock">
        <strong>Never included in cloud payloads</strong>
        <div>
          {dashboard.privacyAudit.forbiddenLabels.map((label) => (
            <span key={label}>{label}</span>
          ))}
        </div>
      </div>
    </CollapsiblePanel>
  );
}
