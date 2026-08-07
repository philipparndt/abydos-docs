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
#   Scripts/screenshots.sh site            # the six the pages use
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
SIZE="${SIZE:-1600x1000}"
THEME="${THEME:-abydos}"
APP="$ABYDOS/build/Abydos.app/Contents/MacOS/Abydos"

# The four palettes, minus the two values that mean "follow the system" — which
# is not a palette but a deferral, and resolves to one of these.
#
# `setting:palette`, because those are two different names for the same thing
# and the app answers to only one of them. `--theme` takes what Settings stores
# — abydos, abydos-light, dark, light — while Theme.swift calls the palettes
# abydos, abydos-light, dusk and daylight, and the page uses those. Worth
# spelling out, because an unrecognised value is not an error: the app falls
# back to following the system, so `--theme daylight` on a dark Mac quietly
# photographs dusk. Which is how this list came to be written down at all.
#
# Two of the four now agree on their name, which is the settle-down after the
# theme became two questions rather than one list: the stored string is the pair
# — which palette, and how light — so the warm one in daylight had to be called
# something, and it is called what it is.
THEMES=(abydos:abydos abydos-light:abydos-light dark:dusk light:daylight)

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

mkdir -p "$OUT" "$OUT/themes"
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
shoot() {
	local path="$1" theme="$2"; shift 2
	printf '  %-24s ' "${path#"$DOCS"/}"
	"$APP" --window-size "$SIZE" --theme "$theme" --screenshot "$path" "$@" >/dev/null 2>&1 || true
	if [ -f "$path" ]; then
		printf '%s\n' "$(du -h "$path" | cut -f1)"
	else
		printf 'FAILED\n'
		return 1
	fi
}

# The editor and the navigator, on a project small enough to take in.
shot_editor() {
	local theme="$1" path="$2"
	local go; go="$(prepare go-service go-service)"
	shoot "$path" "$theme" --open "$go" --file "$go/main.go" --expand --panel-height 0 --delay 4
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
	tmux kill-session -t "$(basename "$go")" 2>/dev/null || true
	shoot "$path" "$theme" --open "$go" --file "$go/main.go" --terminal --panel-height 420 \
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
		--file "$java/src/main/java/com/example/api/Server.java" --expand --panel-height 0 --delay 5
}

# What a breakpoint can be told to do. The values come from a session file,
# which is also where anybody's would come from.
shot_breakpoint() {
	local theme="$1" path="$2"
	local bp; bp="$(prepare go-service bp-options)"
	mkdir -p "$bp/.abydos"
	# Written by python rather than a heredoc plus sed: the path holds slashes,
	# and the quoting around `sed -i ''` on macOS is one mistake away from an
	# empty expression, which is what happened.
	python3 - "$bp" <<-'PYTHON'
		import json, sys
		root = sys.argv[1]
		main = f"{root}/main.go"
		json.dump({
			"files": [{"path": main, "line": 25}],
			"active": main,
			"breakpoints": [{
				"path": main,
				"line": 25,
				"condition": 'stage == "local" && len(os.Args) > 1',
				"hits": "> 5",
				"log": "stage is {stage} after {time.Since(started)}",
			}],
		}, open(f"{root}/.abydos/session.json", "w"), indent=2)
	PYTHON
	# The sheet is a window of its own, so it lands beside the capture under a
	# name of its own, and is moved onto the one that was asked for.
	local sheet="${path%.png}-sheet.png"
	rm -f "$sheet"
	shoot "$path" "$theme" --open "$bp" --panel-height 200 --bp-edit 25 --delay 8
	[ -f "$sheet" ] && mv "$sheet" "$path"
	return 0
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
		--switcher '>' --delay 9
	[ -f "$popover" ] && mv "$popover" "$path"
	return 0
}

# No git shot yet. These are fresh clones with nothing uncommitted in them, so
# the changes pane would be photographed empty, which says the opposite of what
# it is for. Photographing this repository instead would mean whatever happened
# to be lying around that day.
SITE_SHOTS=(editor debugger terminal java breakpoint palette)

if [ "$SET" = site ] || [ "$SET" = all ]; then
	echo "==> The pages' pictures, in $THEME ($SIZE) → ${OUT#"$DOCS"/}"
	for name in "${SITE_SHOTS[@]}"; do
		wanted "$name" || continue
		"shot_$name" "$THEME" "$OUT/$name.png"
	done
fi

# One scene, four palettes. The same shot every time on purpose: a gallery where
# each picture also shows a different file is a gallery about the files.
if [ "$SET" = themes ] || [ "$SET" = all ]; then
	echo "==> One scene in each palette ($SIZE) → ${OUT#"$DOCS"/}/themes"
	for pair in "${THEMES[@]}"; do
		setting="${pair%%:*}" palette="${pair#*:}"
		wanted "$palette" || continue
		shot_editor "$setting" "$OUT/themes/$palette.png"
	done
fi

echo "==> Done."
