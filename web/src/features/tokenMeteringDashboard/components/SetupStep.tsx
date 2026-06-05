export function SetupStep({
  command,
  copied,
  index,
  label,
  multiline = false,
  onCopy
}: {
  command: string;
  copied: boolean;
  index: string;
  label: string;
  multiline?: boolean;
  onCopy: () => void;
}) {
  return (
    <section className="setupStep">
      <div className="stepHeader">
        <span>{index}</span>
        <h3>{label}</h3>
      </div>
      <div className={multiline ? "commandBlock multiline" : "commandBlock"}>
        <code>{command}</code>
        <button type="button" onClick={onCopy}>
          {copied ? "Copied" : "Copy"}
        </button>
      </div>
    </section>
  );
}
