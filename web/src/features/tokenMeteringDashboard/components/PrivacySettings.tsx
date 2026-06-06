import type { DashboardModel } from "../dashboardModel";
import { getTokenMeteringMessages } from "../i18n";
import type { SyncMode } from "../syncSafeUsage";
import { CollapsiblePanel } from "./CollapsiblePanel";

export function PrivacySettings({
  dashboard,
  syncMode,
  onTriggerSelfTest
}: {
  dashboard: DashboardModel;
  syncMode: SyncMode;
  onTriggerSelfTest?: () => void;
}) {
  const messages = getTokenMeteringMessages();
  const rows = [
    {
      label: messages.privacyRows.localOnlyLabel,
      state: syncMode === "local_only" ? messages.privacyRows.active : messages.privacyRows.available,
      detail: messages.privacyRows.localOnlyDetail
    },
    {
      label: messages.privacyRows.cloudAggregateLabel,
      state: syncMode === "cloud_aggregate" ? messages.privacyRows.demoSelected : messages.privacyRows.futureOptIn,
      detail: messages.privacyRows.cloudAggregateDetail
    },
    {
      label: messages.privacyRows.cloudDetailedLabel,
      state: syncMode === "cloud_detailed" ? messages.privacyRows.demoSelected : messages.privacyRows.separateOptIn,
      detail: messages.privacyRows.cloudDetailedDetail
    },
    {
      label: messages.privacyRows.settingsSyncLabel,
      state: messages.privacyRows.separateOptIn,
      detail: messages.privacyRows.settingsSyncDetail
    },
    {
      label: messages.privacyRows.selectedSettingsLabel,
      state: messages.privacyRows.futureOptIn,
      detail: messages.privacyRows.selectedSettingsDetail
    }
  ];

  return (
    <CollapsiblePanel
      description={messages.panels.tokenOnlyContractDescription}
      id="settings"
      title={
        <>
          {messages.panels.tokenOnlyContract}
          <span className="alphaBadge">Alpha</span>
        </>
      }
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
          <strong>{messages.panels.sanitizerStatus}</strong>
          <p>
            {messages.panels.sanitizerDetail(
              dashboard.privacyAudit.eventsPrepared,
              dashboard.privacyAudit.allowedFieldCount,
              dashboard.privacyAudit.emittedFieldsSafe
            )}
          </p>
        </div>
        <span className={dashboard.privacyAudit.emittedFieldsSafe ? "okBadge" : "warnBadge"}>
          {dashboard.privacyAudit.emittedFieldsSafe ? messages.panels.allowlistPass : messages.panels.check}
        </span>
      </div>

      <div className="forbiddenBlock">
        <strong>{messages.panels.neverIncluded}</strong>
        <div>
          {dashboard.privacyAudit.forbiddenLabels.map((label) => (
            <span key={label}>{label}</span>
          ))}
        </div>
      </div>

      {onTriggerSelfTest && (
        <div className="diagnosticsBlock">
          <strong>Diagnostics & Diagnostics Self-Test</strong>
          <p className="diagnosticsDescription">
            The self-test event is local-only, clearly synthetic, uses only numeric buckets and enum labels, and can demonstrate non-unknown source breakdowns without implying real usage classification.
          </p>
          <button className="secondary diagnosticsBtn" onClick={onTriggerSelfTest} type="button">
            Inject Synthetic Self-Test Event
          </button>
        </div>
      )}
    </CollapsiblePanel>
  );
}
