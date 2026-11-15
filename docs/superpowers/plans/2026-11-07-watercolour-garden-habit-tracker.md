# Watercolour Garden Habit Tracker Implementation Plan

> **Superseded** by `docs/superpowers/specs/2026-11-15-habit-leaf-redesign-design.md`.
> The meadow, art pack, habit cap and fresh start planned here are no longer built.
> Kept for history only.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A local-first Flutter phone app where each habit is a flower in a watercolour meadow that grows when watered and can be given a no-penalty fresh start.

**Architecture:** A pure-Dart domain layer (schedule math, growth, actions) with no Flutter imports, tested first. A JSON store persists habits on the device. Riverpod exposes the garden to the UI. The meadow and habit screens draw artwork from a replaceable asset pack, with sway, insects and the watering effect drawn in code on top.

**Tech Stack:** Flutter (stable), Dart, `flutter_riverpod`, `shared_preferences`, `flutter_local_notifications`, `timezone`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-07-watercolour-garden-habit-tracker-design.md`

## Global Constraints

- Phones only, portrait only, iOS and Android. Light theme only; no dark theme.
- Local-first and offline: no accounts, no backend, no sync, no payments, no social features.
- Flutter with Riverpod for state.
- A day ends at 3am local time. The week starts on Monday. Store day indexes (ints), never timestamps.
- Changing the device clock must never cause loss.
- Max 8 habits at once.
- Five growth stages: seed, sprout, bud, young bloom, full bloom. A full bloom takes about four weeks of keeping the schedule, whatever its frequency.
- Flowers never wilt or die.
- Fresh start returns the flower to the growth stage it had reached; history is untouched.
- Extra taps on one day count once. Watering an unscheduled day counts. Back-fill allowed for the last 3 days.
- Notifications: one optional reminder per habit (default 9am), only on scheduled days and not if already watered; max 2 a day, grouped; quiet hours 10pm to 8am; pause a habit's reminders after 3 ignored in a row.
- Tone: warm and proud; never guilt language. No emoji in UI chrome.
- Reduced-motion setting calms sway and insects.
- Flower art is an AI-generated image pack supplied later; the app builds against placeholders and loads any number of frames per flower and per state.

## Review Focus

- Device clock moved backwards or forwards: nothing is lost, and nothing is double-counted (Task 3, Task 4).
- Habit schedule edited mid-week: no phantom missed occurrences (Task 6).
- App not opened for 40+ days: the garden catches up in one pass with history intact, not crashed (Task 4).
- Corrupt or missing saved data: the app starts with an empty garden and keeps the bad data aside (Task 5).
- Zero habits and exactly 8 habits: the empty meadow invites planting; the cap blocks a ninth with a clear message (Task 8, Task 10).

---

## File Structure

```
lib/main.dart                      app entry, ProviderScope, theme
lib/domain/day.dart                day/week index math
lib/domain/schedule.dart           Schedule + occurrence rules
lib/domain/habit.dart              Habit data class + JSON
lib/domain/growth.dart             stage from waterings
lib/domain/actions.dart            water, backfill, freshStart
lib/domain/messages.dart           encouragement pool + selection
lib/data/habit_store.dart          JSON persistence
lib/state/garden_controller.dart   Riverpod controller
lib/art/art_pack.dart              manifest + placeholder pack + loader
lib/ui/theme.dart                  watercolour palette, paper background
lib/ui/meadow_screen.dart          horizontal scrolling meadow
lib/ui/meadow_painter.dart         sway, insects
lib/ui/habit_screen.dart           top flower, bottom details
lib/ui/water_effect.dart           paint-spread watering animation
lib/ui/habit_form.dart             add/edit habit
lib/notify/notifier.dart           scheduling and rules
test/...                           mirrors lib/
```

### Task 1: Scaffold project and constants

**Files:**
- Create: Flutter app at repo root (`flutter create --org com.phillipcole --platforms ios,android .`), `lib/domain/rules.dart`, `test/domain/rules_test.dart`

**Interfaces:**
- Produces: `abstract final class Rules` with `static const int dayStartHour = 3`, `habitCap = 8`, `backfillDays = 3`, `fullBloomWeeks = 4`, `stageCount = 5`.

- [ ] **Step 1: Write the failing test** `rules_test.dart`: asserts each constant equals the Global Constraints value above.
- [ ] **Step 2: Run** `flutter test test/domain/rules_test.dart` — Expected: FAIL (file missing).
- [ ] **Step 3: Scaffold** with `flutter create`, add dependencies to `pubspec.yaml`, set portrait-only in `main.dart` via `SystemChrome.setPreferredOrientations`, and implement `Rules` in `lib/domain/rules.dart`.
- [ ] **Step 4: Run** the test — Expected: PASS.
- [ ] **Step 5: Commit** (`git init` first): `git add -A && git commit -m "chore: scaffold app and rule constants"`.

### Task 2: Day and week math

**Files:**
- Create: `lib/domain/day.dart`; Test: `test/domain/day_test.dart`

**Interfaces:**
- Produces: `int dayIndex(DateTime local)` (days since 1970-01-01 of the calendar date of `local` minus 3 hours); `int weekIndex(int day)` (Monday-start week number); `int weekdayOf(int day)` (1=Mon..7=Sun).

- [ ] **Step 1: Write failing tests:** `dayIndex(DateTime(2026,11,7,2,59)) == dayIndex(DateTime(2026,11,6,12))`; `dayIndex(DateTime(2026,11,7,3,0)) == dayIndex(DateTime(2026,11,7,23))`; 2026-11-09 (a Monday) starts a new `weekIndex` versus 2026-11-08; `weekdayOf` of 2026-11-09 is 1.
- [ ] **Step 2: Run** `flutter test test/domain/day_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** the three functions in `day.dart`. Compute using `DateTime.utc(y, m, d)` after the 3-hour shift, so DST changes cannot shift the day.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `feat: day and week index math`.

### Task 3: Schedule and expected occurrences

**Files:**
- Create: `lib/domain/schedule.dart`; Test: `test/domain/schedule_test.dart`

**Interfaces:**
- Consumes: `weekdayOf`, `weekIndex` (Task 2).
- Produces: `enum ScheduleKind { daily, timesPerWeek, weekday }`; `class Schedule { const Schedule.daily(); const Schedule.timesPerWeek(int n); const Schedule.weekday(int weekday); int get perFourWeeks; Map<String,dynamic> toJson(); factory Schedule.fromJson(Map<String,dynamic> j); }`. `perFourWeeks` is 28 for daily, `4*n` for timesPerWeek, 4 for weekday.

- [ ] **Step 1: Write failing tests:** `perFourWeeks` for the three kinds (28, 12 for `timesPerWeek(3)`, 4); JSON round-trip for each kind; `timesPerWeek(0)` and `timesPerWeek(8)` throw `ArgumentError`; `weekday(8)` throws.
- [ ] **Step 2: Run** the test — Expected: FAIL.
- [ ] **Step 3: Implement** `Schedule` in `schedule.dart` with the validation above.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `feat: schedule model`.

### Task 4: Habit model and growth

**Files:**
- Create: `lib/domain/habit.dart`, `lib/domain/growth.dart`; Test: `test/domain/growth_test.dart`

**Interfaces:**
- Consumes: `Schedule`, `Rules`, day functions.
- Produces:
  - `class Habit` (immutable, `copyWith`, `toJson`/`fromJson`) with fields `String id, name, flowerId; Schedule schedule; Set<int> wateredDays; int plantedDay; int plantingWaterings; int lastWaterDay; int evaluatedDay; int reminderMinutes` (-1 for no reminder); `int ignoredReminders`.
  - `int growthStage(Habit h)` returning 0..4: progress is `plantingWaterings / h.schedule.perFourWeeks`; stage is `floor(progress*4)` capped at 4.

- [ ] **Step 1: Write failing growth tests:** daily habit with 7 waterings is stage 1; with 28 is stage 4; a weekday habit with 4 waterings is stage 4; progress beyond full stays at 4.
- [ ] **Step 2: Run** `flutter test test/domain` — Expected: FAIL.
- [ ] **Step 3: Implement** the model and `growthStage`.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `feat: habit model and growth`.

### Task 5: Persistence

**Files:**
- Create: `lib/data/habit_store.dart`; Test: `test/data/habit_store_test.dart`

**Interfaces:**
- Consumes: `Habit.toJson/fromJson`.
- Produces: `class HabitStore { HabitStore(SharedPreferences prefs); List<Habit> load(); Future<void> save(List<Habit> habits); }`

- [ ] **Step 1: Write failing tests** using `SharedPreferences.setMockInitialValues`: save then load returns equal habits; empty prefs loads `[]`; garbage JSON loads `[]` and the garbage is kept under the key `habits_corrupt` and never overwritten.
- [ ] **Step 2: Run** the test — Expected: FAIL.
- [ ] **Step 3: Implement** `HabitStore` storing one JSON list under key `habits`, with the corrupt-data behaviour above.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `feat: habit persistence`.

### Task 6: Actions (water, back-fill, edit, fresh start)

**Files:**
- Create: `lib/domain/actions.dart`; Test: `test/domain/actions_test.dart`

**Interfaces:**
- Consumes: `Habit`, `Rules`.
- Produces: all pure functions returning a new `Habit`:
  - `Habit water(Habit h, int today, {int? forDay})`: `forDay` defaults to `today`; throws `ArgumentError` if `forDay` is more than `Rules.backfillDays` before `today` or after `today`. Same-day repeats leave the state unchanged. A new day adds to `wateredDays`, adds 1 to `plantingWaterings`, and updates `lastWaterDay` if `forDay` is later.
  - `Habit editSchedule(Habit h, Schedule s, int today)`: replaces the schedule and sets `evaluatedDay = today` so no phantom misses are created for the week in progress.
  - `Habit freshStart(Habit h, int today)`: sets `lastWaterDay = today` and `evaluatedDay = today`; stage and `wateredDays` are unchanged.

- [ ] **Step 1: Write failing tests:** double-tap same day counts once; watering an unscheduled day counts; back-fill 3 days ok, 4 days throws; `freshStart` keeps `growthStage` and `wateredDays`; `editSchedule` mid-week yields no new misses.
- [ ] **Step 2: Run** `flutter test test/domain/actions_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** the three functions per the contracts above.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `feat: garden actions`.

### Task 7: Garden controller and art pack loader

**Files:**
- Create: `lib/state/garden_controller.dart`, `lib/art/art_pack.dart`, placeholder images under `assets/art/placeholder/`; Test: `test/state/garden_controller_test.dart`, `test/art/art_pack_test.dart`

**Interfaces:**
- Consumes: `HabitStore`, actions, `dayIndex`.
- Produces:
  - `class GardenController extends StateNotifier<List<Habit>>` constructed with `(HabitStore store, int Function() todayProvider)`. Methods: `add(Habit h)` (throws `StateError` at 8 habits), `water(String id, {int? forDay})`, `editSchedule`, `freshStart`, `refresh()` (brings all habits to today and saves). `gardenProvider` and `todayProvider` are Riverpod providers; tests override `todayProvider`.
  - `class ArtPack { List<String> framesFor(String flowerId, int stage); }`; `ArtPack.placeholder()` returns generated frames for 4 flower ids; a manifest `assets/art/<pack>/manifest.json` maps `flowerId -> stage -> [frame paths]` and `ArtPack.fromManifest` falls back to the placeholder when a frame is missing.

- [ ] **Step 1: Write failing controller tests:** adding a ninth habit throws; `water` persists through a fresh controller built from the same store; `refresh` after a clock moved backwards changes nothing; `refresh` after 40 days keeps `wateredDays`.
- [ ] **Step 2: Write failing art pack tests:** a missing frame falls back to the placeholder frame; an unknown `flowerId` returns the placeholder frame, never throws; any number of frames per stage loads.
- [ ] **Step 3: Run** both test files — Expected: FAIL.
- [ ] **Step 4: Implement** the controller and art pack. Placeholder frames are simple painted PNGs created once and committed.
- [ ] **Step 5: Run** — Expected: PASS.
- [ ] **Step 6: Commit** `feat: garden controller and art pack`.

### Task 8: Theme and meadow screen

**Files:**
- Create: `lib/ui/theme.dart`, `lib/ui/meadow_screen.dart`, `lib/ui/meadow_painter.dart`; Test: `test/ui/meadow_screen_test.dart`

**Interfaces:**
- Consumes: `gardenProvider`, `ArtPack`, `growthStage`.
- Produces: `MeadowScreen` (home): a horizontally scrolling painted meadow whose width grows with the habit count; flowers are placed in planting order at deterministic positions (same habit, same spot every launch); a sway animation per flower and drifting bees and butterflies; a "plant a seed" button; an empty-state invitation when there are no habits; tapping a flower navigates to `HabitScreen(habitId)`. Sway and insects are disabled when `MediaQuery.disableAnimations` is true.

- [ ] **Step 1: Write failing widget tests:** with zero habits the empty invitation text is shown; with 3 habits there are 3 tappable flowers; with 8 habits the "plant a seed" button shows the cap message instead of opening the form; with `disableAnimations` true no insect widgets are built.
- [ ] **Step 2: Run** `flutter test test/ui/meadow_screen_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** the theme (soft paper background, watercolour palette, light only) and the meadow screen and painter.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Run the app** on a simulator and confirm the meadow scrolls sideways and the flowers sway.
- [ ] **Step 6: Commit** `feat: meadow screen`.

### Task 9: Habit screen and watering effect

**Files:**
- Create: `lib/ui/habit_screen.dart`, `lib/ui/water_effect.dart`; Test: `test/ui/habit_screen_test.dart`

**Interfaces:**
- Consumes: `gardenProvider`, `water`, `freshStart`, `ArtPack`, `messages`.
- Produces: `HabitScreen(String habitId)`. Top half: the flower, large; tapping it calls `water` and plays `WaterEffect` (paint spreads up the flower from the base; a bee or butterfly visits with probability 0.3). Bottom half: name, schedule, "x of n this week", a month calendar marking `wateredDays`, an edit button. The calendar lets the person back-fill within the last 3 days. When the person is struggling (Task 11) a fresh start button appears, reassuring that history stays.

- [ ] **Step 1: Write failing widget tests:** tapping the flower increases the "this week" count; a second tap the same day does not; a struggling garden shows the fresh start button and a healthy one does not; the back-fill list offers exactly the last 3 days.
- [ ] **Step 2: Run** `flutter test test/ui/habit_screen_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** the screen and `WaterEffect` (a `CustomPainter` masking a wet-paint gradient upward over the flower image; respects reduced motion by showing a short fade instead).
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Run the app** and water a flower by hand.
- [ ] **Step 6: Commit** `feat: habit screen and watering effect`.

### Task 10: Add and edit habit form

**Files:**
- Create: `lib/ui/habit_form.dart`; Test: `test/ui/habit_form_test.dart`

**Interfaces:**
- Consumes: `GardenController.add/editSchedule`.
- Produces: `HabitForm({Habit? existing})`: name field, flower picker (from the art pack's flower ids), schedule picker (daily, N times a week, one weekday), optional reminder time (default 9:00). New habits are planted as a seed.

- [ ] **Step 1: Write failing tests:** an empty name cannot be saved; saving a new habit plants it at stage 0; editing the schedule calls `editSchedule` and creates no misses; the flower picker lists every flower in the art pack.
- [ ] **Step 2: Run** the test — Expected: FAIL.
- [ ] **Step 3: Implement** the form.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `feat: add and edit habit`.

### Task 11: Encouragement messages

**Files:**
- Create: `lib/domain/messages.dart`; Test: `test/domain/messages_test.dart`; wire into `meadow_screen.dart`

**Interfaces:**
- Produces: `enum Tone { warm, smallStep, freshStart }`; `String encouragement(Tone t, int seed)` choosing from a pool of at least 10 variants per tone, deterministic for a seed; `bool isStruggling(List<Habit> habits)` true when at least 3 missed occurrences exist across the garden; a message banner on the meadow when `isStruggling`.

- [ ] **Step 1: Write failing tests:** each tone has at least 10 variants; the same seed returns the same message and different seeds cover more than one variant; no message contains the words "fail", "failed", "lazy" or "behind"; `isStruggling` is false at 2 missed and true at 3.
- [ ] **Step 2: Run** the test — Expected: FAIL.
- [ ] **Step 3: Implement** the message pools (using the spec's examples as the first entry of each tone) and show a dismissible banner on the meadow.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `feat: encouragement messages`.

### Task 12: Notifications

**Files:**
- Create: `lib/notify/notifier.dart`; Test: `test/notify/notifier_test.dart`

**Interfaces:**
- Consumes: `Habit`, `Rules`, `flutter_local_notifications`.
- Produces: pure planning function `List<PlannedNotification> planNotifications(List<Habit> habits, int today)` where `PlannedNotification { String habitId; int dayIndex; int minutes; String title; String body; }`, and `Notifier` that schedules the plan with the plugin (and re-plans on app open and after each watering).

Planning rules: reminders only on scheduled days, none for a habit already watered that day; maximum 2 notifications per day (extras grouped into one "a few flowers would love a drink" notification); nothing between 22:00 and 08:00 (moved to 08:00); a habit with `ignoredReminders >= 3` gets none.

- [ ] **Step 1: Write failing tests** for each planning rule above, including a grouped case with 4 habits due the same day, and a reminder at 23:00 moving to 08:00.
- [ ] **Step 2: Run** `flutter test test/notify` — Expected: FAIL.
- [ ] **Step 3: Implement** `planNotifications` and the `Notifier` wrapper; request permission the first time a reminder is set, not at launch.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `feat: notification planning`.

### Task 13: End-to-end pass and art handoff

**Files:**
- Create: `docs/art-pack.md`, `integration_test/garden_flow_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces: `docs/art-pack.md` describing the manifest format and a prompt template for the image model (watercolour style, transparent background, five stages, consistent style across flowers); an integration test.

- [ ] **Step 1: Write the failing integration test:** plant a seed, water it, fast-forward the injected `todayProvider` by 9 days, see the encouragement banner and the fresh start button, take the fresh start, and see the stage and history kept.
- [ ] **Step 2: Run** `flutter test integration_test/garden_flow_test.dart` — Expected: FAIL.
- [ ] **Step 3: Fix** whatever the end-to-end run shows; write `docs/art-pack.md`.
- [ ] **Step 4: Run** the full suite `flutter test` and the integration test — Expected: all PASS.
- [ ] **Step 5: Commit** `feat: end-to-end flow and art pack docs`.

---

## Self-Review Notes

- Spec coverage: meadow (Task 8), habit view (9), adding and choosing flowers and schedules (10), growth (4), fresh start (6, 9), messages (11), reminders (12), art pack (7, 13), cap (7, 8), clock safety (2, 4), corrupt data (5).
- Known gap carried from the spec: the real flower artwork. Tasks build against placeholders; the art arrives via `docs/art-pack.md`.
