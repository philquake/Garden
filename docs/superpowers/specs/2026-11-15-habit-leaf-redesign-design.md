# Garden redesign: Habit Leaf-style tracker with stats, forgiveness and one-time unlock

Status: decisions confirmed by the user in a grilling session on 2026-11-15.
Milestones 1-5 are built and merged to `main`, covered by widget and unit
tests; milestone 6 is drafted in `docs/store/listing-draft.md`. Built since:
30 plants with five growth stages each (replacing the four drawn flowers),
demo mode (`--dart-define=DEMO=true`), and a calm colourful theme with
reworked screen layouts.
Not done: the real store purchase (RevenueCat), the analytics backend and crash
reporting, and any run on a real device.

## Goal

Turn Garden from a watercolour meadow with a neglect/decline system into a card-list habit tracker (like Habit Leaf) with Loop-style statistics, streaks with built-in forgiveness, numeric habits, a one-time $9.99 unlock, no accounts, CSV export and a way to carry data to a new phone.

## Decisions

### Screens
- **Home**: a dated "today" card with a progress bar, then a list of habit cards (the meadow is cut). Each card: name, streak or "Habit formed ✓", grace note ("37 days · 1 grace used"), plant, recent days beside the name. Tapping the log button logs +1 (or marks yes/no done); long-press opens an exact-value box; tapping the card opens the detail screen.
- **Detail**: score %, month and year change, total completions, score line over time, history bars (week/month/year toggle), calendar heatmap, best streaks. Charts hand-drawn with CustomPainter, no chart package. Tapping any past day edits it.
- **Settings**: Restore purchase, backup and transfer, CSV export, reminders default, analytics opt-in toggle.
- **Look**: light and dark themes (warm oat background, bordered white cards, deep sage actions), Newsreader headings. Each habit's plant sets its colour, used as a soft wash on its card and detail header and in its charts.
- **Plants**: 30 plants in four groups (Flowering, Leafy, Succulents, Tall), picked from a grouped picker on the habit form. Each has five growth stages as images (`assets/plants/<id>_<stage>.png`, SVG sources in `docs/art/plants/stages`). Motion is described in `2026-11-14-animated-flower-characters-design.md`.

### Habit model
- Types: yes/no, or numeric (unit, daily target, "at least" or "at most").
- A day is qualifying only when the target is met (or forgiven). Partial progress is shown as a lighter shade only.
- Schedules stay: daily, N times a week, one weekday.
- Any past day from creation is editable (no back-fill limit). Streak, score and forgiveness are always recomputed from the completions history, never stored as running counters.
- Day starts at 03:00 (unchanged).

### Forgiveness and growth
- Daily and fixed-weekday habits: 2 free misses per calendar month, applied automatically, shown on the card.
- "N times a week" habits: a week is met when N is done; streak counts met weeks; no allowance.
- Loop-style decaying score on the detail screen.
- Plants never die. No loss, replant, decline steps, fresh start or ignored-reminder suppression.
- "Habit formed ✓" after 66 qualifying days. The plant grows in five stages toward 66 and stays full grown after. Once a habit has 5 completions, its plant leans a little while the recent score is low and stands straight again as it recovers.

### Pricing and paywall
- Free download: 3 habits, overview stats (score ring, month/year change, total), the current month on the calendar, forgiveness included. Locked: score and history charts, best streaks, earlier months, CSV export, backup and restore.
- One-time unlock at $9.99 via RevenueCat: unlimited habits (the cap of 8 is removed), all charts and history, CSV export, backup/transfer file.
- Paywall appears only when adding a 4th habit or tapping a locked chart/export. Never at launch. Restore purchase is always in Settings.
- Price basis: simple one-time habit apps $3.99-$5.99 (Streaks, Habito), lifetime unlocks $30-65 (HabitKit, Habitify), Leaf $9.99 lifetime. Sources disagree; re-check before release.

### Data, export, transfer
- Storage: SQLite (completions table), replacing the SharedPreferences JSON blob. No migration (app unreleased; add a one-time import only if the user has real data on their own phone).
- No accounts.
- CSV export: `completions.csv` (long format: habit, date, completed/value, note) plus `habits.csv` (name, created date, schedule, current streak). Shared via the system share sheet.
- Device change: OS backup enabled (Android Auto Backup, iCloud), plus a manual "Backup & transfer" file (JSON plus checksum) for Android-iPhone moves and as a fallback. Purchase restores through the store, not the file.

### Analytics
- Opt-in, anonymous, off until accepted (first-run ask plus Settings toggle). Random install ID. About ten counted events: first open, habit created, first completion, daily active, paywall viewed, purchase, export used, backup used, day-1/7/30 return. Never habit names or notes. Crash reports behind the same toggle.
- Backend (PostHog is available) to be chosen, confirming hosting and region.
- Store listing wording: "data stays on your device unless you opt in to anonymous usage stats".
- Expect 30-50% opt-in, so counts will be undercounted.

### Platforms
Android and iOS together.

## Build order
1. SQLite completions store, scoring and forgiveness engine, with tests.
2. Card-list home and detail screens with charts.
3. Numeric habits.
4. Free-tier limits and RevenueCat unlock.
5. CSV export, backup file, OS backup config, opt-in analytics.
6. Store assets and listing.

## Known caveats
- OS backup cannot be verified from inside the app (hence the manual file).
- Opt-in analytics undercounts.
- The old meadow, decline and loss code and notification suppression have been removed.

## Not in scope
Cloud sync, accounts, widgets, social features, subscriptions.
