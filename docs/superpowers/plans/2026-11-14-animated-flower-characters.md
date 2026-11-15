# Animated Flower Characters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the PNG flowers with one cartoon flower character, drawn and animated in code, whose face and pose show each habit's state.

**Architecture:** A pure function turns a `Habit` and today's day index into a `FlowerLook` (kind, stage, face, pose, bubble, faded). A `CustomPainter` draws a look; a `FlowerView` widget owns the clock and plays idle motion, the delighted reaction and stage growth. The three screens swap their `Image.asset` for `FlowerView`, and the art pack is deleted.

**Tech Stack:** Flutter 3.47, Dart, flutter_riverpod 3.x, `CustomPainter`, `flutter_test`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-14-animated-flower-characters-design.md` (read it first; the faces table and the "Left to the builder" list are binding).

## Global Constraints

- No new packages in `pubspec.yaml`.
- Colours come from `lib/ui/theme.dart`; outlines are `inkBrown`. One new constant is allowed: `lavender` (a muted purple).
- Flower kind ids and order stay `tulip`, `sunflower`, `lavender`, `daisy`.
- The saddest look is one tear and a slump. No crying, dead or angry faces. A lost flower is asleep.
- With reduce motion on (`reduceMotion(context)` in `lib/ui/motion.dart`): no sway, blink, bounce, lift or growth tween; looks change instantly.
- No golden (screenshot) tests.
- Growth, neglect, fresh-start and replant rules do not change, apart from the new `freshStartDay` field.
- Existing widget keys (`flower-<id>`, `habit-flower`, `flower-choice-<id>`) and screen-reader wording stay.
- Run `flutter analyze` and `flutter test` before every commit; both must be clean.
- Commits are local only. Do not push.

## Review Focus

1. **Flower drawn very small (56 px meadow seed, 64 px picker):** painting must not throw or produce NaN; the face stays readable. Test in Task 3.
2. **Reduce motion switched on while an animation is running:** the flower settles to its still look at once, no stuck half-pose. Test in Task 3.
3. **A flower becomes lost or changes stage while on screen:** the view moves to the new look without error (stage 4 to faded seed included). Test in Task 3.
4. **Saved habit with an unknown `flowerId`, or `freshStartDay` in the future (clock moved back):** drawn as a daisy; hopeful rule still works, nothing throws. Tests in Task 2.
5. **Times-a-week habit that has met this week's target, and a weekday habit on another day:** no bubble, no "needs water today" label. Tests in Task 2.

---

### Task 1: `freshStartDay` on the habit

**Files:**
- Modify: `lib/domain/habit.dart`, `lib/domain/actions.dart`
- Test: `test/domain/habit_test.dart`, `test/domain/actions_test.dart`

**Interfaces:**
- Produces: `Habit.freshStartDay` (`int`, constructor default `-1`, in `copyWith`, `toJson` key `'freshStartDay'`, `fromJson` reads `j['freshStartDay'] as int? ?? -1`).

- [ ] **Step 1: Write the failing tests**

In `habit_test.dart`: JSON without `freshStartDay` loads as `-1`; a habit with `freshStartDay: 20764` round-trips through `toJson`/`fromJson`.

In `actions_test.dart` (build habits the way the file already does):

```dart
test('freshStart records the day', () {
  expect(freshStart(petalLossHabit, today).freshStartDay, today);
});
test('a new watering clears freshStartDay, back-fill included', () {
  final f = freshStart(petalLossHabit, today);
  expect(water(f, today).freshStartDay, -1);
  expect(water(f, today, forDay: today - 1).freshStartDay, -1);
});
test('watering an already-watered day leaves freshStartDay alone', () {
  final f = freshStart(petalLossHabit, today).copyWith(wateredDays: {today});
  expect(water(f, today).freshStartDay, today);
});
test('replant clears freshStartDay', () {
  expect(replant(lostHabit.copyWith(freshStartDay: 5), today).freshStartDay, -1);
});
```

- [ ] **Step 2: Run** `flutter test test/domain/habit_test.dart test/domain/actions_test.dart` — expect compile failure (`freshStartDay` undefined).
- [ ] **Step 3: Add the field** to `Habit` as listed under Interfaces. In `actions.dart`: `freshStart` sets `freshStartDay: today`; `water`'s final `copyWith` (the new-watering path only) and `replant` set `freshStartDay: -1`.
- [ ] **Step 4: Run** `flutter test` — all pass.
- [ ] **Step 5: Commit** `feat: record the fresh-start day on a habit`

---

### Task 2: Flower look (pure)

**Files:**
- Create: `lib/domain/due.dart`, `lib/flower/look.dart`
- Test: `test/domain/due_test.dart`, `test/flower/look_test.dart`

**Interfaces:**
- Consumes: `Habit.freshStartDay` (Task 1), `displayStage` (`lib/domain/growth.dart`), `weekIndex`, `weekdayOf` (`lib/domain/day.dart`).
- Produces:

```dart
// lib/domain/due.dart
bool needsWaterToday(Habit h, int today);

// lib/flower/look.dart
const flowerKinds = ['tulip', 'sunflower', 'lavender', 'daisy'];
enum Face { asleep, sad, worried, hopeful, expectant, sleepy, curious, content, grin }
enum Pose { upright, droop, slump }

class FlowerLook {           // const, with == and hashCode
  final String kind;         // always one of flowerKinds
  final int stage;           // 0..4
  final Face face;
  final Pose pose;
  final bool bubble;         // water-drop thought bubble
  final bool faded;          // lost
}
FlowerLook lookOf(Habit h, int today);
FlowerLook pickerLook(String kind); // stage 4, grin, upright, no bubble
```

- [ ] **Step 1: Write the failing tests**

`due_test.dart` — `needsWaterToday`:
- lost habit: false. Today already in `wateredDays`: false (each schedule kind).
- daily, not watered today: true.
- weekday(1): true on a Monday, false on a Tuesday.
- timesPerWeek(3): true with 2 waterings this week; false with 3.

`look_test.dart` — `lookOf`, one test per row of the spec's faces table, in priority order:

| Habit | Expect |
|---|---|
| lost (was stage 4) | stage 0, `asleep`, `upright`, faded, no bubble |
| `declineStep: 3` | `sad`, `slump`, bubble |
| `declineStep: 2` | `worried`, `droop`, bubble |
| `freshStartDay: today`, `declineStep: 0`, daily, not watered | `hopeful`, `upright`, bubble |
| `freshStartDay: today`, `declineStep: 1` | `expectant` (hopeful ended) |
| `freshStartDay: today + 5` (clock moved back), `declineStep: 0` | `hopeful`, no throw |
| `declineStep: 1`, watered today | `expectant`, bubble |
| healthy daily, not watered today, stage 4 | `expectant`, bubble |
| healthy, watered today, stages 0 / 1 / 2 / 3 / 4 | `sleepy` / `curious` / `curious` / `content` / `grin`, no bubble |
| weekday habit on another day, stage 4 | `grin`, no bubble |
| `flowerId: 'orchid'` | `kind == 'daisy'` |

Plus: `pickerLook('tulip')` is stage 4, `grin`, `upright`, no bubble, not faded.

- [ ] **Step 2: Run** `flutter test test/domain/due_test.dart test/flower/look_test.dart` — expect compile failure.
- [ ] **Step 3: Implement** `needsWaterToday` and `lookOf` per the spec ("Needs water today", "Water-drop thought bubble", faces table). Bubble rule: `!h.lost && (needsWaterToday(h, today) || h.declineStep >= 1)`. Pose: `slump` for step 3, `droop` for step 2, else `upright`.
- [ ] **Step 4: Run** `flutter test` — all pass.
- [ ] **Step 5: Commit** `feat: map habit state to a flower look`

---

### Task 3: Draw and animate the character

**Files:**
- Create: `lib/flower/flower_painter.dart`, `lib/flower/flower_view.dart`
- Modify: `lib/ui/theme.dart` (add `const lavender`)
- Test: `test/flower/flower_view_test.dart`

**Interfaces:**
- Consumes: `FlowerLook`, `Face`, `Pose`, `flowerKinds` (Task 2); `reduceMotion` (`lib/ui/motion.dart`).
- Produces:

```dart
// lib/flower/flower_view.dart
class FlowerView extends StatefulWidget {
  const FlowerView({
    super.key,
    required this.look,
    required this.size,        // square, logical px
    this.seed = 0,             // offsets sway and blink per flower
    this.delightTrigger = 0,   // each change plays the delighted reaction
  });
}
```

`FlowerView` owns its own ticker, sits in a `RepaintBoundary`, and paints with `FlowerPainter` (a `CustomPainter`; its constructor is the implementer's choice). It is `size` x `size`; the flower stands on the bottom centre.

- [ ] **Step 1: Write the failing widget tests** (`flower_view_test.dart`)

```dart
// Every combination paints without error, at the three real sizes.
for (final size in [56.0, 64.0, 240.0])
  for (final kind in flowerKinds)
    for (var stage = 0; stage < 5; stage++)
      for (final face in Face.values)
        for (final pose in Pose.values)
          for (final bubble in [false, true])
            // pump FlowerView(look: ..., size: size), pump(1s), expect(tester.takeException(), isNull)
```

Group these so the file has one test per size, not thousands. Also:

- `faded: true` paints without error.
- Reduce motion (`MediaQuery(data: MediaQueryData(disableAnimations: true))`): after `pump()`, `tester.hasRunningAnimations` is false; changing `delightTrigger` or `look.stage` still leaves no running animation after one `pump()`.
- Motion on: `tester.hasRunningAnimations` is true for a `grin` look.
- Changing `look` from stage 4 `grin` to stage 0 `asleep` faded, mid-flight (`pump(300ms)` after a stage change), throws nothing.
- Switching the `MediaQuery` to `disableAnimations: true` during a delight (`pump(100ms)` after a trigger change) leaves no running animation after the next `pump()`.
- Changing `delightTrigger` then `pumpAndSettle` is not used (idle loop never settles); use `pump(2s)` and expect no exception.

- [ ] **Step 2: Run** `flutter test test/flower/flower_view_test.dart` — expect compile failure.
- [ ] **Step 3: Implement the painter.** Draw, per the spec's "The character" section: stem, two leaf hands, the stage shape (table of five stages), the kind's petals (table of four kinds), the round face, then the face features for each `Face`. `droop` bends stem and head; `slump` bends further, removes some petals and lays two on the ground (stages with petals only). `bubble` draws a small thought bubble with a water drop beside the head. `faded` draws at 0.45 opacity. Outline width scales with size; below about 80 px, skip the tear and cheeks. All geometry derives from `size`; no division that can hit zero.
- [ ] **Step 4: Implement the view.**
  - Idle: sway (amplitude by face: none for `asleep`, tiny for `sad`, slow for `worried`, breathing scale for `sleepy`), blink every few seconds for faces with open eyes, both phase-shifted by `seed`.
  - Delight: on `delightTrigger` change, about 0.9 s of eyes squeezed shut, leaves clapping, one bounce. Skipped when `look.faded`.
  - Growth: on `look.stage` change, tween from old to new shape over 0.6 s (a cross-fade with scale is acceptable).
  - Hopeful: when the face first becomes `hopeful`, lift from `droop` to upright once.
  - Reduce motion: check in `didChangeDependencies` and on `didChangeAccessibilityFeatures` (as `meadow_screen.dart` does); when on, stop the ticker and paint the still look.
- [ ] **Step 5: Run** `flutter test` and `flutter analyze` — clean.
- [ ] **Step 6: Commit** `feat: cartoon flower painter and animated view`

---

### Task 4: Use the character on all three screens; retire the art pack

**Files:**
- Modify: `lib/ui/meadow_screen.dart`, `lib/ui/habit_screen.dart`, `lib/ui/habit_form.dart`, `lib/main.dart`, `pubspec.yaml`
- Delete: `lib/art/art_pack.dart`, `lib/state/art_provider.dart`, `assets/art/placeholder/` (whole folder), `docs/art-pack.md`, `test/art/art_pack_test.dart`
- Test: `test/ui/meadow_screen_test.dart`, `test/ui/habit_screen_test.dart`, `test/ui/habit_form_test.dart`

**Interfaces:**
- Consumes: `FlowerView`, `lookOf`, `pickerLook`, `flowerKinds`, `needsWaterToday`.

- [ ] **Step 1: Write the failing tests**
  - Meadow: each habit's `flower-<id>` contains a `FlowerView`; no `Image` widget in the tree. A daily habit not watered today has a semantics label ending `, needs water today`; one watered today does not.
  - Habit screen: `habit-flower` contains a `FlowerView` of size 240. Tapping it increases that view's `delightTrigger` and calls `HapticFeedback.lightImpact` once (capture with `tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, ...)`, looking for `HapticFeedback.vibrate` with `HapticFeedbackType.lightImpact`). Tapping a lost habit's flower does neither. Tapping a back-fill cell does neither.
  - Form: there are four `flower-choice-<kind>` entries in `flowerKinds` order, each holding a `FlowerView` whose look equals `pickerLook(kind)`; a new habit defaults to `tulip`.
  - Remove the `ArtPack`/`artPackProvider` setup from `habit_form_test.dart`.
- [ ] **Step 2: Run** `flutter test test/ui` — new tests fail.
- [ ] **Step 3: Meadow.** In `_flower`, replace the image and the `Transform.rotate` sway with `FlowerView(look: lookOf(h, today), size: size, seed: stableHash(h.id))`. Remove the outer `Opacity` for lost (the look carries `faded`). Pass `today` into `_flower`. Replace `_healthWords`' use of `FlowerHealth` with a switch on `h.declineStep` (same four words). Append `, needs water today` to the label when `needsWaterToday(h, today)`. The 24 s controller stays for the insects.
- [ ] **Step 4: Habit screen.** `_flower` returns `FlowerView(look: lookOf(h, today), size: 240, seed: stableHash(h.id), delightTrigger: _waterTaps)`. In `_water`, after a successful call, also `HapticFeedback.lightImpact()`. `WaterEffect` stays wrapped around it.
- [ ] **Step 5: Form.** `_flowerChoice` shows `FlowerView(look: pickerLook(id), size: 64)`; the list and the default come from `flowerKinds`.
- [ ] **Step 6: Delete the art pack** files listed above; remove the pack loading and `artPackProvider` override from `main.dart`; remove the `assets:` block (`assets/art/placeholder/`) from `pubspec.yaml`. Grep `lib/` and `test/` for `ArtPack`, `artPackProvider`, `FlowerHealth`, `healthOf`, `art-pack` and `assets/art`; none may remain. In `README.md`, replace the art-pack text with one line saying the flowers are drawn in code (`lib/flower/`). The dated documents under `docs/superpowers/` are history; leave them.
- [ ] **Step 7: Run** `flutter analyze` and `flutter test` — clean. Fix any existing tests that looked for `Image` or the rotation.
- [ ] **Step 8: Commit** `feat: animated flower characters on meadow, habit screen and picker`

---

### Task 5: Launcher icon and splash

**Files:**
- Modify: `android/app/src/main/res/drawable/ic_launcher_foreground.xml`, and the splash flower in `drawable/launch_background.xml` and `drawable-v21/launch_background.xml` (and whatever drawable `values-v31/styles.xml` names as `windowSplashScreenAnimatedIcon`).

- [ ] **Step 1:** Redraw the vector flower as the happy full-bloom daisy: white rounded petals, honey face, two eyes with highlights, a grin, rosy cheeks, ink-brown (`#4E4036`) outlines, sage stem and two leaves. Keep the 108 dp viewport and keep the artwork inside the centre 66 dp safe zone. Paper background (`@color/paper`) unchanged.
- [ ] **Step 2: Run** `flutter build apk --debug` — builds without resource errors.
- [ ] **Step 3: Commit** `feat: flower character on the launcher icon and splash`

---

### Task 6: Check it by eye on the emulator

- [ ] **Step 1:** `flutter run` on the running emulator (adb is at `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`). The emulator holds a demo garden of 8 habits covering every stage and kind plus wilting, petal loss and lost; if it is gone, plant habits by hand.
- [ ] **Step 2:** Screenshot (`adb shell screencap -p /sdcard/x.png`, then `adb pull`) and check: the meadow at rest (each face matches its state, bubbles on due flowers, lost seed faded and asleep); the habit screen before and during a watering; the picker; the app drawer icon; the splash.
- [ ] **Step 3:** Turn on "Remove animations" in the emulator's accessibility settings; confirm flowers stand still and faces still match. Turn it back off.
- [ ] **Step 4:** Fix anything unreadable at meadow size, re-run `flutter test`, and commit `fix: flower character polish from the emulator check` if anything changed.
