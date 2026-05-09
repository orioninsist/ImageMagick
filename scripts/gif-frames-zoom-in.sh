#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s INPUT OUTPUT_DIR [duration_seconds=4] [fps=20] [size=800x800] [zoom_percent=10]\n' "$(basename "$0")" >&2
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
zoom_percent=${6:-10}

command -v magick >/dev/null 2>&1 || { echo "magick command not found" >&2; exit 127; }
[ -f "$input" ] || { echo "input not found: $input" >&2; exit 1; }

frames=$(awk -v d="$duration" -v f="$fps" 'BEGIN { n=int(d*f+0.5); if (n < 1) n=1; print n }')
mkdir -p "$out_dir"

base="$out_dir/.base-zoom.png"
magick "$input" -auto-orient -colorspace sRGB \
  -filter LanczosSharp -resize "${size}^" -gravity center -extent "$size" \
  -strip "$base"

i=0
while [ "$i" -lt "$frames" ]; do
  scale=$(awk -v i="$i" -v n="$frames" -v z="$zoom_percent" 'BEGIN { t=(n<=1?0:i/(n-1)); printf "%.6f", 100 + z*t }')
  magick "$base" -filter LanczosSharp -resize "${scale}%" \
    -gravity center -crop "$size+0+0" +repage \
    -define png:compression-level=9 "$out_dir/frame_$(printf '%04d' "$i").png"
  i=$((i + 1))
done
rm -f "$base"

printf 'Wrote %s zoom-in PNG frames to %s (%ss at %s fps). GIF was not created.\n' "$frames" "$out_dir" "$duration" "$fps"
