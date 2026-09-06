# abydos-docs

The website for [Abydos](https://philipparndt.github.io/abydos-docs/) — a
terminal-first IDE for AI and cloud development, on macOS.

## What is in it

    src/layout.html        the shell every page is poured into
    src/styles/*.css       concatenated, in name order, into one stylesheet
    src/styles/50-palettes.css   generated — the app's own schemes, as CSS
    src/partials/          the icon, the footer and the switcher, by name
    src/partials/palettes.js     generated beside the stylesheet above
    src/pages/*.html       one file per page, with its title in front matter
    Scripts/build.py       assembles src/ into dist/
    Scripts/palettes.py    writes the palettes out of the app's scheme files
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

## The palettes

The site wears the app's own themes, and the switcher at the foot of every page
is the demonstration — a page about colour asking to be taken on trust is a page
that could have said anything.

```sh
make palettes   # after the app's colours change
```

It reads `Sources/AbydosKit/Settings/Schemes/*.json` from the app checkout and
writes `src/styles/50-palettes.css` and `src/partials/palettes.js`, both
committed. Generated rather than typed, for the reason the screenshots are
generated: a palette copied into a stylesheet by hand is right on the day it is
copied, and nothing would say when it stopped being. Committed rather than built
on the runner, for the reason the pictures are committed: the runner has no app
checkout beside this one, and no Mac to photograph one with.

Two questions rather than one list, which is how the app asks it: the family on
`data-family`, how light on `data-mode`, both kept in `localStorage` so the
answer survives following a link. A palette written onto the page in the markup
wins over the stored one, which is how a driven run photographs the site in each
of them. Without JavaScript the page is `00-palette.css`, which is Abydos
following the display — the palette the app itself used to open in.

## The pictures

```sh
make pictures           # all three below, in the order they have to run
make shots              # every picture in every palette — over an hour
make thumbs             # small copies, for the grid on the front page
make webp               # lossless WebP, and the PNGs removed
```

**Every picture exists in all eight palettes**, under `images/<family>-<light|dark>/`,
because the switcher at the top of the page moves the screenshots with the
colours: a page in daylight showing eight windows at midnight would be a
demonstration of the opposite of what it claims. The site's own script composes
the path from the two answers it already holds, which is why the folders are
named for the family and the lightness rather than for the names the themes page
gives them.

That is eighteen shots times eight, and it is why the pictures are WebP. A window
shot of flat interface colours is 337 KB as a PNG and 76 KB as lossless WebP —
the same pixels — so the whole set, thumbnails and all, is seventeen megabytes
rather than sixty, in a repository whose pictures are re-taken often enough that
every re-take lands in the history at whatever it weighs. `cwebp` is the one tool
here that is not already on a Mac: `brew install webp`.

**The scale is in the name.** A retina capture is twice the picture it is meant
to be shown as; a PNG says so in a `pHYs` chunk, and an encoder has no reason to
carry that across — so `name@2x.webp`, which `Scripts/build.py` reads. Without it
anything narrower than the column is stretched to it and goes soft.

**The runs trust the project they open.** A project is not trusted until somebody
says so, and an untrusted one wears a strip saying nothing in it runs — true, and
a sentence about a directory the script made in /tmp thirty seconds ago rather
than about anything a page here claims. So every capture passes `--trust`, and no
capture is earlier than ten seconds, because trusting says so in a toast and a
toast lives eight of them.

**A long sweep wants an app that holds still.** `make shots` takes over an hour,
and an app rebuilt under it produces a set that disagrees with itself — the first
palettes from one binary and the last from another. Copy the bundle somewhere of
its own and point at that:

```sh
cp -R ../abydos/build/Abydos.app /tmp/frozen.app
APP=/tmp/frozen.app/Contents/MacOS/Abydos make shots
```

`APP` and not `ABYDOS`: the checkout is still wanted, because the pull request
shot clones it.

`make thumbs` is `sips`, which is macOS's own and reads PNG, which is why it runs
before the WebP step rather than after it. The front page shows eleven pictures at
once, and eleven full screenshots is megabytes to look at a page of links.

Every picture is the app doing the thing the page claims, on a project from the
examples repository that anybody can clone — including the nine repositories
`git-scenarios` makes, each stuck in a state worth looking at, which the script
clones and makes for itself. The one exception is `pullrequest`, and it is one
because a pull request lives on a forge and the examples repository has none: it
photographs this app's own repository, which is public, and defaults to a pull
request the repository owner opened rather than somebody else's work.

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
`dracula`, `dracula-light`, `gray`, `gray-light` — and defaults to `abydos`. It is
checked against that list before the app is launched, because the app treats an
unrecognised value as "follow the system": `--theme daylight` on a dark Mac quietly
photographs dusk instead of failing.

`themes.html` names the palettes — `abydos`, `abydos-light`, `dusk`, `daylight`,
`dracula`, `dracula-light`, `gray`, `gray-light` — and the script maps between the
two spellings. Four themes with a light and a dark each is eight pictures; the four
values that mean "follow the system" are not photographed.

The captures are reproducible on purpose: the window is given a size, the panel
is given a height, and the examples are cloned — not copied, since the titlebar
says which branch — into a temporary directory first. The clone's `origin` is set
to wherever the examples checkout points, so the rows the palette offers name
GitHub rather than a directory in `/tmp`.

Six shots want a working environment rather than just the app. `debugger` needs
Delve and a Go toolchain; `terminal` needs `tmux`, and will attach to a session
that is already running, so check what came out before committing it. `scad`
needs OpenSCAD and `cadova` a Swift toolchain and the network once — it is also
the slow one, at about three and a half minutes, since every shot gets a fresh
clone and compiles a C++ geometry kernel from cold. `pullrequest` needs `gh`
logged in to github.com and the network, and `sops` needs `sops` and `age`, for
which it makes a key of its own that goes with the temporary directory. `diagram`
needs nothing: it is Mermaid, which is inside the app.

`sessionlist` synthesises the sessions it counts rather than waiting for real
ones, so its rows say they have announced nothing yet — which is what the app
says about a session it has heard from and which has said nothing. A real one
carries its last line. The caption on that picture says so.

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
