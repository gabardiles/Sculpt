# Sculpt — V1.1 Plan

Three features, one hard constraint: **zero perceived performance cost**.
Every design below follows the same rule — pay any cost once, at a
boundary moment (cycle start, theme switch), never per-render and never
per-request.

---

## 1. Cycle intake — "Tune this cycle"

**What:** Before a cycle starts, three 1–5 sliders:

| Question | Slider |
|---|---|
| Glutes & lower body | 1–5 (default 5 — glutes program is the default) |
| Strong — lift heavier | 1–5 (default 3) |
| Lean & toned upper body | 1–5 (default 3) |

**Where it appears:**
- **First onboarding** (after name) — same screen, three sliders, calm.
- **Between cycles** — as a third section of the existing CycleReview card
  ("Tune the next cycle"), collapsed behind a small link by default.

**How it adjusts the program (deterministic rules, applied ONCE):**
- All defaults → no change (the audited template is the default).
- `strong ≥ 4` → swap up to 2 pump accessories for strength-tier moves in
  the same pattern/muscle (uses the existing guarded swap machinery).
- `lean upper ≥ 4` → Day 5 trades one glute pump for an upper accessory;
  Day 2 ordering favors presses.
- `glutes ≤ 2` → Day 5 ("Booty Volume") swaps toward a balanced
  full-body pump day.
- Exact swap tables to be written with the fitness-coach agent before
  implementation, so every adjustment stays professionally defensible.

**Performance:** answers stored as one `jsonb` column on `programs`
(`intake`), adjustments executed as a single server action at submit.
After that the program is just rows — zero ongoing cost, no new queries
on any page.

## 2. New-cycle / first-run onboarding

- The **CycleReview card already is the between-cycles moment** — it
  gains the intake link (above) and one line linking "How Sculpt works".
  No new screens, no new queries (review data already loads only when a
  cycle just completed).
- **First onboarding** becomes: name → three sliders → "Start the cycle".
  One screen, one action.
- ✅ Done now: How-it-works + Install demoted to small "LEARN" links on
  the You page (was big cards).

## 3. Sculpt — Spartan (men's edition)

**Principle:** one app, one engine, two skins + two templates. No forks.

**Theme architecture (zero-lag):**
- `profiles.theme: 'sculpt' | 'spartan'` + a mirror cookie
  (`sculpt-theme`) so the server renders the right theme on first paint —
  no flash, no client fetch, no layout shift.
- The (app) layout reads the cookie (already-parsed request data, no
  network) and sets `data-theme="spartan"` on the wrapper.
- `globals.css` swaps tokens under `[data-theme="spartan"]`:
  warm charcoal bg (#16130F), bone text (#EDE6E0), bronze accent
  (#B08D57), deep olive for "done". Glass becomes smoked glass
  (rgba(20,18,15,0.55)). Same component classes — **zero JS, zero extra
  CSS requests, zero runtime cost.** Editorial images get a `spartan` set
  in `editorial.ts`.
- Switch lives in You → Account ("Appearance: Sculpt / Spartan").

**Program:**
- Second global template (`programs.user_id = null`, name `Spartan`) —
  the engine already supports multiple templates and active-program
  switching (`programs.active`).
- Day design, ~10–15 new library exercises (bench, OHP, barbell row,
  weighted pull-up, dips…), rationales, share prompts and quotes are
  being designed by the fitness-coach agent now → `docs/spartan-program.md`.
- Theme switch ≠ program switch: changing appearance never touches
  training data. Picking the Spartan *program* happens at onboarding or
  via a deliberate "change program" flow (new cycle starts, history kept).

**Copy layer:** `programCopy.ts` keys by day name already — Spartan day
names get their own rationale/share-prompt entries. Tone: disciplined,
quiet, no bro-shouting.

## Performance guarantees (applies to all three)

1. No new queries on dashboard/workout hot paths — intake and theme are
   read from data already loaded (program row, cookie).
2. All program mutations happen once, at explicit user action.
3. Theme = CSS variables only. No theme JS, no hydration dependency.
4. Anything heavier (image sets) ships as static assets, cached by CDN.

## Build order

1. Intake sliders + adjustment rules (with coach-designed swap tables)
2. Onboarding restyle (name + sliders) + CycleReview intake link
3. Spartan theme tokens + cookie plumbing + You switch
4. Spartan template SQL (from coach report) + editorial image set
5. QA pass on both themes; performance re-check
