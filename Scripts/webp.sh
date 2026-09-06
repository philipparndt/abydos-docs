#!/bin/bash
# Every picture under images/, as lossless WebP, with the PNG removed.
#
# Not a compromise: `-lossless` is the same pixels. A window shot of flat UI
# colours is 226 KB as PNG and 38 KB as WebP, and this site now keeps eighteen
# of them in each of eight palettes — 49 MB against 10 MB, in a repository whose
# pictures are re-taken often enough that every re-take would land in the
# history at full weight.
#
# **The scale goes in the name.** A retina capture is twice the picture it is
# meant to be shown as; a PNG says so in a pHYs chunk and an encoder has no
# reason to carry that across, so a converted file arrives claiming to be 3200
# points wide. `name@2x.webp` is the convention the rest of the world already
# uses, and `Scripts/build.py` reads it.
set -euo pipefail

cd "$(dirname "$0")/.."

command -v cwebp >/dev/null || {
	echo "cwebp is not on the PATH — brew install webp" >&2
	exit 1
}

# `nullglob` alone: macOS ships bash 3.2, which has no `globstar` — and under
# `set -e` asking for it is where this script would have ended. The three levels
# are written out instead, which is all there are.
shopt -s nullglob
converted=0
for picture in images/*.png images/*/*.png images/thumbs/*/*.png; do
	# The density the capture was taken at, from the file rather than assumed:
	# most of these are 144 dpi, and the ones that are not must not be told they
	# are.
	dpi="$(sips -g dpiWidth "$picture" 2>/dev/null | awk '/dpiWidth/ {print $2}')"
	scale="$(awk -v d="${dpi:-72}" 'BEGIN { s = int(d / 72 + 0.5); print (s < 1 ? 1 : s) }')"
	out="${picture%.png}@${scale}x.webp"
	cwebp -lossless -quiet -exact "$picture" -o "$out"
	rm "$picture"
	converted=$((converted + 1))
done

echo "==> $converted pictures, $(du -sh images | cut -f1) in images/"
