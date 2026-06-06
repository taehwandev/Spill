import { formatTokens, type HotspotRow } from "../dashboardModel";
import { getTokenMeteringMessages } from "../i18n";

export function SourceHotspots({ rows }: { rows: HotspotRow[] }) {
  const messages = getTokenMeteringMessages();
  const visibleRows = rows.filter((row) => row.tokens > 0);

  const unknownSourceTooltip = "This represents tokens where the runtime or adapter only reported the total token count without exposing a detailed source breakdown (system, user, history, etc.).";
  const hotspotsTooltip = "Categorized token consumption breakdown. These sources indicate the context type of input and output tokens.";

  return (
    <section className="panel glassCard hotspotPanel" id="hotspots" aria-labelledby="hotspots-title">
      <div className="sectionHeader">
        <div>
          <h2 id="hotspots-title">
            {messages.panels.sourceHotspots}
            <span className="infoIcon" title={hotspotsTooltip}>ⓘ</span>
          </h2>
          <p>{messages.panels.sourceHotspotsDescription}</p>
        </div>
      </div>
      <div className="tableWrap">
        <table>
          <thead>
            <tr>
              <th scope="col">{messages.panels.source}</th>
              <th scope="col">{messages.panels.tokens}</th>
              <th scope="col">{messages.panels.share}</th>
            </tr>
          </thead>
          <tbody>
            {visibleRows.map((row) => (
              <tr key={row.id}>
                <td>
                  {row.label}
                  {row.id === "unknown" && (
                    <span className="infoIcon" title={unknownSourceTooltip} style={{ marginLeft: "6px" }}>ⓘ</span>
                  )}
                </td>
                <td>{formatTokens(row.tokens)}</td>
                <td>
                  <span className="shareCell">{row.percentage.toFixed(1)}%</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="optimizationTip">
        <strong>{messages.panels.optimizationTip}</strong>
        <p>
          {messages.panels.optimizationTipBody}
        </p>
      </div>
    </section>
  );
}
