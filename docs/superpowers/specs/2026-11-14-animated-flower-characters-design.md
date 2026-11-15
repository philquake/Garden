# Animated plants: design

Date: 2026-11-14, revised 2026-11-15 to match the current build. Builds on
`2026-11-15-habit-leaf-redesign-design.md`. (The file name is kept because the
2026-11-14 plan refers to it.)

## Intent

Every habit's plant feels alive: it moves gently, grows as the habit grows,
and reacts when the habit is logged. Opening the app should feel calm and a
little rewarding. Plants have no faces and never wilt or die.

## The plants

- 30 plants in four groups: Flowering, Leafy, Succulents, Tall
  (`lib/flower/plants.dart`, picker order; the first, tulip, is the default
  for a new habit).
- Each has five growth stages, 0 (seed) to 4 (full grown), as transparent
  PNGs: `assets/plants/<id>_<stage>.png`. SVG sources are in
  `docs/art/plants/stages`.
- Each plant has a light-theme and a dark-theme accent colour, used for the
  habit's card wash and charts.
- A saved habit with an unknown plant id shows as a daisy.

## Stage

`stage = min(floor(growth * 4), 4)`, where `growth` is qualifying days over 66
(`Stats.growth`). The plant stays full grown once the habit is formed.

## Motion (`lib/flower/flower_view.dart`)

- **Idle sway:** a slow rotation from the base. Each plant's sway is offset by
  a seed so neighbours do not move in step. Young plants sway less; a plant
  sways a little more while today is due and when full grown.
- **Lean:** once a habit has 5 completions (before that, the score is still
  climbing from zero and means nothing), its plant leans slightly when the
  recent score is below 35% and a little more below 15%. It stands straight
  again as the score recovers. No other change to the picture.
- **Logged:** each successful log plays a short hop (about 0.9 s): the plant
  lifts and grows a touch, then settles.
- **Growing:** when the stage changes on screen, the old picture fades into the
  new one over 0.6 s.
- **Water-drop bubble:** a small water-drop badge at the top right while today
  is due and not done.

## Reduced motion and battery

- With reduce motion on (`reduceMotion` in `lib/ui/motion.dart`, which also
  listens for iOS Reduce Motion): no sway, hop or fade. The plant stands still
  and only its picture and lean change, instantly.
- Each plant repaints inside its own `RepaintBoundary`; the image is decoded at
  the drawn size (capped at 384 px).

## Where plants appear

| Place | Size and behaviour |
|---|---|
| Home habit card | small, live; hops when logged |
| Habit detail header | large, live; hops when logged |
| Habit form picker | 60 px, each plant full grown, in grouped tiles tinted by its colour |

## Testing

- Unit tests for the look: stage from growth, one missed day does not lean
  the plant, a long gap leans it, bubble when due and not done.
- Unit tests that all 30 plants have unique ids, five images on disk and a
  colour for both themes.
- Widget tests that every plant and stage draws, including with reduce motion
  on.
- No golden (screenshot) tests.
