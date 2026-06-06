import { useState, useMemo } from "react";
import {
  formatLocalTimestamp,
  formatLatency,
  formatTokens,
  type SessionTraceRun
} from "../dashboardModel";
import { getTokenMeteringMessages, tokenMeteringLocaleName } from "../i18n";
import { CollapsiblePanel } from "./CollapsiblePanel";
import type { TokenSource } from "../syncSafeUsage";


export function SessionTrace({ runs }: { runs: SessionTraceRun[] }) {
  const messages = getTokenMeteringMessages();
  const [selectedId, setSelectedId] = useState<string | null>(runs[0]?.workItemId || null);
  const [aliases, setAliases] = useState<Record<string, string>>(() => {
    const saved = localStorage.getItem("spill_work_item_aliases");
    return saved ? JSON.parse(saved) : {};
  });
  const [aliasInput, setAliasInput] = useState("");

  // Update input when selected item changes
  const activeRun = useMemo(() => {
    const run = runs.find((r) => r.workItemId === selectedId);
    if (run) {
      setAliasInput(aliases[run.workItemId] || "");
    }
    return run;
  }, [selectedId, runs, aliases]);

  const handleSaveAlias = () => {
    if (!selectedId) return;
    const newAliases = { ...aliases, [selectedId]: aliasInput.trim() };
    if (!aliasInput.trim()) {
      delete newAliases[selectedId];
    }
    setAliases(newAliases);
    localStorage.setItem("spill_work_item_aliases", JSON.stringify(newAliases));
  };

  const handleClearAlias = () => {
    if (!selectedId) return;
    const newAliases = { ...aliases };
    delete newAliases[selectedId];
    setAliases(newAliases);
    setAliasInput("");
    localStorage.setItem("spill_work_item_aliases", JSON.stringify(newAliases));
  };

  // Build model breakdown for the active run
  const activeModelBreakdown = useMemo(() => {
    if (!activeRun) return [];
    const totals: Record<string, number> = {};
    activeRun.steps.forEach((step) => {
      totals[step.model] = (totals[step.model] ?? 0) + step.totalTokens;
    });
    return Object.entries(totals).map(([model, tokens]) => ({
      model,
      tokens,
      percent: activeRun.totalTokens > 0 ? (tokens / activeRun.totalTokens) * 100 : 0
    })).sort((a, b) => b.tokens - a.tokens);
  }, [activeRun]);

  // Build source breakdown for the active run
  const activeSourceBreakdown = useMemo(() => {
    if (!activeRun) return [];
    const breakdown = {
      system: 0,
      user: 0,
      history: 0,
      repo_context: 0,
      tool_output: 0,
      generated_output: 0,
      unknown: 0
    };
    activeRun.steps.forEach((step) => {
      Object.keys(breakdown).forEach((key) => {
        const sourceKey = key as keyof typeof breakdown;
        breakdown[sourceKey] += step.tokenBreakdown[sourceKey] || 0;
      });
    });
    return Object.entries(breakdown)
      .map(([source, tokens]) => ({
        source,
        label: messages.tokenSourceLabels[source as TokenSource] || source,
        tokens,
        percent: activeRun.totalTokens > 0 ? (tokens / activeRun.totalTokens) * 100 : 0
      }))

      .filter((item) => item.tokens > 0)
      .sort((a, b) => b.tokens - a.tokens);
  }, [activeRun, messages]);

  const activeStageBreakdown = useMemo(() => {
    if (!activeRun) return [];
    const totals: Record<string, number> = {};
    activeRun.steps.forEach((step) => {
      totals[step.stage] = (totals[step.stage] ?? 0) + step.totalTokens;
    });
    return Object.entries(totals).map(([stage, tokens]) => ({
      stage,
      tokens,
      percent: activeRun.totalTokens > 0 ? (tokens / activeRun.totalTokens) * 100 : 0
    })).sort((a, b) => b.tokens - a.tokens);
  }, [activeRun]);

  const privacyText = "Privacy boundary: prompt content, file paths, commands, code diffs, logs, and secrets are strictly excluded and never stored.";
  const dedupeTooltip = "Duplicates are checked based on content-free opaque hashes to prevent double counting.";

  return (
    <CollapsiblePanel
      className="widePanel"
      description={messages.panels.sessionsDescription(runs.length)}
      id="sessions"
      title={messages.panels.sessions}
    >
      {runs.length === 0 ? (
        <div className="emptyState">{messages.panels.noSessions}</div>
      ) : (
        <div className="workItemsContainer">
          {/* Sidebar List */}
          <aside className="workItemsSidebar">
            <div className="sidebarTitle">Work Items</div>
            <div className="sidebarList">
              {runs.map((run) => {
                const isSelected = run.workItemId === selectedId;
                const displayName = aliases[run.workItemId] || run.title;
                const toolClass = `toolBadge ${run.aiTool}`;
                return (
                  <button
                    className={`sidebarItem ${isSelected ? "active" : ""}`}
                    key={run.workItemId}
                    onClick={() => setSelectedId(run.workItemId)}
                    type="button"
                  >
                    <div className="sidebarItemHeader">
                      <strong className="sidebarItemTitle">{displayName}</strong>
                      <span className={toolClass}>
                        {messages.aiToolLabels[run.aiTool] || run.aiTool}
                      </span>
                    </div>
                    <div className="sidebarItemMeta">
                      <span>{formatTokens(run.totalTokens)} tokens</span>
                      <span>•</span>
                      <span>{messages.panels.spans(run.eventCount)}</span>
                    </div>
                  </button>
                );
              })}
            </div>
          </aside>

          {/* Detail Panel */}
          <main className="workItemsDetail">
            {activeRun ? (
              <div className="detailContent">
                {/* Header / Alias Editor */}
                <div className="detailHeaderCard glassCard">
                  <div className="detailTitleArea">
                    <span className="eyebrow">Selected Work Item</span>
                    <h2>{aliases[activeRun.workItemId] || activeRun.title}</h2>
                    <span className="technicalLabel">Generated: {activeRun.title}</span>
                  </div>

                  <div className="aliasForm">
                    <label htmlFor="alias-input">Local Alias</label>
                    <div className="aliasInputGroup">
                      <input
                        id="alias-input"
                        onChange={(e) => setAliasInput(e.target.value)}
                        placeholder="Assign a local friendly name..."
                        type="text"
                        value={aliasInput}
                      />
                      <button className="primary" onClick={handleSaveAlias} type="button">
                        Apply
                      </button>
                      {aliases[activeRun.workItemId] && (
                        <button className="secondary" onClick={handleClearAlias} type="button">
                          Clear
                        </button>
                      )}
                    </div>
                    <p className="aliasFormHelp">
                      Local aliases are display metadata stored on this device. They do not alter safe payload logs.
                    </p>
                  </div>
                </div>

                {/* KPI stats */}
                <div className="detailKpiGrid">
                  <div className="detailKpiTile">
                    <span className="tileLabel">Total Tokens</span>
                    <strong>{formatTokens(activeRun.totalTokens)}</strong>
                  </div>
                  <div className="detailKpiTile">
                    <span className="tileLabel">Input Tokens</span>
                    <strong>{formatTokens(activeRun.inputTokens)}</strong>
                  </div>
                  <div className="detailKpiTile">
                    <span className="tileLabel">Output Tokens</span>
                    <strong>{formatTokens(activeRun.outputTokens)}</strong>
                  </div>
                  <div className="detailKpiTile">
                    <span className="tileLabel">Avg Latency</span>
                    <strong>
                      {activeRun.latencyMs === null
                        ? "Unavailable"
                        : formatLatency(activeRun.latencyMs)}
                    </strong>
                  </div>
                </div>

                {/* Properties Table */}
                <div className="detailSection glassCard">
                  <h3>Metadata & Compliance</h3>
                  <div className="metaGrid">
                    <div className="metaItem">
                      <span>AI Tool</span>
                      <strong>{messages.aiToolLabels[activeRun.aiTool] || activeRun.aiTool}</strong>
                    </div>
                    <div className="metaItem">
                      <span>Label Source</span>
                      <strong>Safe Short-lived Context</strong>
                    </div>
                    <div className="metaItem">
                      <span>Total Events</span>
                      <strong>{activeRun.eventCount} Spans</strong>
                    </div>
                    <div className="metaItem">
                      <span>Deduplication</span>
                      <strong>
                        Content-Free Checked
                        <span className="infoIcon" title={dedupeTooltip} style={{ marginLeft: "5px" }}>ⓘ</span>
                      </strong>
                    </div>
                  </div>
                </div>

                {/* Breakdown grids */}
                <div className="detailBreakdowns">
                  {/* Model & Stage */}
                  <div className="detailSection glassCard">
                    <h3>Model Breakdown</h3>
                    <div className="breakdownList">
                      {activeModelBreakdown.map((row) => (
                        <div className="breakdownRow" key={row.model}>
                          <span className="breakdownLabel">{row.model}</span>
                          <span className="breakdownValue">
                            {formatTokens(row.tokens)} ({row.percent.toFixed(1)}%)
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>

                  <div className="detailSection glassCard">
                    <h3>Stage Breakdown</h3>
                    <div className="breakdownList">
                      {activeStageBreakdown.map((row) => (
                        <div className="breakdownRow" key={row.stage}>
                          <span className="breakdownLabel">{row.stage}</span>
                          <span className="breakdownValue">
                            {formatTokens(row.tokens)} ({row.percent.toFixed(1)}%)
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                {/* Source Breakdown (Critical requirement) */}
                <div className="detailSection glassCard">
                  <h3>Source Breakdown</h3>
                  <div className="breakdownList">
                    {activeSourceBreakdown.map((row) => {
                      const isUnknown = row.source === "unknown";
                      const tooltip = isUnknown
                        ? "Runtime did not expose detailed system/user/history context. Only total tokens are exact."
                        : undefined;
                      return (
                        <div className="breakdownRow" key={row.source}>
                          <span className="breakdownLabel">
                            {row.label}
                            {isUnknown && (
                              <span className="infoIcon" title={tooltip} style={{ marginLeft: "6px" }}>ⓘ</span>
                            )}
                          </span>
                          <span className="breakdownValue">
                            {formatTokens(row.tokens)} ({row.percent.toFixed(1)}%)
                          </span>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* Diagnostic Details - Collapsible */}
                <details className="detailSection glassCard diagnosticDetails">
                  <summary>Technical Details & Event Spans</summary>
                  <div className="diagnosticContent">
                    <p className="helpText">
                      These are raw diagnostic identifier scopes. Under compliance guidelines, no content fields are processed.
                    </p>
                    <ol className="diagnosticSteps">
                      {activeRun.steps.map((step, idx) => (
                        <li key={idx} className="diagnosticStepItem">
                          <div className="stepTop">
                            <strong>{step.taskType} ({step.stage})</strong>
                            <time>{formatLocalTimestamp(step.createdAt, tokenMeteringLocaleName())}</time>
                          </div>
                          <div className="stepSub">
                            <span>Model: {step.model}</span>
                            <span>Tokens: {formatTokens(step.totalTokens)} (In: {formatTokens(step.inputTokens)} / Out: {formatTokens(step.outputTokens)})</span>
                          </div>
                          <div className="stepIds">
                            <span>run_id: <code>{step.runId}</code></span>
                            <span>span_id: <code>{step.spanId}</code></span>
                          </div>
                        </li>
                      ))}
                    </ol>
                  </div>
                </details>

                {/* Privacy boundary footer */}
                <div className="detailPrivacyDisclaimer">
                  <span className="statusDot green" />
                  <p>{privacyText}</p>
                </div>
              </div>
            ) : (
              <div className="detailPlaceholder">
                <p>Select a work item from the sidebar to inspect its usage breakdown.</p>
              </div>
            )}
          </main>
        </div>
      )}
    </CollapsiblePanel>
  );
}
