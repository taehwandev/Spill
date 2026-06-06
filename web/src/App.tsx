import { useMemo, useState } from "react";
import { DashboardPage } from "./features/tokenMeteringDashboard/components/DashboardPage";
import { IntroPage } from "./features/tokenMeteringDashboard/components/IntroPage";
import { buildDashboardModel } from "./features/tokenMeteringDashboard/dashboardModel";
import {
  DEFAULT_DEMO_SYNC_MODE,
  demoUsageEvents
} from "./features/tokenMeteringDashboard/demoUsage";
import {
  installCommand,
  setupPrompt,
  type CopiedTarget
} from "./features/tokenMeteringDashboard/setupCopy";
import type { SyncMode, UsageEvent } from "./features/tokenMeteringDashboard/syncSafeUsage";

type ViewMode = "intro" | "dashboard";

export function App() {
  const [viewMode, setViewMode] = useState<ViewMode>("intro");
  const [syncMode, setSyncMode] = useState<SyncMode>(DEFAULT_DEMO_SYNC_MODE);
  const [copiedTarget, setCopiedTarget] = useState<CopiedTarget>(null);
  const [events, setEvents] = useState<readonly UsageEvent[]>(demoUsageEvents);

  const previewDashboard = useMemo(
    () => buildDashboardModel(demoUsageEvents),
    []
  );

  async function copyText(text: string, target: Exclude<CopiedTarget, null>) {
    await navigator.clipboard.writeText(text);
    setCopiedTarget(target);
    window.setTimeout(() => setCopiedTarget(null), 1800);
  }

  const triggerSelfTest = () => {
    const newEvent: UsageEvent = {
      schema_version: 1,
      device_id: "device_self_test",
      project_id: "project_global",
      artifact_id: "artifact_global",
      run_id: `run_test_${Date.now()}`,
      span_id: `span_test_${Date.now()}`,
      ai_tool: "antigravity",
      task_type: "testing",
      stage: "verify",
      model: "demo-self-test-reasoning",
      input_tokens: 5000,
      output_tokens: 1500,
      total_tokens: 6500,
      token_breakdown: {
        system: 500,
        user: 1000,
        history: 1500,
        repo_context: 2000,
        tool_output: 1000,
        generated_output: 500,
        unknown: 0
      },
      latency_ms: 1200,
      created_at: new Date().toISOString(), // Today
      sync_mode: "local_only"
    };
    setEvents((prev) => [newEvent, ...prev]);
  };

  return (
    <div className={viewMode === "intro" ? "introShell" : "appShell"}>
      {viewMode === "intro" ? (
        <IntroPage
          copiedTarget={copiedTarget}
          dashboard={previewDashboard}
          onCopyInstall={() => copyText(installCommand, "install")}
          onCopySetup={() => copyText(setupPrompt, "setup")}
          onOpenDashboard={() => setViewMode("dashboard")}
        />
      ) : (
        <DashboardPage
          events={events}
          onBack={() => setViewMode("intro")}
          setSyncMode={setSyncMode}
          syncMode={syncMode}
          onTriggerSelfTest={triggerSelfTest}
        />
      )}
    </div>
  );
}
