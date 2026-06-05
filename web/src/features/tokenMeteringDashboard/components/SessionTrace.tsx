import {
  formatLatency,
  formatTokens,
  type SessionTraceRun
} from "../dashboardModel";
import { getTokenMeteringMessages, tokenMeteringLocaleName } from "../i18n";
import { CollapsiblePanel } from "./CollapsiblePanel";

export function SessionTrace({ runs }: { runs: SessionTraceRun[] }) {
  const messages = getTokenMeteringMessages();

  return (
    <CollapsiblePanel
      className="widePanel"
      description={messages.panels.sessionsDescription(runs.length)}
      id="sessions"
      title={messages.panels.sessions}
    >
      <div className="traceList">
        {runs.length === 0 ? (
          <div className="emptyState">
            {messages.panels.noSessions}
          </div>
        ) : (
          runs.map((run) => (
            <article className="traceRun" key={run.workItemId}>
              <div className="traceRunHeader">
                <div>
                  <strong>{run.title}</strong>
                  <span>
                    {messages.panels.tokenLatency(
                      formatTokens(run.totalTokens),
                      run.latencyMs === null
                        ? messages.kpis.unavailable
                        : formatLatency(run.latencyMs)
                    )}
                  </span>
                </div>
                <span>{messages.panels.spans(run.eventCount)}</span>
              </div>
              <ol>
                {run.steps.map((step, index) => (
                  <li key={`${run.workItemId}-${index}`}>
                    <span className="stepStage">{step.stage}</span>
                    <div>
                      <strong>{step.taskType}</strong>
                      <span>
                        {messages.panels.stepTokenDetail(
                          step.model,
                          formatTokens(step.totalTokens)
                        )}
                      </span>
                    </div>
                    <time dateTime={step.createdAt}>
                      {new Intl.DateTimeFormat(tokenMeteringLocaleName(), {
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
