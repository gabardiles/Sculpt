import { cn } from "@/lib/cn";

export function Card({
  done = false,
  className,
  children,
  ...props
}: React.HTMLAttributes<HTMLDivElement> & { done?: boolean }) {
  return (
    <div
      className={cn(
        done ? "glass-done" : "glass",
        "transition-colors duration-200",
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
}
