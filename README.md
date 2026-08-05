# ideai-docs

The website for [ideai](https://philipparndt.github.io/ideai-docs/) — a
terminal-first IDE for AI and cloud development, on macOS.

A repository of its own because the program's is private, and GitHub Pages will
not serve a site from a private repository without a paid plan. Nothing else is
here: the page is the deliverable.

## What is in it

- `index.html` — the whole site. Self-contained: no build step, no dependencies,
  no external requests. The palette is the app's own, in both light and dark, and
  the icon is the same shapes `Scripts/make-icon.py` draws, as inline SVG.
- `.nojekyll` — Pages serves the file as it is rather than running Jekyll over it.

## Changing it

Edit `index.html` and push. Pages redeploys within a minute; there is nothing to
build and nothing to install.

To see it before pushing:

```sh
open index.html
```

That renders exactly what is served, which is the point of keeping it to one
file.
