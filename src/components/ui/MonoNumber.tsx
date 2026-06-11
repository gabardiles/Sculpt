import { cn } from "@/lib/cn";

/** Every number in the app renders in Geist Mono — quiet precision. */
export function MonoNumber({
  className,
  children,
  ...props
}: React.HTMLAttributes<HTMLSpanElement>) {
  return (
    <span className={cn("font-mono tabular-nums", className)} {...props}>
      {children}
    </span>
  );
}

export function Eyebrow({
  className,
  children,
  ...props
}: React.HTMLAttributes<HTMLSpanElement>) {
  return (
    <span className={cn("eyebrow", className)} {...props}>
      {children}
    </span>
  );
}
