#!/bin/sh
# Ray-traced product shots, written to ../renders/product-*.png.
#   ./render.sh [black|white|clear] [shot ...]     shots: hero rear exploded open detail colours
# Needs openscad and uv; Blender's renderer comes in through uv as the bpy package, nothing to install.
# INFILL=0 with "clear" draws the thick parts solid, as printed with enough wall loops.
cd "$(dirname "$0")" || exit 1
variant=${1:-black}
[ $# -gt 0 ] && shift
[ $# -eq 0 ] && set -- hero rear exploded open detail
meshes=$(mktemp -d)
trap 'rm -rf "$meshes"' EXIT
for p in body fan_panel nuc_panel core filter filter_mesh fan_frame fan_rotor nuc_body nuc_metal nuc_blue nuc_dark nuc_led; do
  openscad -o "$meshes/$p.stl" -D 'part="none"' -D "piece=\"$p\"" --backend=manifold --export-format binstl \
    parts.scad 2>&1 | grep -E "WARNING|ERROR" &
done
wait
openscad -o "$meshes/dims.echo" -D 'part="none"' -D 'piece="none"' parts.scad 2>/dev/null
sed -n 's/.*dims = \[\(.*\)\].*/\1/p' "$meshes/dims.echo" > "$meshes/dims.txt"
name=$([ "$variant" = clear ] && echo translucent- || { [ "$variant" = black ] || echo "$variant-"; })
for shot in "$@"; do
  uv run --quiet --python 3.11 --with bpy render.py "$meshes" "$PWD/../renders/product-$name$shot.png" \
    "$shot" "${WIDTH:-2400}" "${SAMPLES:-128}" "$variant" 2>&1 | grep -E "Error|Traceback|line [0-9]+"
done
exit 0
