# AGENTS.md

`nuc-rack.scad` is the whole design: a parametric OpenSCAD model of a printed
rack for the NUC with a 120 mm fan underneath. [README.md](README.md) covers
printing, assembly and the parameters. Nothing here is JavaScript; the root
lint and typecheck commands do not apply.

## Commands

- **STLs and preview images**: `./render.sh`
- **Product shots**: `./product/render.sh [black|white|clear] [shot ...]`

After any change to the model, run `./render.sh` and commit the regenerated
`stl/` and `renders/*.png` together with the source.

## How the model is built

- Coordinates: X is width (centred), Y is depth (0 at the rear, `D` at the
  front), Z is up.
- The body prints standing on its rear face, so print height is model Y.
  Anything extruded along Y prints by itself. Anything that starts in mid-air
  further up has to grow out of existing material at 45° or less, or be a
  bridge. The model has one bridge, 61 mm, under the front bar of the seat.
- The panels print front face down. They snap in with four cantilever fingers;
  the grooves sit a little behind the bumps, so the fingers stay bent by
  `snap_preload` and pull the panel against its stops. Each panel rests on a
  lip or a rebate along its top and its bottom edge.
- The opening in the seat, the NUC and the fan share one centre (`fan_y`).

## Checking a change

OpenSCAD reports nothing when parts collide. Intersect the parts and look at
the volume of the result, for example in a scratch file:

```scad
include <nuc-rack.scad>
intersection() { body(); fan_panel(); }
```

run with `openscad -D 'part="none"' --backend=manifold -o check.stl check.scad`.

- body with either panel: about 3.8 mm³, the intended bend at the snap bumps
- body with `nuc_dummy()`, `fan_dummy()`, `filter_dummy()`: zero volume
- panels with the dummies, and with each other: empty

Look at the result as well: cut the model open with `difference()` and render
it from an angle. A face-on orthographic view of a single colour shows nothing.

## What is known from real parts

- NUC 14 Pro slim: 117 × 112 × 37 mm from the spec sheet. Four round feet of
  about 9 mm, centres about 9 mm in from each edge (measured from a photo of
  the tall model, good to about 1 mm).
- Noctua NF-A12x25: 120 × 120 × 25 mm, 27 mm thick with its anti-vibration
  pads. A printed bay of fan size plus 0.3 mm per side takes the bare frame
  only; the pads have to come off.
- The dust filter is 120 × 120 × 2 mm and fits the same bay with nothing to
  spare.
- The first print had panels that wobbled: grooves with play and stops only
  halfway up. That is why the grooves are preloaded and every panel edge has a
  stop now.

## Working on it

- Show a render of every visible change; the owner decides on looks by eye.
- Say what a change costs (print risk, airflow, size) before making it, and say
  which parts need a reprint afterwards.
- The owner likes the click-in panels, symmetry, thin walls and a model that
  prints without supports.
