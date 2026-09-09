#!/bin/sh
# .claude/hooks/gd_on_edit.sh
#
# Claude Code PostToolUse hook. On an edit to a `.gd` file it runs gdformat and gdlint;
# on an edit to any file the project checker covers it runs `tools/check.gd`, which
# assigns a missing uid and reports the problems a normal load does not surface. Reads
# the hook payload from stdin and exits 2 with details on stderr, so both a failure and
# a repair the checker made are reported back to the agent.
#
# The checker is one Godot boot for every rule that applies to the file, which is what
# keeps this hook inside its ~1.5s budget; a `.gd` edit costs ~1.1s and a `.tscn` edit
# ~1.3s. Do not add a second boot.

set -eu

for tool in jq uv godot; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "gd_on_edit.sh: '$tool' not found in PATH; skipping checks." >&2
    exit 0
  fi
done

payload="$(cat)"
file_path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')"

[ -n "$file_path" ] || exit 0

project_dir="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"

# The payload carries a native absolute path, which on Windows is not what the
# shell or the engine expect.
if command -v cygpath >/dev/null 2>&1; then
  file_path="$(cygpath -u "$file_path")"
fi

[ -f "$file_path" ] || exit 0

# The engine resolves paths against the project root, so hand it a relative one.
case "$file_path" in
  "$project_dir"/*) rel_path="${file_path#"$project_dir"/}" ;;
  /*) exit 0 ;;
  *) rel_path="$file_path" ;;
esac

# Vendored addons are third-party code held to their own upstream style, so the
# format and lint commands in AGENTS.md exclude them; the hook must match, or an
# edit to a vendored file is blocked by unfixable upstream violations.
case "$rel_path" in
  addons/*) exit 0 ;;
esac

case "$rel_path" in
  *.gd | *.tscn | *.tres) ;;
  *) exit 0 ;;
esac

# The checker is project content rather than part of this hook, so a repository that
# installed the hook without copying it has nothing to run.
[ -f "$project_dir/tools/check.gd" ] || exit 0

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

status=0

# Every headless run prints the same boilerplate: the engine banner, godotsteam's
# settings conversion, and the leaked-object and resources-in-use notices the engine
# emits while tearing down. None of it is actionable and all of it buries the lines
# that are, so it is dropped here by exact match. Script errors and warnings are NOT
# filtered.
NOISE='^Godot Engine v'
NOISE="$NOISE|^WARNING: Found older |^   at: register_settings"
NOISE="$NOISE|^WARNING: [0-9]+ ObjectDB instances were leaked|^   at: cleanup "
NOISE="$NOISE|^ERROR: [0-9]+ resources still in use at exit|^   at: clear "
NOISE="$NOISE|^exit status [0-9]+$"

# Feedback for a blocking hook must go to stderr; stdout is not surfaced.
report() {
  echo "$1 for $rel_path:" >&2
  grep -Ev "$NOISE" "$out" | sed '/^[[:space:]]*$/d' >&2 || true
  status=2
}

case "$rel_path" in
  *.gd)
    (cd "$project_dir" && uv run gdformat --check "$rel_path") >"$out" 2>&1 ||
      report "gdformat --check failed"
    (cd "$project_dir" && uv run gdlint "$rel_path") >"$out" 2>&1 ||
      report "gdlint failed"
    ;;
esac

# A non-zero exit means there is something to read, whether a problem was found or a uid
# was assigned; the engine cannot tell the two apart through an exit code, so the label
# stays neutral and the checker's own output says which it was.
godot --headless --path "$project_dir" -s tools/check.gd -- --fix "$rel_path" \
  >"$out" 2>&1 || report "project check reported"

# Game logic carries a fast simulation test alongside the usual checks. The branch stays
# inert until a harness exists, since GUT run against a directory holding no test spends
# 3.3s to report that nothing ran, and exits 0 while doing it.
case "$rel_path" in
  project/core/*)
    if ls "$project_dir"/project/core/*_test.gd >/dev/null 2>&1; then
      godot --headless --path "$project_dir" \
        -s addons/gut/gut_cmdln.gd -gdir="res://project/core" \
        -ginclude_subdirs -gprefix="" -gsuffix="_test.gd" -gexit >"$out" 2>&1 ||
        report "sim test failed"
    fi
    ;;
esac

exit "$status"
