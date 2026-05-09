#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s INPUT OUTPUT_DIR [duration_seconds=4] [fps=20] [size=800x800]\n' "$(basename "$0")" >&2
}

if [ "$#" -lt 2 ] || [ "$#" -gt 5 ]; then
  usage
  exit 2
fi

input=$1
out_dir=$2
duration=${3:-4}
fps=${4:-20}
size=${5:-800x800}

command -v magick >/dev/null 2>&1 || { echo "magick command not found" >&2; exit 127; }
[ -f "$input" ] || { echo "input not found: $input" >&2; exit 1; }

frames=$(awk -v d="$duration" -v f="$fps" 'BEGIN { n=int(d*f+0.5); if (n < 1) n=1; print n }')
mkdir -p "$out_dir"

tmp="$out_dir/.base-still.png"
magick "$input" -auto-orient -colorspace sRGB \
  -filter LanczosSharp -resize "${size}^" -gravity center -extent "$size" \
  -strip -define png:compression-level=9 "$tmp"

i=0
while [ "$i" -lt "$frames" ]; do
  cp "$tmp" "$out_dir/frame_$(printf '%04d' "$i").png"
  i=$((i + 1))
done
rm -f "$tmp"

printf 'Wrote %s PNG frames to %s (%ss at %s fps). GIF was not created.\n' "$frames" "$out_dir" "$duration" "$fps"
