# Sculpt — native iOS

A native **SwiftUI** port of the Sculpt training tracker. Same features, same
data, same Alo-Yoga aesthetic — built directly on the **same Supabase backend**
as the web app (`../`), so web and iOS stay in sync row-for-row.

> **Status:** the app is written and structured to build and run in the iOS
> Simulator the moment you open it on a Mac. It was developed on Linux (where
> SwiftUI/Xcode can't compile), so it has **not been compiled here** — expect to
> resolve the odd Swift-package API nuance on first build (notes below). The pure
> logic (the cycle/schedule/goal engines) is covered by unit tests.

## Stack

- **SwiftUI**, iOS 17+, one shared `Supabase` Swift package (SPM).
- **[XcodeGen](https://github.com/yons/XcodeGen)** — the `.xcodeproj` is generated
  from `project.yml` and git-ignored, so the source tree is the single source of
  truth.
- Backend: the existing Supabase project (Postgres + RLS + Auth + Storage +
  Realtime). No backend rewrite — the Swift client talks to the same tables the
  web app does, and RLS provides the same guarantees.

## First-time setup

```bash
brew install xcodegen          # one-time
cd ios
# 1. Point the app at your Supabase project (same one the web app uses):
#    edit Sculpt/Config.xcconfig and set SUPABASE_HOST + SUPABASE_ANON_KEY
#    (Supabase → Project Settings → API). HOST is the bare host, no https://
#    (xcconfig treats // as a comment — the app prepends https:// at runtime).
xcodegen generate              # writes Sculpt.xcodeproj
open Sculpt.xcodeproj
# 2. In Xcode: pick an iPhone simulator and ⌘R. Sign in with an invited email
#    (the same invite-only OTP flow as the web app).
```

Run the tests with ⌘U (or `xcodebuild test -scheme Sculpt -destination 'platform=iOS Simulator,name=iPhone 15'`).

## Project layout

```
Sculpt/
  Core/
    Supabase/    SupabaseManager, SessionStore (auth state)
    Models/      Codable mirrors of src/lib/types.ts (+ nested read shapes)
    Engine/      Ported pure logic: CycleEngine, ScheduleEngine, GoalProgress,
                 RepTargets, Format, ProgramCopy  ← unit-tested
    Theme/       Design tokens (sculpt + spartan palettes), ThemeManager
    DesignSystem/ GlassCard, PillButton, ProgressRing, MonoText, Sparkline…
    Notifications/ Haptics, LocalNotifications, PushNotifications, AppDelegate
    Health/      HealthKitManager (workouts + body weight)
    LiveActivity/ RestActivityController (starts the Dynamic Island timer)
  Data/          Repository (reads ← data.ts) + Repository+Writes (← actions.ts)
Shared/          Compiled into BOTH app + widget (RestActivityAttributes, SharedStore)
SculptWidgets/   Widget extension — Next-session widget + rest Live Activity
  Features/
    Root/        SculptApp (@main), RootView router, MainTabView
    Auth/        Login (email OTP), Onboarding
    Dashboard/   Today tab — the heart, with the live cycle/week state
    Workout/     The session loop: log sets, rest timer, feel rating, celebrate
    Program/     Program editor — swap/add/remove/custom exercises, switch plan
    Weight/ Photos/ Goals/ Friends/ Report/ You/
SculptTests/     Engine tests (cycle, schedule, goals, formatting)
```

## What maps to what

| Web | iOS |
|-----|-----|
| `src/lib/cycle.ts` | `Core/Engine/CycleEngine.swift` + `RepTargets.swift` |
| `src/lib/schedule.ts` | `Core/Engine/ScheduleEngine.swift` |
| `src/lib/goals.ts` | `Core/Engine/GoalProgress.swift` |
| `src/lib/data.ts` (reads) | `Data/Repository.swift` |
| `src/lib/actions.ts` (writes) | `Data/Repository+Writes.swift` |
| `src/app/globals.css` tokens | `Core/Theme/Theme.swift` |
| `components/ui/*` | `Core/DesignSystem/*` |
| each `(app)/*` page | matching `Features/*` screen |

## AI fitness report

Built. "Analyze my photos" in the Report tab calls the **`fitness-report`**
Edge Function (`../supabase/functions/fitness-report/`), which runs the same
Claude-vision prompt + scoring as `src/lib/physique.ts` on the member's latest
progress photos and stores a `fitness_reports` row. To turn it on:

```bash
supabase functions deploy fitness-report
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

Until deployed, the button surfaces a friendly "not enabled yet" message;
reports generated on the web (shared backend) still render here in full.

## Admin invites

Built. Admins get an "Invite someone" screen in the You tab that calls the
**`invite-user`** Edge Function (`../supabase/functions/invite-user/`) — it
creates the account (no password) and emails a sign-in code, mirroring
`inviteUser` in `src/lib/actions.ts`. Deploy:

```bash
supabase functions deploy invite-user
# optional branded email; without it, Supabase's OTP mailer is used:
supabase secrets set RESEND_API_KEY=re_... RESEND_FROM=sculpt@yourdomain.com
```

Nothing is stubbed — every web feature has a native path.

## Native features

| Feature | State |
|---------|-------|
| **Haptics** (done / PB / cheer) | ✅ live |
| **Local notifications** (rest-timer-done, training reminders) | ✅ live, no account needed |
| **Push for feed** (cheer/comment while app closed) | 🟡 scaffolded — see below |
| **HealthKit sync** (workouts + body weight + **steps read**) | ✅ coded — enable the capability in Xcode |
| **Green Days** (steps + training → green/gold days, streaks, points, friends leaderboard) | ✅ live — Apple Health steps power rest-day greens |
| **Live Activity** (Dynamic Island rest timer) + **home-screen widget** | ✅ coded — `SculptWidgets` extension; add App Group in Xcode |

### Enabling the widget + Live Activity

The widget extension target (`SculptWidgets/`) ships a **Next session** widget
(home + lock screen) and the **rest-timer Live Activity** (Lock Screen +
Dynamic Island). The rest timer starts/ends automatically during a session;
the widget reads a snapshot the app writes to a shared **App Group**.

`xcodegen generate` already creates and embeds the extension. To make the
widget show live data (rather than a placeholder), add the **App Group**
capability — the same group id `group.app.getsculpt.ios` — to *both* the `Sculpt`
and `SculptWidgets` targets in Xcode → Signing & Capabilities. Live Activities
need no extra setup beyond `NSSupportsLiveActivities` (already in Info.plist).
Until the App Group is added, `SharedStore` falls back to local defaults and the
widget shows a tasteful "Open Sculpt" placeholder — nothing breaks.

### Enabling HealthKit

The code is in (`Core/Health/HealthKitManager.swift`); it writes a strength
workout on finish, mirrors body-weight entries, and **reads daily steps** to
power Green Days (see below). It asks permission the first time you finish a
session. Everything is guarded, so the app builds and runs fine without the
capability — Health just stays inert. To turn it on:
in Xcode → target → Signing & Capabilities → **+ Capability → HealthKit** (this
wires `Sculpt/Sculpt.entitlements`, already in the repo). The Info.plist usage
strings are in place. HealthKit is available with a free personal team for
on-device development.

### Enabling push (after you have the Apple Developer account)

The app already registers for APNs and stores its device token; the server piece
is written and waiting:

1. Apply the migration `../supabase/migrations/0014_device_tokens.sql`.
2. Deploy the Edge Function: `supabase functions deploy notify-feed`
   (`../supabase/functions/notify-feed/index.ts`).
3. Set the function secrets from your APNs auth key (.p8):
   `supabase secrets set APNS_KEY_ID=… APNS_TEAM_ID=… APNS_BUNDLE_ID=app.getsculpt.ios APNS_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)" APNS_ENVIRONMENT=sandbox`
4. In the Supabase Dashboard → Database → Webhooks, add INSERT webhooks on
   `feed_cheers` and `feed_comments` pointing at the `notify-feed` function.
5. In Xcode, add the **Push Notifications** capability to the target.

Until then everything stays dormant and harmless — `registerForRemoteNotifications`
simply fails quietly without the entitlement.

## Shipping (when the Developer account is live)

1. Set your team under target → Signing & Capabilities (or `DEVELOPMENT_TEAM` in
   `project.yml`).
2. App icon is in place (`Sculpt/Resources/Assets.xcassets/AppIcon`) — a white
   heart on Sculpt's dusty-pink gradient. Regenerate any time with
   `python3 scripts/generate-appicon.py` (pure stdlib, no deps), or replace the
   1024² PNG with your own.
3. Archive (Product → Archive) → distribute to **TestFlight**, then the App Store.

## Notes / things to verify on first compile

- **supabase-swift API drift.** This was written against supabase-swift v2.
  A couple of call sites (storage `upload`, the `.is("user_id", value: nil)`
  filter, realtime channel subscription in `FriendsViewModel`) may need a small
  signature tweak depending on the exact package version Xcode resolves — they're
  commented where relevant. Pin a version in `project.yml` if you want stability.
- **Fonts.** The web uses Geist; here we default to SF Pro + a monospaced design
  for numerals. Drop `Geist-*.ttf` into `Resources/`, register `UIAppFonts` in
  `Info.plist`, and swap the helpers in `DesignSystem.swift` to match exactly.
- **Editorial photography.** The web pulls external editorial imagery per day;
  the native app uses themed blush/spartan gradients instead (the web hides those
  photos in the Spartan theme anyway).
