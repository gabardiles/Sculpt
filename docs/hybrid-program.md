# Hybrid Athlete — the coach's 20-week system

Encoded from three coaching documents (start block, weeks 25–39 of the
ongoing program, and the home-substitution + nutrition guide). This doc is
the source of truth for *why* the template looks the way it does.

## The system

**Weekly undulation.** Every week is LIGHT, MEDIUM, or HEAVY (the coach's
words). Light = less volume so you recover and keep developing. Medium =
moderate, still bites late in the week. Heavy = deliberately under-recovered
— "to push you to the next level". Heavy weeks can stack two in a row, and a
light taper always precedes a test week.

**Three session types, ~4–6 sessions/week.**

1. **Strength** — every session opens with the same barbell warmup
   (3 rounds × 8 deadlift / strict press or good mornings / back squat /
   bent-over row), then the big four (back squat, deadlift, bench, strict
   press) as %-of-1RM waves (e.g. *ramp 20–70% 5×3, work 70–80% 5×5*),
   followed by accessories. Core rule, verbatim from the coach: the last 1–3
   reps of every work set must be properly heavy, nothing left in the tank —
   move the weight up or down between sets to keep it that way. LIGHT/MEDIUM
   sets are ramping warmups; HEAVY sets are the work.
2. **CrossFit** — AMRAPs / EMOMs / for-time pieces with a color intensity
   code (yellow = technique, no lactate; orange = 70–80% effort; red =
   all-out), always closing with a 15–20 min grey-zone cooldown.
3. **Conditioning** — heart-rate-zone based. Running preferred, any machine
   as fallback. Zones (running / machines): GREEN 134–154 / 124–144,
   BLUE 154–164 / 144–154, YELLOW 169–179 / 159–169, ORANGE 179–194 /
   169–194.

**Test weeks.** 1RM back squat / deadlift / strict press / bench; max
unbroken strict pull-ups, dips, dead hang; farmers-walk distance; one
conditioning benchmark (40 min blue-zone distance) and one CrossFit
benchmark. Results recalibrate every percentage that follows.

**Block weeks.** Late in the program, whole weeks concentrate one modality
(conditioning or CrossFit). The coach is explicit: the day order matters —
if life intervenes, move the rest days first, swap session order second.

**Substitution is part of the system.** The home-training document is
literally a swap table: replace a gym strength session with the home session
whose movements match closest; replace any CrossFit session with any home
CrossFit session. That maps 1:1 onto Sculpt's existing guardrail — swaps are
only offered for the same `movement_pattern` + `muscle_group`, same
`rep_profile` first.

## The 20-week map

| Week | Intensity | Source | Notes |
|------|-----------|--------|-------|
| 1 | LIGHT | start wk 1 | 3 strength + 1 CrossFit |
| 2 | HEAVY | start wk 2 | squat 80–90% triples appear |
| 3 | MEDIUM | start wk 3 | powerwalk Sunday |
| 4 | LIGHT | start wk 4 | |
| 5 | MEDIUM | wk 29 | sled WOD |
| 6 | HEAVY | wk 30 | clean & jerk ladder |
| 7 | LIGHT | wk 31 | dumbbell EMOM |
| 8 | MEDIUM | wk 32 | triple AMRAP |
| 9 | HEAVY | wk 25 | back-to-back heavy, part 1 |
| 10 | HEAVY | wk 26 | back-to-back heavy, part 2 |
| 11 | LIGHT | wk 27 | taper before the test |
| 12 | **TEST** | wk 28 | full benchmark battery |
| 13 | LIGHT | wk 34 | new percentages start here |
| 14 | HEAVY | wk 35 | |
| 15 | HEAVY | wk 36 | block — conditioning |
| 16 | MEDIUM | wk 37 | block — CrossFit |
| 17 | HEAVY | wk 38 | block — conditioning (squat + push press complex) |
| 18 | LIGHT | wk 39 | block — CrossFit |
| 19 | LIGHT | derived from wk 27 | half-volume taper |
| 20 | **TEST** | wk 28 pattern | same battery — compare with week 12 |

Every source week is used exactly once; weeks 19–20 are derived to close the
arc the way the coach closes his blocks (taper → test).

## How it's encoded

- `programs.schedule_mode = 'fixed'` — 20 distinct weeks instead of the
  repeating 3-week cycle. The cycle engine is untouched for other programs.
- `program_weeks` — one row per week: `intensity`
  (`light|medium|hard|test`, where `hard` renders as HEAVY), optional block
  `label` and coach `note`.
- `program_days` — gains `week_index`, `weekday` (1 = Monday),
  `session_type` (`strength|crossfit|conditioning`) and `content` (the
  written session: warmup, WOD, zones). CrossFit/conditioning days have no
  exercise rows — they're logged as a completed session + feel rating.
- `program_exercises.scheme` — the coach's prescription verbatim
  (e.g. *Ramp 20–70% 5×3, then work 70–80% 5 reps × 5 set*). When present it
  replaces the derived phase rep target in the workout UI. `sets` holds the
  number of work sets for logging.
- State stays derived from logs: a fixed-program day is unique, so *done*
  means a log exists for it. Logs store `week_index` in `cycle_number` and
  the week's intensity in `week_phase` (check constraints now allow
  `'test'`). `deriveScheduleState` in `src/lib/schedule.ts` is the fixed
  twin of `deriveCycleState`.
- New library exercises (tagged for the swap guardrail): Strict Pull-Up,
  Seal Row, Push Press, Barbell Curl, Leg Extension, GHD Sit-Up, Farmers
  Walk. Everything else maps to existing entries (strict press → Overhead
  Press, deadlift → Conventional Deadlift, etc.).

## Running it

1. Run `supabase/setup_all.sql` (idempotent — adds the schema + exercises).
2. Run `supabase/hybrid20.sql` (idempotent — seeds the 20-week template).
3. On the Program page, switch to **Hybrid Athlete**.

Percentages run off an estimated daily max until week 12's test gives real
numbers — exactly how the coach starts new athletes.
