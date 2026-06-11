import { cn } from "@/lib/cn";

type Variant = "primary" | "ghost" | "sage";

export function PillButton({
  variant = "primary",
  className,
  children,
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant }) {
  return (
    <button
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-full px-6 min-h-12",
        "text-sm font-medium tracking-wide select-none",
        "transition-all duration-150 active:scale-[0.98] disabled:opacity-40 disabled:pointer-events-none",
        variant === "primary" && "bg-blush text-on-accent active:bg-blush-deep",
        variant === "ghost" &&
          "bg-transparent text-ink border border-ink/15 active:border-ink/30",
        variant === "sage" && "bg-sage text-ink",
        className
      )}
      {...props}
    >
      {children}
    </button>
  );
}
