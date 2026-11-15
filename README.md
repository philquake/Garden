# Garden

A habit tracker where every habit grows its own plant. Log a habit and its
plant grows, stage by stage, until the habit is formed. Streaks forgive a
couple of slips a month, and plants never die.

## Features

- A card for each habit on the home screen, with a dated "today" card and
  progress bar, and a strip of recent days beside each habit's name
- Yes/no habits and number habits ("at least 8 glasses", "at most 2 coffees")
- Daily, N-times-a-week or fixed-weekday schedules
- Tap a card's log button to log today; long-press it for an exact value; tap
  the card for the habit's detail screen; edit any past day from the calendar
- Streaks with 2 free misses a month, a Loop-style score, and charts by week,
  month and year (drawn in code, no chart package)
- 30 plants in four groups (Flowering, Leafy, Succulents, Tall), each with five
  growth stages from seed to full grown
- Optional reminders at the time you choose
- Light and dark themes
- CSV export, and a backup file you can restore on a new phone
- No accounts; data stays on the phone. Anonymous usage counts only if you opt in
- Free for 3 habits; a one-time $9.99 unlock for unlimited habits, all charts
  and history, export and backup

## Run, test, build

```
flutter pub get
flutter run
flutter test
flutter build apk --debug
```

Demo mode starts on ten sample habits (in their own database, so real data is
never touched) with the unlock switched on:

```
flutter run --dart-define=DEMO=true
```

iOS builds need a Mac.

## Project layout

- `lib/domain` pure rules (schedules, streaks, forgiveness, score, reminder
  planning, day maths), no Flutter
- `lib/data` SQLite store for habits and completions
- `lib/state` Riverpod providers and the garden controller
- `lib/ui` home, habit detail, habit form, settings, charts, paywall and theme
- `lib/flower` the plant list and the animated plant view
- `lib/notify` reminder scheduling
- `lib/export` CSV export, backup and restore
- `lib/purchases` free-tier limit and the one-time unlock
- `lib/analytics` opt-in anonymous event counts
- `lib/demo` sample habits for demo mode
- `assets/plants` plant images, `<plant>_<stage>.png`, stages 0 to 4; SVG
  sources are in `docs/art/plants/stages`
- `test/` unit and widget tests, one folder per `lib` area

## The rules

| Rule | Value |
| --- | --- |
| Done day | the target is met (yes/no: done; numbers: at least or at most the target) |
| Forgiveness | daily and weekday habits: 2 free misses per calendar month, applied automatically |
| Times a week | a week counts when N days are done; the streak counts weeks; no free misses |
| Habit formed | 66 done or forgiven days |
| Growth | 5 stages towards "habit formed"; stays full grown after |
| Plants | never die; a plant leans a little while its recent score is low (once it has 5 completions) |
| Free habits | 3; unlimited after the unlock |
| Past days | any day since the habit was created can be edited |
| Reminders | 1 per habit at a time you choose (default 9:00), only on scheduled days and not once the target is met; quiet hours 10pm to 8am (moved to 8am); with 3 or more due in a day, the first is sent alone and the rest are grouped into one |
| Day boundary | 3am |
| Week starts | Monday |

## Not done yet

- The real store purchase: Unlock uses a stand-in until RevenueCat and the
  store products are set up
- The analytics backend and crash reporting (events go nowhere for now)
- Checks on real Android and iOS devices: reminders firing and surviving a
  reboot, share sheet, file picker, backup and restore, OS backup, a test
  purchase
- iOS build (phones only: iPad is not a target device)

## More

- Current design: [docs/superpowers/specs/2026-11-15-habit-leaf-redesign-design.md](docs/superpowers/specs/2026-11-15-habit-leaf-redesign-design.md)
- Plant motion: [docs/superpowers/specs/2026-11-14-animated-flower-characters-design.md](docs/superpowers/specs/2026-11-14-animated-flower-characters-design.md)
- Store listing draft: [docs/store/listing-draft.md](docs/store/listing-draft.md)
- Competitor research: [docs/research/2026-11-15-habit-tracker-competitors.md](docs/research/2026-11-15-habit-tracker-competitors.md)
