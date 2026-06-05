import { type DashboardModel } from "../dashboardModel";
import { getTokenMeteringMessages } from "../i18n";
import { SYNC_MODES, type SyncMode } from "../syncSafeUsage";

export function SyncContractPanel({
  dashboard,
  onClose,
  setSyncMode,
  syncMode
}: {
  dashboard: DashboardModel;
  onClose: () => void;
  setSyncMode: (mode: SyncMode) => void;
  syncMode: SyncMode;
}) {
  const messages = getTokenMeteringMessages();
  const syncModeContent = messages.syncModeContent;

  return (
    <aside aria-label={messages.syncContract.ariaLabel} className="contractPanel open">
      <div className="contractPanelInner">
        <div className="contractPanelHeader">
          <h2>{messages.syncContract.title}</h2>
          <button aria-label={messages.syncContract.closeAria} onClick={onClose} type="button">
            x
          </button>
        </div>

        <div className="modePills" role="radiogroup" aria-label={messages.syncContract.syncModeAria}>
          {SYNC_MODES.map((mode) => (
            <button
              aria-checked={mode === syncMode}
              className={mode === syncMode ? "modePill active" : "modePill"}
              key={mode}
              onClick={() => setSyncMode(mode)}
              role="radio"
              type="button"
            >
              <span>{syncModeContent[mode].label}</span>
              <small>{syncModeContent[mode].status}</small>
            </button>
          ))}
        </div>

        <div className="contractSteps">
          <div>
            <span>1</span>
            <div>
              <strong>{messages.syncContract.signInFirstTitle}</strong>
              <p>{messages.syncContract.signInFirstBody}</p>
            </div>
          </div>
          <div>
            <span>2</span>
            <div>
              <strong>{messages.syncContract.chooseDepthTitle}</strong>
              <p>{messages.syncContract.chooseDepthBody}</p>
            </div>
          </div>
          <div>
            <span>3</span>
            <div>
              <strong>{messages.syncContract.allowlistTitle}</strong>
              <p>
                {messages.syncContract.allowlistBody(dashboard.privacyAudit.allowedFieldCount)}
              </p>
            </div>
          </div>
        </div>

        <button className="panelPrimary" onClick={onClose} type="button">
          {messages.syncContract.close}
        </button>
      </div>
    </aside>
  );
}
