# abydos-docs

The website for [Abydos](https://philipparndt.github.io/abydos-docs/) — a
terminal-first IDE for AI and cloud development, on macOS.

A repository of its own because the program's is private, and GitHub Pages will
not serve a site from a private repository without a paid plan.

## What is in it

    src/layout.html        the shell every page is poured into
    src/styles/*.css       concatenated, in name order, into one stylesheet
    src/partials/          the icon and the footer, included by name
    src/pages/*.html       one file per page, with its title in front matter
    Scripts/build.py       assembles src/ into dist/
    Scripts/screenshots.sh drives the app and photographs it into images/
    images/                the pictures, committed — they need a Mac to make
    Makefile               the four commands below

`dist/` is the site and is not committed: the workflow builds it on every push.

## Changing it

```sh
make            # assemble src/ into dist/
make serve      # ...and serve it on http://localhost:8000
make help       # everything else
```

There is a build now because there are two pages. One page justified one file;
two pages sharing a palette, a header and a footer by having been copied are two
pages that drift, and the drift is always the second one. Nothing is installed
to run it — `python3` is on macOS and on the runner, and there is no lockfile,
no `node_modules` and nothing to keep current.

The templating is three things and deliberately no more:

- `{{ include partials/footer.html }}` splices a file in, recursively.
- `{{ title }}` substitutes a value from the page's front matter — the `---`
  fenced block at the top of each file in `src/pages/`.
- `<img src="images/x.png">` is given `width` and `height` read out of the PNG.

That last one is the reason the build is a program rather than a `cat`.
Intrinsic dimensions stop the page from jumping as the pictures load, and a
number typed by hand beside a file that a script regenerates is a number that is
eventually wrong — as the old page's were, which is how this was noticed. It
also means a page that names a picture that is not there fails the build instead
of shipping a broken image.

## The pictures

```sh
make screenshots        # the six the pages use, in the app's own theme
make theme-shots        # one scene in each palette, for themes.html
make shots              # both
```

Every picture is the app doing the thing the page claims, on a project from the
examples repository that anybody can clone. Nothing is staged and nothing is a
mockup.

It needs both other checkouts beside this one:

    git clone https://github.com/philipparndt/abydos.git           ../abydos
    git clone https://github.com/philipparndt/abydos-examples.git  ../abydos-examples

The examples are public; the app is not yet, so taking the pictures needs
access to it. A clone made before the rename still sits in a folder called the
old thing, so each is looked for under both names and the new one wins:

    ABYDOS=../abydos             or ../ideai
    EXAMPLES=../abydos-examples  or ../ideai-examples

Both are overridable, as are `OUT`, `SIZE`, `THEME` and which shots to take:

```sh
Scripts/screenshots.sh site debugger      # just that one
THEME=light Scripts/screenshots.sh site   # the pages, in daylight
```

`THEME` takes what Settings stores — `abydos`, `abydos-light`, `dark`, `light`,
`dracula`, `dracula-light` — and defaults to `abydos`, so the pictures do not
depend on whichever theme the machine taking them happens to be set to. It is
checked against that list before the app is launched, because the app treats an
unrecognised value as "follow the system": `--theme daylight` on a dark Mac
quietly photographs dusk instead of failing, which cost an afternoon once.

`themes.html` names the palettes — `abydos`, `abydos-light`, `dusk`, `daylight`,
`dracula`, `dracula-light` — and the script maps between the two spellings. The
stored value is one string holding both halves of what is asked as two questions
in Settings: which theme, and how light. Three themes with a light and a dark
each is six pictures; the three values that mean "follow the system" are not
photographed, because they are not palettes.

The page calls `dracula-light` **Alucard**, since that is upstream's own name
for it, but the file keeps the setting's name. The mapping stays in one
direction that way: what the app stores is what the picture is called.

The captures are reproducible on purpose: the window is given a size, the panel
is given a height, and the examples are cloned into a temporary directory first,
because the window frame, the split position and which files were last open are
all remembered per machine.

A clone rather than a copy, since the titlebar says which project *and* which
branch: a copied folder has no branch, so every capsule came out with half of
itself missing. The clone's `origin` is set to wherever the examples checkout
points, so the rows the palette offers name GitHub rather than a directory
in `/tmp` that is deleted when the script exits.

Two of them want a working environment rather than just the app: `debugger`
needs Delve and a Go toolchain, and `terminal` needs `tmux` — and it will attach
to a session that is already running, so a stale one gets photographed. Check
what came out before committing it.

`palette` photographs a popover, which is a window of its own and so is nowhere
in the picture of the window it is over. The app writes it out beside the
capture and the script moves it onto the name that was asked for, the same way
`breakpoint` handles its sheet.

`../abydos/Scripts/screenshots.sh` does the same job and predates this one; its
output was copied here by hand. This is now the only copy the site depends on,
so that one can go.

## Publishing

`.github/workflows/pages.yml` runs `make build` and uploads `dist/`. Pull
requests build without publishing; `main` builds and deploys; `workflow_dispatch`
re-runs a deployment that stalled.

Pages' own branch pipeline used to do this, until it started creating the
artifact and then sitting at `deployment_in_progress` until the ten-minute
default gave up. A workflow of our own is the same steps written down, which
means they can be re-run, and read when they fail.
