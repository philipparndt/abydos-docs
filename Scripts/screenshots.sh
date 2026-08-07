#!/bin/bash
# Photographs Abydos for this site.
#
# The pictures are the claim. Every one is the app doing the thing the page
# says it does, on a project from the examples repository that anybody can
# clone — nothing is staged, nothing is drawn by hand, and nothing is a mockup.
#
# Reproducible on purpose. The window is given a size, the panel is given a
# height, and each project is copied to a temporary directory first, because the
# window frame, the split position and which files were last open are all
# remembered per machine. A screenshot that depends on those is a screenshot
# that looks different for everybody who takes it.
#
# The theme is given too, and defaults to the app's own. Left to itself the app
# follows the system, so the same command run after dark produced a different
# picture — which is a thing you find out only by looking at the diff.
#
#   Scripts/screenshots.sh                 # both sets
#   Scripts/screenshots.sh site            # the five the pages use
#   Scripts/screenshots.sh site debugger   # just that one
#   Scripts/screenshots.sh themes          # one scene in each theme
#   THEME=daylight Scripts/screenshots.sh site
#   ABYDOS=~/dev/abydos EXAMPLES=~/dev/abydos-examples Scripts/screenshots.sh
set -euo pipefail

cd "$(dirname "$0")/.."
DOCS="$(pwd)"

# Both checkouts are being renamed from ideai to abydos, and the folders have
# not caught up yet. Try the new name first and fall back, so this keeps working
# on either side of the rename without an edit here.
find_checkout() {
	local name="$1"; shift
	for candidate in "$@"; do
		if [ -d "$candidate" ]; then (cd "$candidate" && pwd); return 0; fi
	done
	echo "no $name checkout — looked in $*" >&2
	return 1
}

ABYDOS="${ABYDOS:-$(find_checkout app ../abydos ../ideai)}"
EXAMPLES="${EXAMPLES:-$(find_checkout examples ../abydos-examples ../ideai-examples)}"
OUT="${OUT:-$DOCS/images}"
SIZE="${SIZE:-1600x1000}"
THEME="${THEME:-abydos}"
APP="$ABYDOS/build/Abydos.app/Contents/MacOS/Abydos"

# The themes the app offers, minus "system" — which is not a palette but a
# deferral, and resolves to one of the other two.
#
# `setting:palette`, because those are two different names for the same thing
# and the app answers to only one of them. `--theme` takes what Settings stores
# — dark, light, abydos — while Theme.swift calls the palettes dusk, daylight
# and abydos, and the page uses those. Worth spelling out, because an
# unrecognised value is not an error: the app falls back to following the
# system, so `--theme daylight` on a dark Mac quietly photographs dusk. Which is
# how this list came to be written down at all.
THEMES=(abydos:abydos dark:dusk light:daylight)

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

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

# A copy, not the original: opening a project writes a session file into it, and
# a subdirectory of a git repository resolves to the repository root — so
# `--open examples/go-service` would open the whole examples repo with whatever
# was last open in it.
prepare() {
	local example="$1" name="$2"
	rm -rf "${WORK:?}/$name"
	cp -R "$EXAMPLES/$example" "$WORK/$name"
	rm -rf "$WORK/$name/.abydos/session.json" "$WORK/$name/.ideai/session.json" \
	       "$WORK/$name/build" "$WORK/$name/target"
	(cd "$WORK/$name" && pwd -P)
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
# No `--file`: stopping opens the file itself, and opening it first leaves two
# tabs for the one file — the debugger names it by the path Delve reports, which
# is the resolved one.
shot_debugger() {
	local theme="$1" path="$2"
	local go; go="$(prepare go-service go-service)"
	shoot "$path" "$theme" --open "$go" --maximize-terminal --breakpoint 25 --debug-line 18 --delay 40
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

# No git shot. These are copies, and a copy has no `.git` — the changes pane
# would be photographed empty, which says the opposite of what it is for.
# Photographing this repository instead would mean whatever happened to be
# uncommitted that day.
SITE_SHOTS=(editor debugger terminal java breakpoint)

if [ "$SET" = site ] || [ "$SET" = all ]; then
	echo "==> The pages' pictures, in $THEME ($SIZE) → ${OUT#"$DOCS"/}"
	for name in "${SITE_SHOTS[@]}"; do
		wanted "$name" || continue
		"shot_$name" "$THEME" "$OUT/$name.png"
	done
fi

# One scene, three palettes. The same shot every time on purpose: a gallery
# where each picture also shows a different file is a gallery about the files.
if [ "$SET" = themes ] || [ "$SET" = all ]; then
	echo "==> One scene in each theme ($SIZE) → ${OUT#"$DOCS"/}/themes"
	for pair in "${THEMES[@]}"; do
		setting="${pair%%:*}" palette="${pair#*:}"
		wanted "$palette" || continue
		shot_editor "$setting" "$OUT/themes/$palette.png"
	done
fi

echo "==> Done."
