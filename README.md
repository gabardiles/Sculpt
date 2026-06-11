# Sculpt

A minimalist training tracker for girls who lift. Alo Yoga aesthetic — calm,
airy, glass cards over soft blush gradients. 3-week progressive cycles
(light → medium → hard), tap-to-complete workouts, weight diary, progress
photos, goals, and a small friends feed for sharing wins.

## Stack

- Next.js 15 (App Router) · React 19 · TypeScript
- Tailwind CSS v4 (design tokens in `src/app/globals.css`)
- Geist Sans + Geist Mono (`geist` package — every number is mono)
- lucide-react icons
- Supabase: Postgres + RLS, magic-link auth (invite-only), Storage
- PWA-ready (manifest + apple-touch-icon), mobile-first at 390px

## Setup

1. **Supabase**: create a project, then in the SQL editor run:
   - `supabase/setup_all.sql` — one idempotent script: schema, RLS, seed
     data, instruction videos. Safe to re-run on any database state.
   - `supabase/storage_policies.sql` — as a **separate** query. If it
     errors with "must be owner of table objects", create the same
     policies via Dashboard → Storage → Policies (expressions are in the
     file).

   The `supabase/migrations/` folder holds the same changes as individual
   migrations for CLI-based workflows (`supabase db push`); the SQL editor
   wraps each script in one transaction, so the storage-policy section can
   roll back an entire migration on hosted projects — hence the split
   files above.
2. **Auth**: login is by emailed 6-digit code (`signInWithOtp` +
   `verifyOtp`, with `shouldCreateUser: false` — invite-only). In Supabase:
   - Authentication → Sign In / Up: disable "Allow new users to sign up".
   - Authentication → Emails → **Magic Link** template: make sure the code
     is in the email body by including `{{ .Token }}`, e.g.
     ```html
     <h2>Your Sculpt code</h2>
     <p>Enter this code in the app:</p>
     <h1>{{ .Token }}</h1>
     ```
   No redirect-URL configuration is needed — the code flow never leaves
   the app.
3. **Env**: copy `.env.example` → `.env.local` and fill in the keys.
4. **Make yourself admin** (enables the `/admin` invite screen):
   ```sql
   update public.profiles set is_admin = true
   where id = (select id from auth.users where email = 'you@example.com');
   ```
5. `npm install && npm run dev`

Visit `/styleguide` to verify the design system without auth.

## How the cycle works

State is **derived from logs, never stored**: the current cycle is the
highest logged `cycle_number` (or the program's manual-reset floor), and the
current week is the first phase (light → medium → hard) with unfinished days.
Completing the hard week rolls into the next cycle automatically. Rep targets
come from the phase (10–12 / 6–8 / 4–6); everything is 3 sets, always.
See `src/lib/cycle.ts`.

## Friends feed — privacy model

Friends are added mutually with a 6-character code (`add_friend` RPC). The
feed shares **wins only**: completed workouts, new PBs, gym photos and short
messages. Body-weight entries and progress photos are never shared — they
have no path into `feed_posts`, and RLS keeps them owner-only.

## Notes / TODO

- `exercises.instruction_url` is seeded as `null`. Fill in curated
  `youtube-nocookie.com/embed/...` URLs per exercise; the player appears in
  the instruction sheet automatically (form cues already show).
- Icons are generated from brand tokens: `node scripts/generate-icons.mjs`.
- Parked for v2: weekly recap share-card, deload whisper, duo mode.
