# Animated Plants Implementation Plan

> **Superseded and done.** This plan first added flowers drawn in code. They
> were later replaced by 30 plant images (commit `8b115c2`). What this plan
> built that is still in the app is the motion: the `FlowerView` widget. The
> current design is
> `docs/superpowers/specs/2026-11-14-animated-flower-characters-design.md`.
> Kept for history only.

**Goal:** Every habit's plant moves gently, grows between stages and reacts
when the habit is logged, without ever wilting.

**Architecture:** A pure function turns a habit's stats into a `FlowerLook`
(kind, stage, lean, bubble). A `FlowerView` widget owns the clock and plays
the idle sway, the logged hop and the stage fade. The screens show a
`FlowerView` wherever a plant appears.

**Tech Stack:** Flutter, Dart, flutter_riverpod 3.x, `flutter_test`. No new
dependencies.

## Global Constraints

- No new packages in `pubspec.yaml`.
- Plants never wilt or die.
- With reduce motion on (`reduceMotion(context)` in `lib/ui/motion.dart`): no
  sway, hop or fade; looks change instantly.
- No golden (screenshot) tests.
- Run `flutter analyze` and `flutter test` before every commit; both must be
  clean.
- Commits are local only. Do not push.

## Review Focus

1. **Plant drawn very small (picker tiles):** painting must not throw.
2. **Reduce motion switched on while an animation is running:** the plant
   settles to its still look at once.
3. **A plant changes stage while on screen:** the view moves to the new look
   without error.
4. **Saved habit with an unknown plant id:** shown as a daisy, nothing throws.

---

### Task 1: Plant look (pure)

**Files:** `lib/flower/look.dart`; test `test/flower/look_test.dart`

- [x] `lookOf` maps stats to stage, lean, bubble; `pickerLook` is full grown.
- [x] Tests: stage follows qualifying days; one missed day does not lean the
  plant; a long gap leans it; unknown id falls back to the daisy.

### Task 2: Animated view

**Files:** `lib/flower/flower_view.dart`; test `test/flower/flower_view_test.dart`

- [x] Idle sway, offset per plant by a seed.
- [x] Hop on each change of `delightTrigger`.
- [x] 0.6 s fade between stages.
- [x] Water-drop badge while due and not done.
- [x] Reduce motion: still, instant changes, also on iOS.
- [x] Tests: every plant and stage paints; reduce motion stops everything,
  including mid-hop; disposing stops the clock.

### Task 3: Use the view on every screen

- [x] Home habit card and habit detail header (both hop when logged), and the
  habit form picker (each plant full grown).

### Task 4: Check it by eye

- [ ] Run on a real device or emulator (demo mode:
  `flutter run --dart-define=DEMO=true`) and check sway, hop, fade and Reduce
  Motion.
