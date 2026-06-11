/** Tiny blush trend line — no axes, no clutter. */
export function Sparkline({
  values,
  width = 220,
  height = 48,
}: {
  values: number[];
  width?: number;
  height?: number;
}) {
  if (values.length < 2) return null;
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const pad = 6;
  const points = values.map((v, i) => {
    const x = pad + (i / (values.length - 1)) * (width - pad * 2);
    const y = pad + (1 - (v - min) / span) * (height - pad * 2);
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  });
  const last = points[points.length - 1].split(",");

  return (
    <svg width={width} height={height} aria-hidden>
      <polyline
        points={points.join(" ")}
        fill="none"
        stroke="var(--color-blush-deep)"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx={last[0]} cy={last[1]} r="3" fill="var(--color-blush-deep)" />
    </svg>
  );
}
