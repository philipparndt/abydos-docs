#!/usr/bin/env python3
"""Assembles the site from `src/` into `dist/`.

The page used to be one file, which is the right answer right up to the point
where there are two pages: the palette, the header and the footer were about to
be copied, and a copy is a thing that drifts. So the parts live apart and this
puts them back together — with no dependencies, because a documentation site
that needs an install before it can be read is worse than the copy.

Three things it does, and nothing else:

  {{ include partials/x.html }}   splices a file in, recursively
  {{ title }}                     substitutes a value from the page's front matter
  <img src="images/x.png">        gets `width` and `height` read from the PNG

The last one is why this is Python rather than `cat`. Intrinsic dimensions stop
the page from jumping while the pictures load, and a number typed by hand beside
a file that a script regenerates is a number that is eventually wrong.

    Scripts/build.py [--out dist] [--src src]
"""

from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import struct
import sys
from pathlib import Path

# `{{ include path/to/file }}` or `{{ name }}`. Whitespace inside is optional so
# that both spellings work, since both will be written.
TOKEN = re.compile(r"\{\{\s*(?:include\s+(?P<include>[^\s}]+)|(?P<name>[\w.-]+))\s*\}\}")

# An <img> that names a file under images/. Deliberately narrow: it matches the
# tag we write, not every possible way HTML can spell one.
IMG = re.compile(r"<img\s+[^>]*?src=\"(?P<src>images/[^\"]+)\"[^>]*?>", re.DOTALL)

FRONT_MATTER = re.compile(r"\A---\n(?P<body>.*?)\n---\n", re.DOTALL)

# Copied into dist/ as they are. Everything else under src/ is a source file
# that gets assembled rather than served.
STATIC = ["images", ".nojekyll"]

MAX_DEPTH = 16


class BuildError(Exception):
	pass


def read_front_matter(text: str, page: Path) -> tuple[dict[str, str], str]:
	"""Splits `key: value` lines fenced by `---` off the top of a page."""
	match = FRONT_MATTER.match(text)
	if not match:
		raise BuildError(f"{page}: no front matter — a page needs at least a title")

	values: dict[str, str] = {}
	for number, line in enumerate(match.group("body").splitlines(), start=2):
		if not line.strip() or line.lstrip().startswith("#"):
			continue
		key, separator, value = line.partition(":")
		if not separator:
			raise BuildError(f"{page}:{number}: not `key: value` — {line!r}")
		values[key.strip()] = value.strip()

	return values, text[match.end():]


def expand(text: str, values: dict[str, str], root: Path, where: str, depth: int = 0) -> str:
	"""Substitutes includes and values, until there are none left.

	Includes are expanded before the text they brought in is scanned again, so a
	partial can include a partial. The depth is bounded because two partials that
	include each other are a hang otherwise, and a hang in a build is a mystery
	rather than an error.
	"""
	if depth > MAX_DEPTH:
		raise BuildError(f"{where}: includes nested more than {MAX_DEPTH} deep — a cycle?")

	def replace(match: re.Match[str]) -> str:
		included = match.group("include")
		if included:
			path = root / included
			if not path.is_file():
				raise BuildError(f"{where}: no such include — {included}")
			return expand(path.read_text(), values, root, str(path), depth + 1)

		name = match.group("name")
		if name not in values:
			known = ", ".join(sorted(values)) or "none"
			raise BuildError(f"{where}: nothing named {name!r} (have: {known})")
		return values[name]

	return TOKEN.sub(replace, text)


def png_info(path: Path) -> tuple[int, int, int]:
	"""Width, height and pixel density, walking the PNG's chunks.

	IHDR is always first and carries the two dimensions as big-endian 32-bit
	integers. pHYs, if it is there at all, carries pixels per metre — 5669 of
	them is 144 dpi, which is a retina capture and means the picture is meant to
	be shown at half its pixel size. A file without pHYs is taken to be 1x,
	which is what the older shots here are.

	The density matters because without it a small picture gets stretched to the
	width of the column and goes soft, which is what happened to the breakpoint
	sheet.
	"""
	data = path.read_bytes()
	if data[:8] != b"\x89PNG\r\n\x1a\n":
		raise BuildError(f"{path}: not a PNG")

	width = height = 0
	density = 1
	offset = 8
	while offset + 8 <= len(data):
		length = struct.unpack(">I", data[offset:offset + 4])[0]
		kind = data[offset + 4:offset + 8]
		body = data[offset + 8:offset + 8 + length]

		if kind == b"IHDR":
			width, height = struct.unpack(">II", body[:8])
		elif kind == b"pHYs" and length >= 9:
			per_metre, _, unit = struct.unpack(">IIB", body[:9])
			if unit == 1 and per_metre:
				# 0.0254 metres to the inch, 72 dpi to the point.
				density = max(1, round(per_metre * 0.0254 / 72))
		elif kind == b"IDAT":
			break  # Everything worth reading comes before the pixels.

		offset += 12 + length

	if not width:
		raise BuildError(f"{path}: no IHDR")
	return width, height, density


def size_images(html: str, root: Path, where: str) -> str:
	"""Gives every local <img> its display size, so the layout does not jump.

	The size written out is the pixel size divided by the density: a 920-pixel
	capture of a 460-point sheet is a 460-wide picture that happens to have twice
	the detail. A `srcset` says so, which is how the browser is told to spend
	those pixels on sharpness rather than on size.

	A picture already carrying both attributes is left alone: a shot that is
	deliberately shown at some other size says so in the tag.
	"""

	def annotate(match: re.Match[str]) -> str:
		tag = match.group(0)
		if "width=" in tag and "height=" in tag:
			return tag

		source = match.group("src")
		path = root / source
		if not path.is_file():
			raise BuildError(f"{where}: <img> names a file that is not there — {source}")

		width, height, density = png_info(path)
		attributes = f' width="{width // density}" height="{height // density}"'
		if density > 1:
			attributes += f' srcset="{source} {density}x"'
		return tag[:-1].rstrip() + attributes + ">"

	return IMG.sub(annotate, html)


def build(src: Path, out: Path) -> int:
	layout_path = src / "layout.html"
	if not layout_path.is_file():
		raise BuildError(f"no layout at {layout_path}")
	layout = layout_path.read_text()

	pages = sorted((src / "pages").glob("*.html"))
	if not pages:
		raise BuildError(f"no pages in {src / 'pages'}")

	# One stylesheet from every file in src/styles, in name order — which is why
	# they are numbered. The palette has to land before what uses it.
	sheets = sorted((src / "styles").glob("*.css"))
	if not sheets:
		raise BuildError(f"no stylesheets in {src / 'styles'}")
	css = "\n".join(f"/* {sheet.name} */\n{sheet.read_text().strip()}" for sheet in sheets) + "\n"

	if out.exists():
		shutil.rmtree(out)
	out.mkdir(parents=True)

	(out / "assets").mkdir()
	(out / "assets" / "site.css").write_text(css)

	# The URL carries a digest of the contents. Pages sets a long cache lifetime
	# on assets, and a stylesheet that changed under a URL that did not is a
	# reader looking at last week's colours.
	stylesheet = f"assets/site.css?v={hashlib.sha256(css.encode()).hexdigest()[:8]}"

	root = Path.cwd()
	for name in STATIC:
		source = root / name
		if not source.exists():
			continue
		if source.is_dir():
			shutil.copytree(source, out / name)
		else:
			shutil.copy2(source, out / name)

	for page in pages:
		values, body = read_front_matter(page.read_text(), page)
		values.setdefault("og_title", values.get("title", ""))
		values.setdefault("og_description", values.get("description", ""))
		values["stylesheet"] = stylesheet

		values["body"] = expand(body, values, src, str(page))
		html = expand(layout, values, src, str(layout_path))
		html = size_images(html, root, str(page))

		(out / page.name).write_text(html)
		print(f"  {out / page.name}")

	print(f"==> {len(pages)} pages, {len(sheets)} stylesheets, into {out}/")
	return 0


def main() -> int:
	parser = argparse.ArgumentParser(description="Assemble the site from src/ into dist/.")
	parser.add_argument("--src", type=Path, default=Path("src"))
	parser.add_argument("--out", type=Path, default=Path("dist"))
	arguments = parser.parse_args()

	try:
		return build(arguments.src, arguments.out)
	except BuildError as error:
		print(f"build: {error}", file=sys.stderr)
		return 1


if __name__ == "__main__":
	raise SystemExit(main())
