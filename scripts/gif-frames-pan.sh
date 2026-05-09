#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s INPUT OUTPUT_DIR [duration_seconds=4] [fps=20] [size=800x800] [direction=left-to-right]\n' "$(basename "$0")" >&2
}

if [ "$#" -lt 2 ] || [ "$#" -gt 6 ]; then
  usage
  exit 2
fi

input=$1
out_dir=$2
duration=${3:-4}
fps=${4:-20}
size=${5:-800x800}
direction=${6:-left-to-right}

command -v magick >/dev/null 2>&1 || { echo "magick command not found" >&2; exit 127; }
[ -f "$input" ] || { echo "input not found: $input" >&2; exit 1; }

case "$direction" in
  left-to-right|right-to-left|top-to-bottom|bottom-to-top) ;;
  *) echo "direction must be left-to-right, right-to-left, top-to-bottom, or bottom-to-top" >&2; exit 2 ;;
esac

frames=$(awk -v d="$duration" -v f="$fps" 'BEGIN { n=int(d*f+0.5); if (n < 1) n=1; print n }')
mkdir -p "$out_dir"

base="$out_dir/.base-pan.png"
magick "$input" -auto-orient -colorspace sRGB \
  -filter LanczosSharp -resize "${size}^" -resize 112% \
  -gravity center -strip "$base"

read -r base_w base_h target_w target_h <<EOF
$(magick identify -format '%w %h ' "$base"; magick -size "$size" xc:none -format '%w %h' info:)
EOF

i=0
while [ "$i" -lt "$frames" ]; do
  offset=$(awk -v i="$i" -v n="$frames" -v d="$direction" \
    -v bw="$base_w" -v bh="$base_h" -v tw="$target_w" -v th="$target_h" 'BEGIN {
    t=(n<=1?0:i/(n-1));
    max_x=bw-tw; max_y=bh-th;
    x=int(max_x/2); y=int(max_y/2);
    if (d=="left-to-right") x=int(max_x*t);
    else if (d=="right-to-left") x=int(max_x*(1-t));
    else if (d=="top-to-bottom") y=int(max_y*t);
    else y=int(max_y*(1-t));
    printf "%dx%d+%d+%d", tw, th, x, y;
  }')
  magick "$base" -filter LanczosSharp -crop "$offset" +repage \
    -define png:compression-level=9 "$out_dir/frame_$(printf '%04d' "$i").png"
  i=$((i + 1))
done
rm -f "$base"

printf 'Wrote %s pan PNG frames to %s (%ss at %s fps, %s). GIF was not created.\n' "$frames" "$out_dir" "$duration" "$fps" "$direction"
