import {
  connectedDevices,
  syncModeLabel,
  type ConnectedDeviceViewModel
} from "../model/syncSecurityPolicy";
import { MaterialIcon } from "./MaterialIcon";

const deviceIcons: Record<ConnectedDeviceViewModel["deviceType"], string> = {
  desktop: "desktop_windows",
  iphone: "smartphone",
  mac: "laptop_mac"
};

export function ConnectedDeviceList({
  compact = false
}: {
  compact?: boolean;
}) {
  return (
    <div className={compact ? "deviceList compact" : "deviceList"}>
      {connectedDevices.map((device) => (
        <article className={`deviceItem ${device.status}`} key={device.id}>
          <div className="deviceIcon">
            <MaterialIcon name={deviceIcons[device.deviceType]} />
          </div>
          <div className="deviceBody">
            <div className="deviceTitleRow">
              <strong>{device.displayName}</strong>
              <span>{device.status}</span>
            </div>
            <p>
              {device.platform} · Last seen {device.lastSeenLabel}
            </p>
            <small>
              {syncModeLabel(device.syncMode)} · {device.dataScope} · {device.keyStatus}
            </small>
          </div>
          <div className="deviceMetric">
            <strong>{device.totalTokensLabel}</strong>
            <span>tokens</span>
          </div>
        </article>
      ))}
    </div>
  );
}
