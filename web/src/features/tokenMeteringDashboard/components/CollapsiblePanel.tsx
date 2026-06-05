import type { ReactNode } from "react";
import { getTokenMeteringMessages } from "../i18n";

export function CollapsiblePanel({
  children,
  className = "",
  defaultOpen = false,
  description,
  id,
  title
}: {
  children: ReactNode;
  className?: string;
  defaultOpen?: boolean;
  description: string;
  id: string;
  title: string;
}) {
  const messages = getTokenMeteringMessages();

  return (
    <details
      className={`panel glassCard collapsiblePanel ${className}`}
      id={id}
      open={defaultOpen}
    >
      <summary className="collapsibleSummary">
        <div>
          <h2>{title}</h2>
          <p>{description}</p>
        </div>
        <span className="collapseHint" aria-hidden="true">
          {messages.panels.toggle}
        </span>
      </summary>
      <div className="collapsibleBody">{children}</div>
    </details>
  );
}
