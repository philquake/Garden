# Animated flower characters: design

Date: 2026-11-14. Builds on `2026-11-07-watercolour-garden-habit-tracker-design.md`.

## Intent

Every habit's flower becomes a cartoon character with a face. The face and
body show how the habit is doing, and the flower moves gently.

Why: opening the app should mostly make the user smile. When a habit is
slipping, its flower should cause a small pang, and one tap of water should
fix that pang at once. The meadow should also answer "what is left today?" at
a glance.

Style reference (supplied by the user, not to be copied): hand-drawn cartoon
flowers with thick ink outlines, flat colour, a round yellow face with big
eyes, round petals around the face, and two leaves used like hands. We design
our own character in that spirit.

## Goals

- One character design, shared by all four flower kinds, drawn in code.
- A face and pose for every habit state (table below).
- Gentle idle motion, bigger motion only on events.
- Works at three sizes: meadow (56 to 136 px), habit screen (240 px), flower
  picker (64 px).
- The launcher icon and splash show the same character.

## Non-goals

- Restyling the meadow, buttons, cards or type. Only the flowers change.
- Sound.
- Eyes that follow a finger, flowers asleep at night, flowers reacting to each
  other, a different face per flower kind.
- iOS icon and launch screen, and the pre-Android-8 PNG icons (still the
  defaults, as before).
- Any change to growth, neglect, fresh-start or replant rules.

## Anti-goals

- Guilt. The saddest a flower ever looks is one tear and a slump. No crying,
  no dead flowers, no angry or accusing faces. A lost flower is asleep.
- A flower that stays sad after being watered. Watering always produces the
  delighted reaction straight away.
- Motion that ignores the phone's reduce-motion setting.

## Approaches considered

1. **Drawn in Flutter code with a custom painter (chosen).** Petals, face and
   leaves are shapes; code moves them. Blink, sway and expression changes are
   cheap, there is no new dependency, the app stays small, and it is sharp at
   every size. Limit: clean vector shapes only, which matches the cartoon
   style.
2. **Rive or Lottie files.** Richer hand animation, but needs an animator and
   a design tool, and adds a dependency.
3. **Image frames.** Can match a drawing exactly, but needs many images per
   kind, stage, state and expression, and makes the app much bigger.

The user picked 1.

## The character

Shared by all kinds: a round honey-yellow face, two large eyes with a
highlight, small brows, a simple mouth, optional rosy cheeks, a green stem,
and two leaves that act as hands. Ink-brown outlines (`inkBrown`), flat fills
from the existing palette in `lib/ui/theme.dart`. Outline width scales with
the drawn size.

Kinds (ids unchanged: `tulip`, `sunflower`, `lavender`, `daisy`; order
unchanged, tulip first):

| Kind | Petals |
|---|---|
| Tulip | dusty-pink cupped petals rising around the face from below |
| Sunflower | a ring of honey-yellow pointed petals; face a slightly warmer tone |
| Daisy | a ring of white rounded petals |
| Lavender | a ring of small purple puffs; adds one muted lavender colour to the palette |

A saved habit with an unknown `flowerId` is drawn as a daisy.

### Growth stages (`displayStage`, 0 to 4)

| Stage | Shape |
|---|---|
| 0 seed | a soil mound with the face peeking out |
| 1 sprout | a short stem with two leaves, the face on a small green bud |
| 2 bud | a closed bud on a short stem, with leaf hands |
| 3 young bloom | a half-open flower on a taller stem |
| 4 full bloom | petals all round the face |

### Faces and poses

The look is a pure function of the habit and today's day index. Checked in
this order; the first match wins.

| # | Condition | Face | Pose and motion |
|---|---|---|---|
| 1 | `lost` | peacefully asleep | stage 0 seed, faded (the current 0.45 opacity), still |
| 1a | `declineStep >= 1` and already watered today | hopeful, looking up | the pose of its decline step (upright, droop or slump); no bubble |
| 2 | `declineStep == 3` (petal loss) | sad, one tear | slumped; some petals missing, two lying on the ground; barely moves |
| 3 | `declineStep == 2` (wilting) | worried, brows up, glancing at the viewer | stem and head droop; slow sway |
| 4 | `freshStartDay >= 0` and `declineStep == 0` | hopeful, looking up | upright; on first showing, lifts slowly back upright |
| 5 | needs water today, or `declineStep == 1` (thirsty) | expectant, looking at the viewer | normal sway |
| 6 | stage 0 | sleepy, eyes closed | slow breathing |
| 7 | stages 1 and 2 | curious, wide eyes | small sway |
| 8 | stage 3 | content smile | sway |
| 9 | stage 4 | big grin, rosy cheeks | happy sway |

Wilting and petal loss apply at every stage. Stages 0 and 1 have no petals,
so they only droop and change face.

**Water-drop thought bubble:** shown whenever the flower has not been watered
today, is not lost, and either needs water today or is thirsty
(`declineStep >= 1`), whichever row sets the face. (Row 1a and the
"not watered today" condition were added during the build: a flower already
watered today cannot be helped further, so it must not keep asking.)
So a hopeful, wilting or sad flower that is due today also shows the bubble,
and the meadow's "needs water today" label follows the same rule. (Author's
call: a fresh start must not hide that a flower is due. Once a fresh-started
flower is missed again and turns thirsty, the hopeful face ends.)

**Needs water today** (new pure function in the domain layer):
- never when lost, and never when today is already in `wateredDays`;
- daily: yes;
- weekday: yes when today is that weekday;
- times a week: yes while this week's waterings are below the weekly target.

**Delighted (event, not a state):** on every tap of the flower on the habit
screen that does not fail, the flower squeezes its eyes shut, claps its
leaves and bounces once, then settles into its state. This uses the same
trigger as the existing `WaterEffect` droplets (`_waterTaps`), which stay, so
tapping an already-watered flower replays it (author's call). A light haptic
tick plays on the same event. Back-filling a calendar day does not trigger
it. A lost flower does not react.

**Growing:** when a flower's stage changes while it is on screen, it grows
into the new shape over about 0.6 s.

**Blink:** every non-sleeping face blinks every few seconds, at a time that
differs per flower (seeded from the habit id, as sway phase is today).

### Reduced motion and battery

- With reduce motion on (`reduceMotion` in `lib/ui/motion.dart`): no sway,
  blink, bounce, lift or growth tween. Faces and poses still change; changes
  are instant.
- Nothing animates while the app is in the background.
- Up to 8 flowers animate at once in the meadow; idle motion must stay cheap
  (repaint only the flowers, not the meadow background).

## Data change

`Habit` gains `freshStartDay` (int, default -1 = none).

- `freshStart` sets it to today.
- `water` sets it to -1 whenever it records a new watering, including a
  back-filled day (author's call: any new watering ends the hopeful state).
  `replant` also sets it to -1.
- Saved with the habit; gardens saved before the field existed load as -1.

## Where flowers appear

| Place | Today | After |
|---|---|---|
| Meadow (`meadow_screen.dart`) | PNG, sway by rotation | live character; label below unchanged |
| Habit screen (`habit_screen.dart`) | 240 px PNG | 240 px live character; tap still waters |
| Form picker (`habit_form.dart`) | stage 2 PNG per kind | each kind as a happy full bloom (row 9), idle motion |
| Launcher icon, splash (Android vector drawables) | plain flower | the happy full-bloom daisy; paper background stays |

Screen-reader labels keep their current wording. The meadow label adds
"needs water today" whenever the bubble shows, so the thought bubble is not
the only signal.

## Removed

The PNG art pack is retired: `lib/art/art_pack.dart`,
`lib/state/art_provider.dart`, `assets/art/placeholder/` (36 PNGs and
`manifest.json`), the `assets:` entry in `pubspec.yaml`,
`docs/art-pack.md`, `test/art/art_pack_test.dart`, and the pack loading in
`lib/main.dart`. `FlowerHealth`/`healthOf` move or are replaced as the builder
sees fit; the meadow's health words must keep working. Tests that override
`artPackProvider` are updated.

## Testing

- Unit tests for the look function over the whole table, including the
  priority order and "needs water today" for each schedule kind.
- Unit tests for `freshStartDay`: set by fresh start, cleared by watering and
  replant, absent in old JSON.
- A widget test per screen that the flower draws without errors, for every
  kind, stage and state, including with reduce motion on.
- No golden (screenshot) tests.
- A by-eye check on the emulator. The emulator already holds a demo garden of
  8 habits (every stage and kind, plus wilting, petal loss and lost), loaded
  by hand into the app's saved data in an earlier session. It is not in the
  repo and nothing needs building for it. If it is gone, plant habits by hand.

## Left to the builder

- Exact shapes, proportions and curves of the character, within the
  descriptions above. Faces must be readable at the meadow's smallest size
  (56 px); details such as the tear or cheeks may be simplified at small
  sizes.
- File layout for the new flower code, and how the animation clock is shared.
- Timing and easing, other than the 0.6 s growth.
- The exact lavender colour.
