/** Tiny class joiner — avoids pulling in clsx for an app this small. */
export function cn(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}
