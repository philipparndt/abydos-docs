#!/bin/bash
# Photographs Abydos for this site.
#
# The pictures are the claim. Every one is the app doing the thing the page
# says it does, on a project from the examples repository that anybody can
# clone — nothing is staged, nothing is drawn by hand, and nothing is a mockup.
#
# Reproducible on purpose. The window is given a size, the panel is given a
# height, and the examples are cloned into a temporary directory first, because
# the window frame, the split position and which files were last open are all
# remembered per machine. A screenshot that depends on those is a screenshot
# that looks different for everybody who takes it.
#
# The theme is given too, and defaults to the app's own. Left to itself the app
# follows the system, so the same command run after dark produced a different
# picture — which is a thing you find out only by looking at the diff.
#
#   Scripts/screenshots.sh                 # both sets
#   Scripts/screenshots.sh site            # the eight the pages use
#   Scripts/screenshots.sh site debugger   # just that one
#   Scripts/screenshots.sh themes          # one scene in each palette
#   THEME=light Scripts/screenshots.sh site
#   ABYDOS=~/dev/abydos EXAMPLES=~/dev/abydos-examples Scripts/screenshots.sh
set -euo pipefail

cd "$(dirname "$0")/.."
DOCS="$(pwd)"

# Both repositories are called abydos now, but a clone made before the rename
# still sits in a folder called the old thing — and renaming a folder is the
# kind of chore that waits. So the new name is tried first and the old one is
# the fallback, which works on either side of it without an edit here.
find_checkout() {
	local name="$1" repo="$2"; shift 2
	for candidate in "$@"; do
		if [ -d "$candidate" ]; then (cd "$candidate" && pwd); return 0; fi
	done
	# Where to get it, rather than only that it is missing: the answer to "no
	# examples checkout" is a clone, and it saves looking the name up.
	echo "no $name checkout — looked in $*" >&2
	echo "  git clone https://github.com/philipparndt/$repo.git ${1}" >&2
	return 1
}

ABYDOS="${ABYDOS:-$(find_checkout app abydos ../abydos ../ideai)}"
EXAMPLES="${EXAMPLES:-$(find_checkout examples abydos-examples ../abydos-examples ../ideai-examples)}"
OUT="${OUT:-$DOCS/images}"
SIZE="${SIZE:-1280x800}"
THEME="${THEME:-dark}"
# The binary, and the checkout, which are two things.
#
# Almost always the first is inside the second and this is one variable's worth
# of arithmetic. They come apart for a long sweep: `all` takes over an hour, an
# app rebuilt under it produces a set that disagrees with itself, and the way to
# stop that is to copy the bundle somewhere of its own and point `APP` at the
# copy. `ABYDOS` still has to be the repository, because the pull request shot
# clones it — which is how this was found, an hour into a sweep, with `fatal:
# repository '/private/tmp/abydos-shot' does not exist`.
APP="${APP:-$ABYDOS/build/Abydos.app/Contents/MacOS/Abydos}"

# The eight palettes — four themes with a light and a dark each — minus the four
# values that mean "follow the system", which is not a palette but a deferral and
# resolves to one of these.
#
# `setting:directory`. The first is what Settings stores and what `--theme`
# answers to; the second is the folder the pictures land in, spelled
# `<family>-<lightness>` so that the switcher on the site can compose the path
# to a picture from the two answers it already holds. The page's own names for
# these — Dusk, Daylight, Alucard — are editorial and appear nowhere a program
# has to agree about. `--theme` takes what Settings stores
# — abydos, abydos-light, dark, light, dracula, dracula-light — while Theme.swift
# calls the palettes abydos, abydos-light, dusk, daylight, dracula and
# dracula-light, and the page uses those. Worth spelling out, because an
# unrecognised value is not an error: the app falls back to following the system,
# so `--theme daylight` on a dark Mac quietly photographs dusk. Which is how this
# list came to be written down at all.
#
# Only Blue's two disagree, which is the leftover from when the theme was one
# list rather than the pair it is now — every palette added since has been stored
# under the name it is called by.
#
# The page calls dracula-light Alucard, because that is what upstream calls it.
# The file is named for the setting rather than the heading, so the mapping stays
# in one direction: what the app stores is what the picture is called.
THEMES=(
	abydos:abydos-dark   abydos-light:abydos-light
	dark:blue-dark       light:blue-light
	dracula:dracula-dark dracula-light:dracula-light
	gray:gray-dark       gray-light:gray-light
)

usage() { sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

case "${1:-}" in
	-h|--help) usage 0 ;;
	site|themes|all) SET="$1"; shift ;;
	"") SET=all ;;
	*) echo "unknown set: $1" >&2; usage 1 >&2 ;;
esac
ONLY=("$@")

# Checked here rather than left to the app, for the reason above: an unknown
# theme produces a picture instead of an error, and the picture looks fine.
case " ${THEMES[*]} " in
	*" $THEME:"*) ;;
	*) echo "unknown theme: $THEME — one of ${THEMES[*]%%:*}" >&2; exit 1 ;;
esac

# A debug build, because it is the one `make build` leaves in build/ and the
# pictures do not care. Built rather than demanded: forgetting is the common
# case and the fix is one command away.
if [ ! -x "$APP" ]; then
	echo "==> No app at $APP — building it"
	make -C "$ABYDOS" --no-print-directory build CONFIG=debug
fi
test -x "$APP" || { echo "still no $APP" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Where the examples came from, so a clone of them can be pointed back at it.
# Without this the origin is a path in /tmp, and a palette that offers "Open
# Repository on GitHub" would be offering it about a directory that is deleted
# when this script exits.
ORIGIN="$(git -C "$EXAMPLES" remote get-url origin 2>/dev/null || true)"

# A clone, not the original and no longer a copy.
#
# Not the original because opening a project writes a session file into it, and
# because a subdirectory of a git repository resolves to the repository root —
# so the shots would carry whatever was last open in the examples checkout.
#
# A clone rather than `cp -R` because the titlebar now says which project *and*
# which branch, and a copied folder has no branch to say: every capsule came out
# with half of itself missing. It is also faster and cleaner — the examples
# working tree is a hundred megabytes of build output and the history is under
# one, so a clone is both cheaper to make and already free of the `build/` and
# `target/` directories that used to be deleted by hand afterwards.
#
# One clone per shot rather than one per run, because two shots of the same
# example want different state: the breakpoint one writes a session file, and
# the debugger one must not find it.
prepare() {
	local example="$1" name="$2"
	rm -rf "${WORK:?}/$name"
	git clone --quiet "$EXAMPLES" "$WORK/$name"
	# An `if` rather than `[ … ] && …`, which under `set -e` fails the whole run
	# on the day somebody's examples checkout has no remote.
	if [ -n "$ORIGIN" ]; then
		git -C "$WORK/$name" remote set-url origin "$ORIGIN"
	fi
	(cd "$WORK/$name/$example" && pwd -P)
}

wanted() {
	[ ${#ONLY[@]} -eq 0 ] && return 0
	local name="$1"
	for one in "${ONLY[@]}"; do [ "$one" = "$name" ] && return 0; done
	return 1
}

# One capture. `path` is where it lands; everything after it is handed to the app.
#
# `--trust` on every one of them. A project is not trusted until somebody says
# so, and an untrusted one wears a strip across the top saying that nothing in
# it runs — which is correct, and is a sentence about a directory this script
# made in /tmp thirty seconds ago rather than about anything a page here claims.
# Every scene below is of somebody working in their own project, so the runs
# start where a person would be after pressing Trust. A driven run does not
# write that down, so it reaches nobody's real list.
#
# **Which is why no capture is earlier than ten seconds.** Trusting says so in
# a toast, and a toast lives eight of them — so a shot taken at four seconds
# came out with `Trusted go-service` sitting in the corner of it. The floor is
# here rather than in each scene, because the next scene written would be
# written at whatever delay its own content needs and would find this out
# again.
shoot() {
	local path="$1" theme="$2"; shift 2
	printf '  %-24s ' "${path#"$DOCS"/}"
	"$APP" --window-size "$SIZE" --theme "$theme" --trust --screenshot "$path" "$@" >/dev/null 2>&1 || true
	if [ -f "$path" ]; then
		printf '%s\n' "$(du -h "$path" | cut -f1)"
	else
		printf 'FAILED\n'
		return 1
	fi
}

# The editor and the navigator, on a project small enough to take in.
# The devcontainer, out of a clone.
#
# go-service names one, and every picture of it therefore carries either a
# question in the corner about starting a container or a strip saying the server
# was not started — in scenes that are about the editor, the debugger and the
# terminal. What a devcontainer does is a row in the table on the front page and
# has nothing to prove in a picture of a breakpoint. The clone is thrown away
# afterwards, and the project is then the one these scenes were built on.
without_devcontainer() {
	rm -rf "$1/.devcontainer"
}

shot_editor() {
	local theme="$1" path="$2"
	local go; go="$(prepare go-service go-service)"
	without_devcontainer "$go"
	shoot "$path" "$theme" --open "$go" --file "$go/main.go" --expand --panel-height 0 --delay 10
}


# The claim that matters: stopped on a breakpoint. Started with the terminal
# filling the window, because that is both the state people work in and the one
# the debugger has to recover from.
#
# `--file`, and it has to be there: both `--breakpoint` and `--debug-line` act on
# whatever file is open, and a project with no session file open has none — so
# without this the app came up on "Select a file to open", the two flags did
# nothing each, and the picture was of an idle window. It said so, too: no
# breakpoint in the gutter and no colour in the seam, which is exactly what an
# app that is not running looks like.
#
# The path is the resolved one, because `prepare` hands one back and the
# debugger names the file by what Delve reports, which is also resolved. When
# the two spellings differed this left two tabs for the one file.
shot_debugger() {
	local theme="$1" path="$2"
	local go; go="$(prepare go-service go-service)"
	without_devcontainer "$go"
	shoot "$path" "$theme" --open "$go" --file "$go/main.go" \
		--maximize-terminal --breakpoint 25 --debug-line 18 --delay 40
}

# A terminal that is a terminal: tmux's own windows as the panel's tabs, with
# something in them. The first version photographed one empty window, which
# proves the tabs exist and nothing about what they are for — so a second window
# is opened from inside the terminal, the way anybody would, and a real build
# runs in it.
#
# Typed at the shell rather than with `--type`, which types wherever the keyboard
# is — and that is the editor, so the first attempt photographed two tmux
# commands inserted into main.go.
#
# The session is named after the project and outlives the app, so a second run
# found the window from the first and made another beside it: three tabs saying
# "build". Killed first, so the picture is of one run.
shot_terminal() {
	local theme="$1" path="$2"
	local go; go="$(prepare go-service go-service)"
	without_devcontainer "$go"
	tmux kill-session -t "$(basename "$go")" 2>/dev/null || true
	shoot "$path" "$theme" --open "$go" --file "$go/main.go" --terminal --panel-height 336 \
		--run "tmux new-window -n build -c '$go'" \
		--send-bytes 'go build -v -o /dev/null ./... && go vet ./... && echo "  build ok"\r' \
		--delay 16
}

# Java, because "a language is supported" is a claim about a build file as much
# as about source: the outline over a POM comes from Maven's own structure.
shot_java() {
	local theme="$1" path="$2"
	local java; java="$(prepare java/maven-service maven-service)"
	shoot "$path" "$theme" --open "$java" \
		--file "$java/src/main/java/com/example/api/Server.java" --expand --panel-height 0 --delay 10
}

# What a breakpoint can be told to do.
#
# **The values are flags, not a session file.** They used to be written into the
# project's `.abydos/session.json`, which is where anybody's would come from —
# and a driven run does not read one. `LaunchStore` says why: "a driven run
# shows what it was given and nothing else", so that a capture cannot come out
# holding the tabs and terminals somebody left open in a project of their own.
# The shot was older than that rule and had been quietly photographing an empty
# window ever since.
#
# `--file` for the same reason: `--bp-edit` acts on whatever is open, and
# without a session there is nothing open to act on.
#
# The three fields are separated by tabs because each of them is an expression:
# `a || b` and `f(x, y)` are what they look like, and a tab is the one character
# none of them contains.
shot_breakpoint() {
	local theme="$1" path="$2"
	local bp; bp="$(prepare go-service bp-options)"
	without_devcontainer "$bp"
	# The sheet is a window of its own, so it lands beside the capture under a
	# name of its own, and is moved onto the one that was asked for.
	local sheet="${path%.png}-sheet.png"
	rm -f "$sheet"
	shoot "$path" "$theme" --open "$bp" --file "$bp/main.go" --panel-height 160 \
		--breakpoint 25 \
		--bp-condition "$(printf 'stage == "local" && len(os.Args) > 1\t> 5\tstage is {stage} after {time.Since(started)}')" \
		--bp-edit 25 --delay 12
	[ -f "$sheet" ] && mv "$sheet" "$path"
	return 0
}

# A shape and the file that describes it, which is the whole claim of the 3D
# page. The render is OpenSCAD's own, run on the file as it is on disk — so a
# picture of this is a picture of OpenSCAD agreeing, and a broken one would show
# an empty pane rather than a cube, which is the behaviour 0484 settled.
#
# `bracket.scad` rather than `dollhouse.scad`: the small one fits beside its own
# source at this window size, and the point being made is that both halves are
# there, not how large a model can be.
shot_scad() {
	local theme="$1" path="$2"
	local scad; scad="$(prepare openscad openscad)"
	shoot "$path" "$theme" --open "$scad" --file "$scad/adapter-feder.scad" \
		--preview-mode split --panel-height 0 --delay 14
}

# Cadova, where the model is a *program* and not a file: there is no shape until
# the package has been built and run, so this delay is a cold `swift build` and
# not a render. About 90 seconds from a fresh clone — 23 s to resolve seven
# packages and 65 s to compile a C++ geometry kernel — and `prepare` hands out a
# fresh clone every time on purpose, so it is cold every time.
#
# The network is needed once, for the resolve. A machine without it photographs
# the pane saying what the build said, which is honest and is not the picture
# the page wants.
#
# `coaster` rather than `HexKeyHolder`, which this was first. The hex key holder
# is the model from Cadova's own README and is the better *model*; it is also
# eighty-one lines that open on twenty-six of comment, so the picture was a
# screenful of prose with `import Cadova` at the top and the shape beside it. The
# coaster is twenty-eight lines whole — the import, four constants and the three
# operations that make it — so the claim the page makes, that the shape is beside
# the code describing it, is a thing somebody can check in the picture rather
# than take on trust.
# The slow one, and the reason a full sweep is measured in hours rather than
# minutes: the model is built by compiling a C++ geometry kernel, and a fresh
# clone compiles it from cold.
#
# **Prepared once for the whole run**, unlike every other scene. `prepare` wipes
# and re-clones, which is right where two shots of the same example want
# different state — the breakpoint one writes a session file and the debugger one
# must not find it — and is three and a half minutes of compiler for nothing when
# the same picture is being taken in eight palettes. The second palette onwards
# opens a package that is already built, and the delay comes down with it.
shot_cadova() {
	local theme="$1" path="$2" wait=260
	local pkg="$WORK/cadova/cadova-models"
	if [ -d "$pkg" ]; then
		# Warm rather than instant: SwiftPM still relinks and the model is still
		# run to produce the mesh. The picture is checked rather than assumed.
		pkg="$(cd "$pkg" && pwd -P)"
		wait=140
	else
		pkg="$(prepare cadova-models cadova)"
	fi
	# The target has to be in the clone, and a clone has only what is committed.
	# Said here rather than found in the picture: what an absent target produces
	# is a window with a source file and an empty pane beside it, which looks
	# like a render that failed rather than like a target that is not there.
	if [ ! -d "$pkg/Sources/high-speed-curve" ]; then
		echo "no high-speed-curve target in the examples clone —" >&2
		echo "  commit cadova-models/Sources/high-speed-curve and Package.swift" >&2
		echo "  in $EXAMPLES, or this shot has nothing to render" >&2
		return 1
	fi
	shoot "$path" "$theme" --open "$pkg" \
		--file "$pkg/Sources/high-speed-curve/main.swift" \
		--preview-mode split --panel-height 0 --delay "$wait"
}


# A diagram beside the text that makes it. Mermaid rather than PlantUML, and
# not because it is the better tool: PlantUML is a JVM and wants a container or
# an install, and the machine these are taken on has no container runtime that
# will start. Mermaid is 3.6 MB of JavaScript inside the app, so this shot needs
# nothing that the app does not already carry — which also makes it the one
# diagram anybody can reproduce.
shot_diagram() {
	local theme="$1" path="$2"
	local mmd; mmd="$(prepare mermaid mermaid)"
	shoot "$path" "$theme" --open "$mmd" --file "$mmd/project.mmd" \
		--preview-mode split --panel-height 0 --delay 10
}

# The command palette, which is what the titlebar became: one field over
# everything the app can be asked to do.
#
# `>` and nothing after it, because the list is the claim. A word typed after it
# would photograph the filter working, which is a smaller thing to say than what
# is in there — the project's own handoffs first, then every command the menus
# offer, each with the menu it lives in and the key it already answers to.
#
# The clone is what makes the top of that list exist: the three GitHub rows are
# offered because this is a checkout with a remote, and are absent from a folder
# that only looks like one.
#
# A popover is a window of its own, so it is nowhere in the picture of the
# window it is over. It lands beside the capture as a child and is moved onto
# the name that was asked for, the way the breakpoint sheet is.
shot_palette() {
	local theme="$1" path="$2"
	local go; go="$(prepare go-service palette)"
	local popover="${path%.png}-child0.png"
	rm -f "$popover"
	shoot "$path" "$theme" --open "$go" --file "$go/main.go" --panel-height 0 \
		--switcher '>' --delay 10
	[ -f "$popover" ] && mv "$popover" "$path"
	return 0
}

# ── Git ─────────────────────────────────────────────────────────────────────
#
# Where this file used to say there was no git shot, the objection was right and
# had no answer at the time: a fresh clone has nothing uncommitted in it, and
# photographing *this* repository would be photographing whatever was lying
# around that day. `git-scenarios` is the answer. It is nine repositories, each
# stuck in a state worth looking at, made by a script the examples repository
# commits — so every picture below is a state anybody reproduces with
# `make scenarios` in their own checkout.
#
# Cloned and made once for the whole run, because the `large` scenario is three
# hundred commits. The directory is the marker rather than a variable: a
# function used as `$(scenarios x)` runs in a subshell and cannot remember
# anything.
scenarios() {
	local out="$WORK/scenarios/git-scenarios/out"
	if [ ! -d "$out" ]; then
		git clone --quiet "$EXAMPLES" "$WORK/scenarios" >&2
		( cd "$WORK/scenarios" && ./git-scenarios/make-scenarios.sh >/dev/null ) >&2
	fi
	printf '%s' "$out/$1"
}

# The refs tree: one list from the top edge of the pane, with the repository as
# its first row.
#
# `branches` on its own is five branches and nothing else — no remote, no tags,
# a clean working copy — so four of the sections the tree draws would be empty
# and the row that says how far you are from the remote would have nothing to
# say. What is added here is what any repository being worked in has: a remote
# with some branches published and some not, a tag, one commit that has not been
# pushed, and work in progress.
shot_git() {
	local theme="$1" path="$2"
	local repo; repo="$(scenarios branches)"
	if [ ! -d "$WORK/git-remote.git" ]; then
		git init -q --bare "$WORK/git-remote.git"
		git -C "$repo" remote add origin "$WORK/git-remote.git"
		git -C "$repo" push -q -u origin main
		# With `-u`, because a branch pushed without an upstream is still an
		# unpublished branch as far as the row is concerned — and a tree where
		# every branch says the same thing shows nothing about the vocabulary.
		git -C "$repo" push -q -u origin feature/lights fix/timeout
		git -C "$repo" tag -a v1.2.0 -m "Release 1.2.0"
		git -C "$repo" push -q origin v1.2.0
		printf 'one more line\n' >> "$repo/README.md"
		git -C "$repo" commit -qm "A commit the remote has not seen" README.md
		printf 'target: 21.5\n' > "$repo/thermostat.yaml"
		printf 'and this is still being written\n' >> "$repo/README.md"
	fi
	shoot "$path" "$theme" --open "$repo" --file "$repo/README.md" \
		--sidebar branches --sidebar-width 330 --panel-height 0 --delay 10
}

# The log page, on a history with something in it to draw: five commits, a tag,
# a topic branch and the merge that brought it back.
shot_log() {
	local theme="$1" path="$2"
	local repo; repo="$(scenarios history)"
	shoot "$path" "$theme" --open "$repo" --panel-height 0 --log-page "settle:2,file:0" --delay 10
}

# The commit page, on the scenario that is staged, unstaged and untracked at
# once — which is the state the two lists exist to tell apart.
shot_commit() {
	local theme="$1" path="$2"
	local repo; repo="$(scenarios uncommitted)"
	shoot "$path" "$theme" --open "$repo" --panel-height 0 \
		--commit-page "settle:1,select:README.md" --delay 10
}

# A merge stopped in the middle, which is the one state where the strip above
# the tree is the whole of what the pane is for.
shot_conflict() {
	local theme="$1" path="$2"
	local repo; repo="$(scenarios conflict)"
	# A second conflicted file, because the strip's job is a list and a count:
	# one row can be read as "the pane found the file", where two rows and
	# `1 of 2 resolved` is the thing it actually does.
	if [ ! -f "$repo/limits.yaml" ]; then
		git -C "$repo" merge --abort
		git -C "$repo" checkout -q theirs
		printf 'timeout: 30\n' > "$repo/limits.yaml"
		git -C "$repo" add limits.yaml
		git -C "$repo" commit -qm "Wait half a minute"
		git -C "$repo" checkout -q main
		printf 'timeout: 10\n' > "$repo/limits.yaml"
		git -C "$repo" add limits.yaml
		git -C "$repo" commit -qm "Wait ten seconds"
		git -C "$repo" merge theirs >/dev/null 2>&1 || true
	fi
	shoot "$path" "$theme" --open "$repo" --file "$repo/settings.yaml" \
		--sidebar branches --sidebar-width 330 --panel-height 0 --delay 10
}

# A pull request, which is the one picture on this site that is not of the
# examples repository — because a pull request is on a forge and the examples
# repository has none. It is this app's own, which is public and can be cloned,
# and `gh` has to be logged in for it to come out at all.
#
# A local clone rather than the checkout beside this one: opening a project
# writes a session file into it, and that checkout is somebody's working tree.
# `origin` is then the real one, because `gh` resolves the repository from it.
# `PR=` to photograph another one. The default is one of this repository
# owner's own, deliberately: an open pull request is usually somebody else's
# work, and their name and their branch would be on a page on a website without
# their having been asked. #19 is also the one that added this page.
shot_pullrequest() {
	local theme="$1" path="$2" number="${PR:-19}"
	if [ ! -d "$WORK/abydos" ]; then
		git clone --quiet "$ABYDOS" "$WORK/abydos" >&2
		git -C "$WORK/abydos" remote set-url origin https://github.com/philipparndt/abydos.git
	fi
	shoot "$path" "$theme" --open "$WORK/abydos" --panel-height 0 \
		--pull-requests "settle:2,number:$number,settle:6,pick:2" --delay 22
}

# The pill on the terminal panel's title bar, counting what is working and what
# is waiting. The sessions are synthesised rather than waited for: a real one
# would have to be started, would say whatever it was doing that minute, and
# would put somebody's own work in a picture on a website.
#
# Not go-service, for these three and the two below: it names a devcontainer,
# and the question about activating one is a toast in the corner that has
# nothing to do with what any of them are about. maven-service names none.
shot_sessions() {
	local theme="$1" path="$2"
	local project; project="$(prepare java/maven-service sessions)"
	# The session is killed first, the way the terminal shot kills its own.
	#
	# tmux outlives the app, and `prepare` gives each palette a fresh clone at a
	# new path — so the pane from the palette before is a shell sitting in a
	# directory that has since been deleted, and what it prints is `fatal: Unable
	# to read current working directory`, once per palette, stacking up. By the
	# fifth the picture was a wall of red about nothing.
	tmux kill-session -t "$(basename "$project")" 2>/dev/null || true
	shoot "$path" "$theme" --open "$project" --file "$project/pom.xml" \
		--terminal --panel-height 288 --send-bytes 'git status -sb\r' \
		--claude-running "1a2b3c4d-0001-4000-8000-000000000001:working:sub2" \
		--claude-running "1a2b3c4d-0002-4000-8000-000000000002:needs" \
		--claude-running "1a2b3c4d-0003-4000-8000-000000000003:working" \
		--claude-running "1a2b3c4d-0004-4000-8000-000000000004:done" \
		--delay 10
}

# The same register on ⇧⌘A, which is a panel of its own and so lands beside the
# capture the way the palette and the breakpoint sheet do.
shot_sessionlist() {
	local theme="$1" path="$2"
	local project; project="$(prepare java/maven-service sessionlist)"
	local popover="${path%.png}-child0.png"
	rm -f "$popover"
	shoot "$path" "$theme" --open "$project" --panel-height 0 \
		--claude-running "1a2b3c4d-0001-4000-8000-000000000001:working:sub2" \
		--claude-running "1a2b3c4d-0002-4000-8000-000000000002:needs" \
		--claude-running "1a2b3c4d-0003-4000-8000-000000000003:working" \
		--claude-running "1a2b3c4d-0004-4000-8000-000000000004:done" \
		--running-sessions-palette 6 --delay 10
	[ -f "$popover" ] && mv "$popover" "$path"
	return 0
}

# A dotenv file, which opens with its values already unreadable. The file is
# written into the clone rather than committed to the examples repository,
# which is where anybody's would come from too — and it is untracked and
# unignored on purpose, because that is what puts the notice beside the lock.
#
# The values are invented, and shaped so that no scanner can mistake them for
# real ones. The first attempt used a plausible `sk_live_` followed by
# twenty-four alphanumerics, which is exactly Stripe's own pattern — GitHub's
# push protection refused the commit, and it was right to: a key-shaped string
# in a public repository is a key until somebody proves otherwise, and nobody
# reading a diff is going to run that test. Underscores break the pattern and
# say what the value is at the same time.
shot_secrets() {
	local theme="$1" path="$2"
	local go; go="$(prepare java/maven-service secrets)"
	cat > "$go/.env" <<'ENV'
# The service reads these at start. Nothing here is real.
APP_ENV=staging
LOG_LEVEL=debug
DATABASE_URL=postgres://thermostat:8Jq2wV6nR4xP@db.staging.internal:5432/readings
STRIPE_SECRET_KEY=sk_live_NOT_A_KEY_ONLY_A_PICTURE
export SENTRY_DSN=https://not-a-dsn@only.a.picture/6318
SMTP_PASSWORD=
# An empty value is not a secret, so it is left as it is.
ENV
	shoot "$path" "$theme" --open "$go" --file "$go/.env" --panel-height 0 --delay 10
}

# A SOPS file, decrypted in place from the chip beside the lock. The key is made
# for the run and thrown away with the temporary directory, and the values are
# invented — which is the whole point of photographing this one revealed.
shot_sops() {
	local theme="$1" path="$2"
	local go; go="$(prepare java/maven-service sops)"
	local keys="$WORK/age.txt"
	# Once per run, not once per palette: `age-keygen -o` refuses a file that is
	# already there, and under `set -e` the second palette would end the sweep.
	[ -f "$keys" ] || age-keygen -o "$keys" >/dev/null 2>&1
	local recipient; recipient="$(grep -o 'age1[0-9a-z]*' "$keys" | head -1)"
	cat > "$go/.sops.yaml" <<RULES
creation_rules:
  - path_regex: secrets/.*\.yaml\$
    age: $recipient
RULES
	mkdir -p "$go/secrets"
	cat > "$go/secrets/dev.yaml" <<'VALUES'
database:
  user: thermostat
  password: 8Jq2wV6nR4xP
api:
  stripe: sk_live_NOT_A_KEY_ONLY_A_PICTURE
  sentry: https://not-a-dsn@only.a.picture/6318
VALUES
	( cd "$go" && SOPS_AGE_KEY_FILE="$keys" sops --encrypt --in-place secrets/dev.yaml )
	SOPS_AGE_KEY_FILE="$keys" \
		shoot "$path" "$theme" --open "$go" --file "$go/secrets/dev.yaml" \
			--panel-height 0 --sops "settle:1,decrypt" --delay 10
}

SITE_SHOTS=(
	editor debugger terminal java breakpoint palette scad cadova diagram
	git log commit conflict pullrequest sessions sessionlist secrets sops
)

# One palette's worth. The pictures live under the palette they were taken in,
# because the site wears the app's themes and its screenshots follow: a page in
# daylight showing eight windows at midnight is the one thing the switcher must
# not do.
one_palette() {
	local setting="$1" palette="$2"
	local out="$DOCS/images/$palette"
	mkdir -p "$out"
	echo "==> $palette ($SIZE) → images/$palette"
	for name in "${SITE_SHOTS[@]}"; do
		wanted "$name" || continue
		"shot_$name" "$setting" "$out/$name.png"
	done
}

case "$SET" in
	site)
		# The one palette named by THEME, which defaults to the app's own
		# default family after dark.
		for pair in "${THEMES[@]}"; do
			# `if` rather than `&&`: under `set -e` a test that fails is the
			# last command in the loop body, and the script ends there.
			if [ "${pair%%:*}" = "$THEME" ]; then
				one_palette "$THEME" "${pair#*:}"
			fi
		done
		;;
	themes)
		# The gallery under each palette's own heading, which is the editor shot
		# and nothing else — the same picture the site shows when it is wearing
		# that palette, rather than a second copy of it.
		ONLY=(editor)
		for pair in "${THEMES[@]}"; do
			one_palette "${pair%%:*}" "${pair#*:}"
		done
		;;
	all)
		for pair in "${THEMES[@]}"; do
			one_palette "${pair%%:*}" "${pair#*:}"
		done
		;;
esac

echo '==> Done. Scripts/thumbs.sh next, then Scripts/webp.sh.' 
