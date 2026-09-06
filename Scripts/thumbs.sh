#!/bin/bash
# Small copies of the screenshots, for the grid on the front page.
#
# The grid shows eleven pictures at once. At full size that is megabytes to look
# at a page of links, and the pictures are 1280 points wide to be read at, which
# is not what a tile is for. So each gets a copy a quarter of the width, in every
# palette, and the page names the copy.
#
# `sips`, which is macOS's own and is already required to be here: the pictures
# need a Mac to make in the first place. It reads and writes PNG, which is why
# this runs before `Scripts/webp.sh` rather than after it.
#
# Regenerated rather than kept in step by hand. A thumbnail is derived, so it is
# `make thumbs` after `make shots`, and both are committed because a runner
# cannot make either.
set -euo pipefail

cd "$(dirname "$0")/.."
WIDTH="${WIDTH:-800}"

shopt -s nullglob
made=0
for palette in images/*/; do
	name="$(basename "$palette")"
	[ "$name" = "thumbs" ] && continue
	out="images/thumbs/$name"
	mkdir -p "$out"
	for picture in "$palette"*.png; do
		sips --resampleWidth "$WIDTH" "$picture" --out "$out/$(basename "$picture")" >/dev/null
		made=$((made + 1))
	done
done
echo "==> $made thumbnails at ${WIDTH}px"
