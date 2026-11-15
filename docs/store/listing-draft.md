# Store listing and privacy wording (draft)

Drafts only. Nothing here has been submitted. Every claim below matches what the
app does on this branch; the items under "Open before submitting" do not yet.

## Name and subtitle

- Name: **Garden: Habit Tracker**
- Subtitle (30 characters): **Grow a flower with each habit**
- Category: Health & Fitness (or Productivity)

## Short description (Google Play, 80 characters)

Track habits, keep streaks that forgive a slip, and watch your flowers grow.

## Full description

Garden is a habit tracker where every habit grows its own flower.

Tick off a habit each day (or log a number, like glasses of water) and your
flower grows with you. Miss a day and it simply waits: Garden forgives up to two
missed days a month without breaking your streak, so one bad day never undoes a
good month.

**What you get**
- A card for each habit with a heatmap of recent days
- Streaks with built-in forgiveness
- A score that rises with steady effort, plus charts by week, month and year
- A calendar where you can fix or fill in any past day
- Yes/no habits and number habits ("at least 8 glasses", "at most 2 coffees")
- Reminders at the time you choose
- Light and dark themes
- 30 plants to choose from (flowering, leafy, succulents and tall), each
  growing through five stages

**Yours, not ours**
- No account and no sign-up
- Your habits stay on your phone
- Export every day of every habit as CSV for a spreadsheet
- Back up to a file and restore it on a new phone (including Android to iPhone)

**Free to start, pay once**
Garden is free for up to three habits. A single one-time purchase unlocks
unlimited habits, every chart and your full history, CSV export and backup. No
subscription, ever.

## Keywords (Apple, 100 characters)

habit tracker,streak,routine,daily habits,goal tracker,habit streaks,flower,habit chart,CSV,offline

## What's new (first release)

First release.

## In-app purchase

- Type: non-consumable ("Garden Unlock")
- Price: $9.99 (USD tier; other countries from the store's price tiers)
- Product ID: not created yet (see "Open before submitting")

## Screenshots to capture (6, same on both stores)

1. Home: three or four cards with heatmaps, one "Habit formed", one with
   "37 days · 1 grace used".
2. A habit's detail: ring score, score line, history bars.
3. The calendar with a mix of done, partly done and forgiven days.
4. A number habit being logged (the exact-value box).
5. The unlock sheet (shows one payment, no subscription).
6. Settings: export, backup, restore.

Capture in both themes; use sample habits only, never real personal data.

## Privacy: what the app does

- No accounts, no sign-in, no ads, no third-party trackers.
- Habits, history and settings are stored only on the device (SQLite and local
  preferences). They are set up to be included in the phone's own backup (Google or iCloud);
  this still needs checking on real devices.
- Optional, off by default: anonymous usage counts. If the person agrees, the app
  sends event counts (for example "habit created", "paywall viewed") with a
  random install ID. It never sends habit names, notes or values.
- Payments are handled by the App Store / Google Play through RevenueCat. Garden
  itself never sees payment details.
- Exports and backups are files the person chooses to share; Garden sends them
  nowhere itself.

### Apple App Privacy answers (once the analytics backend is chosen)

- Data linked to the user: none.
- Data not linked to the user: Usage Data > Product Interaction (analytics, only
  if opted in); Purchases (handled by the store).
- Used for tracking: no.
- If analytics is never turned on in the shipped build: "Data Not Collected".

### Google Play Data safety (same condition)

- Data collected: App activity > App interactions (optional, analytics).
- Data shared with third parties: none beyond the analytics service provider.
- Encryption in transit: yes, once the backend uses HTTPS.
- Users can request deletion: opting out deletes the install ID on the device;
  server-side deletion depends on the chosen backend.

## Open before submitting

- Create the purchase product and the entitlement in the stores and RevenueCat,
  then connect the SDK (the app currently has a "no store" stand-in, so Unlock
  does nothing yet).
- Choose the analytics backend and region, and a crash-reporting tool (none is
  installed); update the privacy answers above to match.
- Write a privacy policy and support page (both stores require URLs).
- Real app icon and splash for the redesigned look; screenshots above.
- Test on real Android and iOS devices: reminders, share sheet, file picker,
  backup and restore, OS backup and a purchase with a store test account.
