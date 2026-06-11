/** Swedish-friendly dates: "3 mars". */
export function formatDay(date: string | Date): string {
  return new Intl.DateTimeFormat("sv-SE", {
    day: "numeric",
    month: "long",
  }).format(typeof date === "string" ? new Date(date) : date);
}

export function formatRange(start: string, end: string): string {
  return `${formatDay(start)} – ${formatDay(end)}`;
}

/** "40" or "12.5" — never trailing zeros. */
export function formatKg(value: number | null | undefined): string {
  if (value == null) return "—";
  return Number(value.toFixed(2)).toString().replace(".", ",");
}

export function greeting(name: string | null): string {
  const h = new Date().getHours();
  const part =
    h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
  return name ? `${part}, ${name}` : part;
}

export function todayISO(): string {
  const d = new Date();
  const off = d.getTimezoneOffset();
  return new Date(d.getTime() - off * 60_000).toISOString().slice(0, 10);
}
