# Art pack handoff

How to generate the real flower artwork with an AI image model and install it.
The app currently ships a generated placeholder pack (`assets/art/placeholder/`).

## Manifest format

`assets/art/<pack>/manifest.json`:

```json
{
  "tulip": {
    "0": { "healthy": ["assets/art/watercolour/tulip_0_healthy.png"] },
    "1": { "healthy": ["assets/art/watercolour/tulip_1_healthy.png"] },
    "2": {
      "healthy":   ["assets/art/watercolour/tulip_2_healthy.png"],
      "thirsty":   ["assets/art/watercolour/tulip_2_thirsty.png"],
      "wilting":   ["assets/art/watercolour/tulip_2_wilting.png"],
      "petalLoss": ["assets/art/watercolour/tulip_2_petalLoss.png"]
    },
    "3": { "healthy": ["assets/art/watercolour/tulip_3_healthy.png"] },
    "4": { "healthy": ["assets/art/watercolour/tulip_4_healthy.png"] }
  }
}
```

flowerId -> stage `"0".."4"` -> health `healthy | thirsty | wilting | petalLoss`
-> list of frame asset paths (full paths from the project root). More than one
frame in a list plays as a short animation loop; one frame is a still that the
app sways.

Stages: 0 seed, 1 sprout, 2 bud, 3 young bloom, 4 full bloom.

### Fallback (`ArtPack.framesFor`, never throws)

For a requested stage and health, it tries the same stage with the requested
health, then healthier states of that stage; then lower stages, then higher
stages (same health order). If the flower has nothing, it uses the first flower
in the manifest, then any frame of the flower, then the built-in placeholder.
So missing frames never crash; they just reuse nearby art.

## How many images

- Full pack: 5 stages x 4 health states = 20 per flower (more if you add frames).
- Minimum viable (matches the placeholder): every stage healthy (5), plus
  wilting and petalLoss for stages 2 and 4 (4) = 9 per flower.

## Image specs

- PNG, transparent background, square, 768x768 or 1024x1024 source
- Flower centred, base at the bottom-centre so the sway pivots naturally
- Same scale between stages so growth reads correctly
- Soft watercolour: translucent washes, visible paper grain, wet edges, pale
  colour bleeds; no hard outlines; no text

## Style anchor (paste into every prompt)

> Soft botanical watercolour illustration on a transparent background: thin
> translucent washes of colour, visible cold-press paper grain, wet-in-wet
> edges with pale colour bleeds, gentle muted palette (sage greens, dusty pinks,
> warm creams), no hard outlines, no black ink, no text, no shadow or ground.
> Single plant centred, stem base at the bottom-centre of a square canvas.

## Prompt template

```
[STYLE ANCHOR]
Subject: a {FLOWER NAME} plant, {STAGE DESCRIPTION}, {HEALTH STATE}.
Keep the same plant, scale and palette as the reference image.
```

- STAGE DESCRIPTION: `a seed just planted in a tiny mound` / `a small sprout
  with two leaves` / `a closed bud on a short stem` / `a young half-open bloom`
  / `a full bloom with all petals open`
- HEALTH STATE:
  - healthy: `upright, fresh and vibrant`
  - thirsty: `a slight droop of the stem and head, colours still fresh`
  - wilting: `drooping, muted and faded colours, leaves limp`
  - petal loss: `bare patches where petals are missing, fallen petals beside the stem, muted colours`

Tip: generate stage 4 healthy first, then derive every other stage and health
state from it as image-to-image references so the flower stays consistent.
Remove backgrounds to transparent PNG afterwards if the model cannot.

## Install

1. Put the files in `assets/art/watercolour/` with `manifest.json`.
2. Register the directory in `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/art/placeholder/
       - assets/art/watercolour/
   ```
3. Nothing else: `lib/main.dart` loads the pack named `watercolour` at start and
   falls back to the placeholder if it is missing or broken. To use another
   name, change the `pack:` argument in `main.dart`.

Do not add the pubspec line before the directory exists; the build fails.

## Flower ids

Placeholder ids: `tulip`, `sunflower`, `lavender`, `daisy`. Habits store the
flower id the user picked, and the picker lists the manifest's flowers, so real
ids should match these (or accept that habits with an unknown id fall back to
the first flower).

## Verification checklist

- [ ] `flutter test test/art` passes (parse and framesFor checks)
- [ ] `flutter run`: plant each flower; the picker shows every flower
- [ ] Water it and check the sway pivots from the stem base
- [ ] Stage and health art: fast-forward is not possible in the running app,
      so use test overrides of `todayProvider` (see `test/flows/garden_flow_test.dart`)
      or temporary debug habits to view each state
- [ ] No hard edges or white boxes around the flower on the meadow
