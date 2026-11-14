#!/bin/sh
# Renders preview images and print-ready STLs.
cd "$(dirname "$0")" || exit 1
mkdir -p renders stl
r() { # name part rot_x rot_z
  openscad -o "renders/$1.png" -D "part=\"$2\"" --camera="0,0,0,$3,0,$4,500" --viewall --autocenter \
    --imgsize=1600,1200 --projection=p --render --backend=manifold --colorscheme=Tomorrow \
    nuc-rack.scad 2>&1 | grep -E "WARNING|ERROR"
}
r front-iso  assembly 68 205
r front      assembly 90 180
r side-iso   assembly 75 250
r rear-iso   assembly 65 30
r exploded   exploded 62 215
r section    section  90 180
r print      print    55 205
for p in body fan-panel nuc-panel; do
  openscad -o "stl/$p.stl" -D "part=\"$p\"" --backend=manifold --export-format binstl nuc-rack.scad 2>&1 |
    grep -E "WARNING|ERROR"
done
exit 0
