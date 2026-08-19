#!/bin/bash
# Small copies of the screenshots, for the grid on the front page.
#
# The grid shows eight pictures at once. At full size that is four megabytes of
# PNG to look at a page of links, and the eight are 1600 wide to be read at —
# which is not what a tile is for. So each gets a copy a quarter of the width,
# and the page names the copy.
#
# `sips`, which is macOS's own and is already required to be here: the pictures
# need a Mac to make in the first place. No Homebrew, no Python imaging library,
# nothing to install and nothing to keep current — the same rule the build
# follows.
#
# Regenerated rather than kept in step by hand. A thumbnail is derived, so it is
# `make thumbs` after `make shots`, and both are committed because a runner
# cannot make either.
set -euo pipefail

cd "$(dirname "$0")/.."
WIDTH="${WIDTH:-800}"
OUT=images/thumbs

mkdir -p "$OUT"
shopt -s nullglob
thumb() {
	local picture="$1" name="$2"
	sips --resampleWidth "$WIDTH" "$picture" --out "$OUT/$name" >/dev/null
	printf '  %-28s %s\n' "$OUT/$name" "$(du -h "$OUT/$name" | cut -f1)"
}

for picture in images/*.png; do
	thumb "$picture" "$(basename "$picture")"
done

# The themes page's own gallery, one of which stands for the whole page on the
# grid. Prefixed, because `abydos.png` under images/themes/ and a tile called
# `abydos.png` in one flat directory would be two different pictures with one
# name the day another set arrives.
#
# Both lightnesses, because the tile that stands for the themes page must not be
# in the theme every other tile is already in: eight amber windows and a ninth
# amber window says nothing about palettes. The page uses the daylight one, which
# is the one that differs at a glance rather than on inspection.
for picture in images/themes/abydos.png images/themes/daylight.png; do
	thumb "$picture" "themes-$(basename "$picture")"
done
echo "==> thumbnails at ${WIDTH}px"
