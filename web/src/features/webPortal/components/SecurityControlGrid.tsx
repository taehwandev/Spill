import { syncTransportControls } from "../model/syncSecurityPolicy";
import { MaterialIcon } from "./MaterialIcon";

export function SecurityControlGrid() {
  return (
    <div className="securityGrid">
      {syncTransportControls.map((control) => (
        <article className="securityControl" key={control.id}>
          <div>
            <span className="securityIcon">
              <MaterialIcon
                filled
                name={control.id === "e2ee" ? "encrypted" : control.id === "https" ? "https" : "verified_user"}
              />
            </span>
            <strong>{control.label}</strong>
          </div>
          <span className="requiredPill">{control.value}</span>
          <p>{control.detail}</p>
        </article>
      ))}
    </div>
  );
}
