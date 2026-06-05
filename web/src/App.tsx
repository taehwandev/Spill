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
  workflowSetupPrompt,
  type CopiedTarget
} from "./features/tokenMeteringDashboard/setupCopy";
import type { SyncMode } from "./features/tokenMeteringDashboard/syncSafeUsage";

type ViewMode = "intro" | "dashboard";

export function App() {
  const [viewMode, setViewMode] = useState<ViewMode>("intro");
  const [syncMode, setSyncMode] = useState<SyncMode>(DEFAULT_DEMO_SYNC_MODE);
  const [copiedTarget, setCopiedTarget] = useState<CopiedTarget>(null);

  const dashboard = useMemo(() => buildDashboardModel(demoUsageEvents), []);
  const previewDashboard = useMemo(
    () => buildDashboardModel(demoUsageEvents),
    []
  );

  async function copyText(text: string, target: Exclude<CopiedTarget, null>) {
    await navigator.clipboard.writeText(text);
    setCopiedTarget(target);
    window.setTimeout(() => setCopiedTarget(null), 1800);
  }

  return (
    <div className={viewMode === "intro" ? "introShell" : "appShell"}>
      {viewMode === "intro" ? (
        <IntroPage
          copiedTarget={copiedTarget}
          dashboard={previewDashboard}
          onCopyInstall={() => copyText(installCommand, "install")}
          onCopySetup={() => copyText(setupPrompt, "setup")}
          onCopyWorkflow={() => copyText(workflowSetupPrompt, "workflow")}
          onOpenDashboard={() => setViewMode("dashboard")}
        />
      ) : (
        <DashboardPage
          dashboard={dashboard}
          onBack={() => setViewMode("intro")}
          setSyncMode={setSyncMode}
          syncMode={syncMode}
        />
      )}
    </div>
  );
}
