import { formatTokens, type BreakdownRow } from "../dashboardModel";

export function TaskBreakdown({
  rows,
  total
}: {
  rows: BreakdownRow[];
  total: number;
}) {
  const visibleRows = rows.filter((row) => row.tokens > 0);

  return (
    <section className="panel glassCard taskPanel" aria-labelledby="task-breakdown-title">
      <div className="sectionHeader">
        <div>
          <h2 id="task-breakdown-title">Task-Type Breakdown</h2>
          <p>{formatTokens(total)} preview tokens</p>
        </div>
        <a href="#sessions">View details</a>
      </div>
      <div className="barList">
        {visibleRows.length === 0 ? (
          <div className="emptyState">
            Synced token rows will show task attribution here.
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
                aria-label={`${row.label} token share`}
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

      <div className="visualTiles" aria-hidden="true">
        <div className="visualTile chartTile">
          {visibleRows.slice(0, 6).map((row) => (
            <span
              key={row.id}
              style={{ height: `${Math.max(18, row.percentage + 24)}%` }}
            />
          ))}
        </div>
        <div className="visualTile lineTile">
          <span />
        </div>
      </div>
    </section>
  );
}
