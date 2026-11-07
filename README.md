# Garden

A habit tracker that grows and waters a watercolour garden. Every habit is a
flower in a painted meadow: water it when you do the habit, and it grows over
about four weeks. Miss too many days and it droops, but it never judges you,
and you can always start again with your history intact.

## Features

- A meadow of up to 8 habit flowers, each with five growth stages
- Daily, N-times-a-week or fixed-weekday schedules
- Tap the flower to water it; back-fill the last 3 days from the calendar
- Gentle neglect: thirsty, wilting, petal loss, and finally resting
- Fresh start (from petal loss, or 14 days without water) and replant (when lost), history always kept
- Encouragement banner and optional local reminders, with warnings before a
  flower is lost
- Swappable art packs (placeholder art ships today)

## Run, test, build

```
flutter pub get
flutter run
flutter test
flutter build apk --debug
```

iOS builds need a Mac.

## Project layout

- `lib/domain` pure rules (schedules, growth, neglect, day maths), no Flutter
- `lib/state` Riverpod providers and the garden controller
- `lib/data` persistence (SharedPreferences habit store)
- `lib/ui` meadow, habit screen, habit form, painters and effects
- `lib/art` art pack loading and frame lookup
- `lib/notify` reminder scheduling
- `test/` unit, widget and end-to-end flow tests (`test/flows`)

## The rules

| Rule | Value |
| --- | --- |
| Growth | 5 stages over about 4 weeks of full watering |
| Thirsty | 1 missed scheduled day |
| Wilting | 2 misses and 4 days since water |
| Petal loss | 3 misses and 8 days since water |
| Lost | 30 days without watering |
| Fresh start | allowed from petal loss or 14 days without water; keeps stage and history |
| Replant | when lost; new seed, history kept |
| Habit cap | 8 |
| Reminders | 1 per habit at a time you choose (default 9:00); at most 2 notifications a day in total (extras are grouped); quiet hours 10pm to 8am (reminders in that window move to 8am); paused after 3 ignored in a row (and at most 3 are scheduled ahead, so an unopened app goes quiet); a new reminder time starts the count afresh; warnings at days 14, 21 and 27 are exempt from the daily cap |
| Back-fill | up to 3 days |
| Day boundary | 3am |
| Week starts | Monday |

## What still needs a real device

- Notification permission prompt and notifications actually firing
- Reminders surviving a reboot
- iOS build (phones only: iPad is not a target device)
- How the meadow feels at 60fps

## More

- Art handoff: [docs/art-pack.md](docs/art-pack.md)
- Design spec: [docs/superpowers/specs/2026-11-07-watercolour-garden-habit-tracker-design.md](docs/superpowers/specs/2026-11-07-watercolour-garden-habit-tracker-design.md)
