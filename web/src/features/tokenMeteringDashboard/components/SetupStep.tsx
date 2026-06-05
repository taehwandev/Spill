import { getTokenMeteringMessages } from "../i18n";

export function SetupStep({
  command,
  copied,
  hideCommand = false,
  index,
  label,
  multiline = false,
  onCopy
}: {
  command: string;
  copied: boolean;
  hideCommand?: boolean;
  index: string;
  label: string;
  multiline?: boolean;
  onCopy: () => void;
}) {
  const messages = getTokenMeteringMessages();

  return (
    <section className="setupStep">
      <div className="stepHeader">
        <span>{index}</span>
        <h3>{label}</h3>
      </div>
      <div className={hideCommand ? "commandBlock copyOnly" : multiline ? "commandBlock multiline" : "commandBlock"}>
        {hideCommand ? <p>{messages.setupStep.hiddenPromptDetail}</p> : <code>{command}</code>}
        <button type="button" onClick={onCopy}>
          {copied ? messages.setupStep.copied : messages.setupStep.copy}
        </button>
      </div>
    </section>
  );
}
