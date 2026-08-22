# abydos-docs

The website for [Abydos](https://philipparndt.github.io/abydos-docs/) — a
terminal-first IDE for AI and cloud development, on macOS.

## What is in it

    src/layout.html        the shell every page is poured into
    src/styles/*.css       concatenated, in name order, into one stylesheet
    src/partials/          the icon and the footer, included by name
    src/pages/*.html       one file per page, with its title in front matter
    Scripts/build.py       assembles src/ into dist/
    Scripts/screenshots.sh drives the app and photographs it into images/
    Scripts/thumbs.sh      small copies of those, for the grid on the front page
    images/                the pictures, committed — they need a Mac to make
    images/thumbs/         derived from them by `make thumbs`, committed too
    Makefile               the commands below

`dist/` is the site and is not committed: the workflow builds it on every push.

## Changing it

```sh
make            # assemble src/ into dist/
make serve      # ...and serve it on http://localhost:8000
make help       # everything else
```

There is a build because there is more than one page, and pages sharing a
palette, a header and a footer by having been copied are pages that drift.
Nothing is installed to run it — `python3` is on macOS and on the runner.

The templating is three things and deliberately no more:

- `{{ include partials/footer.html }}` splices a file in, recursively.
- `{{ title }}` substitutes a value from the page's front matter — the `---`
  fenced block at the top of each file in `src/pages/`.
- `<img src="images/x.png">` is given `width` and `height` read out of the PNG.

That last one is the reason the build is a program rather than a `cat`.
Intrinsic dimensions stop the page from jumping as the pictures load, and a
number typed by hand beside a file a script regenerates is eventually wrong. A
page that names a picture that is not there fails the build instead of shipping
a broken image.

## The pictures

```sh
make screenshots        # the nine the pages use, in the app's own theme
make theme-shots        # one scene in each palette, for themes.html
make shots              # both
make thumbs             # small copies of all of them, after either
```

`make thumbs` is `sips`, which is macOS's own. The front page shows nine at
once, and nine full screenshots is four megabytes to look at a page of links.

Every picture is the app doing the thing the page claims, on a project from the
examples repository that anybody can clone.

It needs both other checkouts beside this one:

    git clone https://github.com/philipparndt/abydos.git           ../abydos
    git clone https://github.com/philipparndt/abydos-examples.git  ../abydos-examples

Both are public. Each is looked for under its old name as well, and the new one
wins:

    ABYDOS=../abydos             or ../ideai
    EXAMPLES=../abydos-examples  or ../ideai-examples

Both are overridable, as are `OUT`, `SIZE`, `THEME` and which shots to take:

```sh
Scripts/screenshots.sh site debugger      # just that one
THEME=light Scripts/screenshots.sh site   # the pages, in daylight
```

`THEME` takes what Settings stores — `abydos`, `abydos-light`, `dark`, `light`,
`dracula`, `dracula-light` — and defaults to `abydos`. It is checked against that
list before the app is launched, because the app treats an unrecognised value as
"follow the system": `--theme daylight` on a dark Mac quietly photographs dusk
instead of failing.

`themes.html` names the palettes — `abydos`, `abydos-light`, `dusk`, `daylight`,
`dracula`, `dracula-light` — and the script maps between the two spellings. Three
themes with a light and a dark each is six pictures; the three values that mean
"follow the system" are not photographed.

The captures are reproducible on purpose: the window is given a size, the panel
is given a height, and the examples are cloned — not copied, since the titlebar
says which branch — into a temporary directory first. The clone's `origin` is set
to wherever the examples checkout points, so the rows the palette offers name
GitHub rather than a directory in `/tmp`.

Four shots want a working environment rather than just the app. `debugger` needs
Delve and a Go toolchain; `terminal` needs `tmux`, and will attach to a session
that is already running, so check what came out before committing it. `scad`
needs OpenSCAD and `cadova` a Swift toolchain and the network once — it is also
the slow one, at about three and a half minutes, since every shot gets a fresh
clone and compiles a C++ geometry kernel from cold. `diagram` needs nothing: it
is Mermaid, which is inside the app.

`palette` photographs a popover, which is a window of its own and so is nowhere
in the picture of the window it is over. The app writes it out beside the
capture and the script moves it onto the name that was asked for, the same way
`breakpoint` handles its sheet.

## Publishing

`.github/workflows/pages.yml` runs `make build` and uploads `dist/`. Pull
requests build without publishing; `main` builds and deploys; `workflow_dispatch`
re-runs a deployment that stalled.

Pages' own branch pipeline used to do this, until it started sitting at
`deployment_in_progress` until the ten-minute default gave up. A workflow of our
own is the same steps written down, so they can be re-run and read when they
fail.
