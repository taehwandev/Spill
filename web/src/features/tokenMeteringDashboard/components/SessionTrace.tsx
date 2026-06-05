import {
  formatLatency,
  formatTokens,
  type SessionTraceRun
} from "../dashboardModel";
import { CollapsiblePanel } from "./CollapsiblePanel";

export function SessionTrace({ runs }: { runs: SessionTraceRun[] }) {
  return (
    <CollapsiblePanel
      className="widePanel"
      description={`${runs.length} preview runs with opaque ids and token totals`}
      id="sessions"
      title="Sessions"
    >
      <div className="traceList">
        {runs.length === 0 ? (
          <div className="emptyState">
            Synced token rows will appear here.
          </div>
        ) : (
          runs.map((run) => (
            <article className="traceRun" key={run.runId}>
              <div className="traceRunHeader">
                <div>
                  <strong>{run.runId}</strong>
                  <span>
                    {formatTokens(run.totalTokens)} tokens / {formatLatency(run.latencyMs)}
                  </span>
                </div>
                <span>{run.steps.length} spans</span>
              </div>
              <ol>
                {run.steps.map((step) => (
                  <li key={step.spanId}>
                    <span className="stepStage">{step.stage}</span>
                    <div>
                      <strong>{step.taskType}</strong>
                      <span>
                        {step.spanId} / {step.model} / {formatTokens(step.totalTokens)} tokens
                      </span>
                    </div>
                    <time dateTime={step.createdAt}>
                      {new Intl.DateTimeFormat("en-US", {
                        hour: "2-digit",
                        minute: "2-digit"
                      }).format(new Date(step.createdAt))}
                    </time>
                  </li>
                ))}
              </ol>
            </article>
          ))
        )}
      </div>
    </CollapsiblePanel>
  );
}
