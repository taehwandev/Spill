import { formatTokens, type AIToolBreakdownRow } from "../dashboardModel";
import { getTokenMeteringMessages } from "../i18n";

export function AIToolBreakdown({
  rows,
  total
}: {
  rows: AIToolBreakdownRow[];
  total: number;
}) {
  const visibleRows = rows.filter((row) => row.tokens > 0);
  const messages = getTokenMeteringMessages();

  return (
    <section className="panel glassCard taskPanel" aria-labelledby="ai-tool-breakdown-title">
      <div className="sectionHeader">
        <div>
          <h2 id="ai-tool-breakdown-title">{messages.panels.aiToolDistribution}</h2>
          <p>{messages.panels.aiToolDistributionDescription}</p>
        </div>
        <span className="panelMeta">{formatTokens(total)}</span>
      </div>
      <div className="barList">
        {visibleRows.length === 0 ? (
          <div className="emptyState">
            {messages.panels.noAIToolRows}
          </div>
        ) : (
          visibleRows.map((row, index) => (
            <div className="barRow" key={row.id}>
              <div className="barMeta">
                <span>{row.label}</span>
                <strong>{row.percentage}%</strong>
              </div>
              <div
                className="barTrack"
                role="meter"
                aria-label={messages.panels.tokenShare(row.label)}
                aria-valuemin={0}
                aria-valuemax={100}
                aria-valuenow={row.percentage}
              >
                <span
                  className={`barTone${(index % 5) + 1}`}
                  style={{ width: `${row.percentage}%` }}
                />
              </div>
            </div>
          ))
        )}
      </div>
    </section>
  );
}
