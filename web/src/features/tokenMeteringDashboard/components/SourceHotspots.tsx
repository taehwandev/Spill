import { formatTokens, type HotspotRow } from "../dashboardModel";

export function SourceHotspots({ rows }: { rows: HotspotRow[] }) {
  return (
    <section className="panel glassCard hotspotPanel" id="hotspots" aria-labelledby="hotspots-title">
      <div className="sectionHeader">
        <div>
          <h2 id="hotspots-title">Token-Source Hotspots</h2>
          <p>Numeric source categories only</p>
        </div>
      </div>
      <div className="tableWrap">
        <table>
          <thead>
            <tr>
              <th scope="col">Source</th>
              <th scope="col">Tokens</th>
              <th scope="col">Share</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.id}>
                <td>{row.label}</td>
                <td>{formatTokens(row.tokens)}</td>
                <td>
                  <span className="shareCell">{row.percentage}%</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="optimizationTip">
        <strong>Optimization Tip</strong>
        <p>
          Source category totals are high. Tune category rules before
          enabling any cloud aggregate view.
        </p>
      </div>
    </section>
  );
}
