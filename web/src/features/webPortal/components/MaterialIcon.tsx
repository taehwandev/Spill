const iconGlyphs: Record<string, string> = {
  account_circle: "●",
  analytics: "▥",
  check: "✓",
  check_circle: "✓",
  cloud_done: "☁",
  content_copy: "□",
  dashboard: "▦",
  desktop_windows: "▤",
  devices: "▣",
  download: "↓",
  encrypted: "◆",
  expand_more: "⌄",
  fluid_med: "S",
  grid_view: "▦",
  https: "◆",
  laptop_mac: "▭",
  lock: "◆",
  more_vert: "⋮",
  payments: "$",
  refresh: "↻",
  security: "◆",
  settings: "⚙",
  shield: "◆",
  smartphone: "▯",
  speed: "↗",
  terminal: ">",
  toll: "○",
  tune: "≡",
  verified: "✓",
  verified_user: "✓"
};

export function MaterialIcon({
  className = "",
  name
}: {
  className?: string;
  filled?: boolean;
  name: string;
}) {
  return (
    <span
      aria-hidden="true"
      className={`symbolIcon ${className}`}
      data-icon={name}
    >
      {iconGlyphs[name] ?? "•"}
    </span>
  );
}
