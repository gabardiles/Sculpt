/** Instant skeleton while a page's data loads — calm pulse, no spinner. */
export default function Loading() {
  return (
    <main className="animate-fade-in" aria-busy>
      <div className="h-8 w-48 rounded-full bg-white/60 animate-pulse" />
      <div className="mt-2 h-3 w-32 rounded-full bg-white/50 animate-pulse" />
      <div className="glass mt-6 h-32 animate-pulse" />
      <div className="mt-5 flex gap-2">
        {[...Array(5)].map((_, i) => (
          <div key={i} className="h-12 flex-1 rounded-full bg-white/50 animate-pulse" />
        ))}
      </div>
      <div className="glass mt-6 h-24 animate-pulse" />
      <div className="glass mt-3 h-24 animate-pulse" />
    </main>
  );
}
