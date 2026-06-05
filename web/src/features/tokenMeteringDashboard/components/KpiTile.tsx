import type { Kpi } from "../dashboardModel";

export function KpiTile({ index, kpi }: { index: number; kpi: Kpi }) {
  const progressWidth =
    kpi.label === "Input tokens" ? "71%" : kpi.label === "Output tokens" ? "29%" : null;

  return (
    <article className={`metricTile metricTone${index + 1}`}>
      <p>{kpi.label}</p>
      <strong>{kpi.value}</strong>
      <span>{kpi.detail}</span>
      {progressWidth ? (
        <div className="metricProgress" aria-hidden="true">
          <span style={{ width: progressWidth }} />
        </div>
      ) : null}
    </article>
  );
}
