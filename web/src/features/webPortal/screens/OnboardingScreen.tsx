import type { DashboardModel } from "../../tokenMeteringDashboard/dashboardModel";
import {
  OnboardingFeatureGridBlock,
  OnboardingFinalCtaBlock,
  OnboardingFlowPreviewBlock,
  OnboardingHeroBlock
} from "../blocks/OnboardingBlocks";
import { AuthControls } from "../components/AuthControls";
import { MaterialIcon } from "../components/MaterialIcon";
import type { SpillAuthProvider, SpillAuthState } from "../model/spillAuth";
import type { PortalRoute } from "../routes";

export function OnboardingScreen({
  auth,
  copiedInstall,
  dashboard,
  onCopyInstall,
  onNavigate,
  onSignIn,
  onSignOut
}: {
  auth: SpillAuthState;
  copiedInstall: boolean;
  dashboard: DashboardModel;
  onCopyInstall: () => void;
  onNavigate: (route: PortalRoute) => void;
  onSignIn: (provider: SpillAuthProvider) => void;
  onSignOut: () => void;
}) {
  return (
    <div className="landingPage">
      <header className="landingHeader">
        <button className="landingBrand" onClick={() => onNavigate("onboarding")} type="button">
          <span className="appIcon">
            <MaterialIcon filled name="fluid_med" />
          </span>
          <strong>Spill</strong>
        </button>

        <nav className="landingNav" aria-label="Spill landing navigation">
          <a href="#features">Features</a>
          <a href="#security">Security</a>
          <a href="#docs">Docs</a>
        </nav>

        <div className="landingActions">
          <AuthControls state={auth} onSignIn={onSignIn} onSignOut={onSignOut} />
          <button className="ghostAction" type="button">
            Download
          </button>
          <button className="primaryAction small" onClick={() => onNavigate("dashboard")} type="button">
            Go to Dashboard
          </button>
        </div>
      </header>

      <main className="landingMain">
        <OnboardingHeroBlock
          auth={auth}
          copiedInstall={copiedInstall}
          onCopyInstall={onCopyInstall}
          onNavigate={onNavigate}
          onSignIn={onSignIn}
          onSignOut={onSignOut}
        />
        <OnboardingFlowPreviewBlock dashboard={dashboard} />
        <OnboardingFeatureGridBlock />
        <OnboardingFinalCtaBlock onNavigate={onNavigate} />
      </main>

      <footer className="siteFooter">
        <strong>Spill</strong>
        <span>© 2026 Spill. Built for macOS professionals.</span>
        <nav aria-label="Footer links">
          <a href="#docs">GitHub</a>
          <a href="#security">Privacy</a>
          <a href="#docs">Terms</a>
        </nav>
      </footer>
    </div>
  );
}
