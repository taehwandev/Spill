import { syncModeContent, type DashboardModel } from "../dashboardModel";
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
  return (
    <aside aria-label="Sync contract" className="contractPanel open">
      <div className="contractPanelInner">
        <div className="contractPanelHeader">
          <h2>Sync Contract</h2>
          <button aria-label="Close sync contract" onClick={onClose} type="button">
            x
          </button>
        </div>

        <div className="modePills" role="radiogroup" aria-label="Sync mode">
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
              <strong>Sign in first</strong>
              <p>Cloud dashboard rows require an authenticated account.</p>
            </div>
          </div>
          <div>
            <span>2</span>
            <div>
              <strong>Choose sync depth</strong>
              <p>Aggregate and detailed modes are separate opt-in states.</p>
            </div>
          </div>
          <div>
            <span>3</span>
            <div>
              <strong>Allowlist payload</strong>
              <p>
                {dashboard.privacyAudit.allowedFieldCount} safe fields are
                eligible; content-like fields are rejected.
              </p>
            </div>
          </div>
        </div>

        <button className="panelPrimary" onClick={onClose} type="button">
          Close contract
        </button>
      </div>
    </aside>
  );
}
