#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s INPUT OUTPUT_DIR [duration_seconds=4] [fps=20] [size=800x800] [max_degrees=2]\n' "$(basename "$0")" >&2
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
max_degrees=${6:-2}

command -v magick >/dev/null 2>&1 || { echo "magick command not found" >&2; exit 127; }
[ -f "$input" ] || { echo "input not found: $input" >&2; exit 1; }

frames=$(awk -v d="$duration" -v f="$fps" 'BEGIN { n=int(d*f+0.5); if (n < 1) n=1; print n }')
mkdir -p "$out_dir"

base="$out_dir/.base-pulse.png"
magick "$input" -auto-orient -colorspace sRGB \
  -filter LanczosSharp -resize "${size}^" -resize 108% \
  -gravity center -strip "$base"

i=0
while [ "$i" -lt "$frames" ]; do
  vals=$(awk -v i="$i" -v n="$frames" -v md="$max_degrees" 'BEGIN {
    pi=atan2(0,-1);
    t=(n<=1?0:i/(n-1));
    wave=sin(2*pi*t);
    zoom=104 + 2*wave;
    angle=md*wave;
    printf "%.6f %.6f", zoom, angle;
  }')
  set -- $vals
  zoom=$1
  angle=$2
  magick "$base" -background none -virtual-pixel edge \
    -filter LanczosSharp -distort SRT "$zoom $angle" \
    -gravity center -crop "$size+0+0" +repage \
    -define png:compression-level=9 "$out_dir/frame_$(printf '%04d' "$i").png"
  i=$((i + 1))
done
rm -f "$base"

printf 'Wrote %s pulse/rotate PNG frames to %s (%ss at %s fps). GIF was not created.\n' "$frames" "$out_dir" "$duration" "$fps"
