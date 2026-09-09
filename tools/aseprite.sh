#!/bin/sh
# tools/aseprite.sh
#
# Bakes `.aseprite` sources to a horizontal PNG sheet plus a tag manifest, both of which
# Godot's stock importer reads. Takes files or directories:
#
#   tools/aseprite.sh assets/src/hero.aseprite
#   tools/aseprite.sh --out assets/baked assets/src
#
# The manifest is Aseprite's own JSON reduced to the sheet size, each frame's duration
# and the tags. The rest is dropped, because `meta.image` is an absolute path and
# `meta.version` is the installed binary, so both churn per machine and per upgrade.
#
# The binary is found through `ASEPRITE`, then `PATH`, then the usual install
# locations, since its path is per-machine and cannot be committed.
#
# NOTE: Never add `*.aseprite` to an export preset's `exclude_filter`. A filter that
# matches a source also drops the `.res`/`.sample` baked beside it, and nothing says so
# until an exported build looks for the asset at runtime.

set -eu

usage() {
  echo "usage: tools/aseprite.sh [--out DIR] <file.aseprite | directory>..." >&2
  exit 2
}

# find_aseprite prints the path to the Aseprite binary.
find_aseprite() {
  if [ -n "${ASEPRITE:-}" ]; then
    if [ ! -x "$ASEPRITE" ]; then
      echo "aseprite.sh: ASEPRITE is set but not executable: $ASEPRITE" >&2
      return 2
    fi

    printf '%s\n' "$ASEPRITE"
    return 0
  fi

  if command -v aseprite >/dev/null 2>&1; then
    command -v aseprite
    return 0
  fi

  for candidate in \
    "/c/Program Files/Aseprite/Aseprite.exe" \
    "/c/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe" \
    "${LOCALAPPDATA:-$HOME/AppData/Local}/Aseprite/Aseprite.exe" \
    "/Applications/Aseprite.app/Contents/MacOS/aseprite" \
    "$HOME/Applications/Aseprite.app/Contents/MacOS/aseprite"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

# native prints a path the way the Aseprite binary expects it, which on Windows is not
# the way this shell writes it.
native() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s\n' "$1"
  fi
}

# bake exports one source to `<out>/<name>.png` and `<out>/<name>.json`.
bake() {
  src="$1"
  out="$2"

  name="$(basename "$src")"
  name="${name%.*}"

  # NOTE: Outputs are named after the source's basename, so two sources sharing one
  # would overwrite each other. The record is a file because the walk below subshells.
  if grep -qxF "$name" "$work/names" 2>/dev/null; then
    echo "aseprite.sh: more than one source is named '$name'; they would overwrite" \
      "each other in '$out'." >&2
    return 1
  fi

  printf '%s\n' "$name" >>"$work/names"

  png="$out/$name.png"
  manifest="$out/$name.json"
  raw="$work/$name.raw.json"

  # NOTE: `--list-tags` is what emits `meta.frameTags[]`; without it the manifest has no
  # animations at all. There is no `--trim`, because `hframes` and `SpriteFrames` both
  # expect uniform, full-canvas frames.
  "$aseprite" -b "$(native "$src")" \
    --sheet "$(native "$png")" \
    --sheet-type horizontal \
    --data "$(native "$raw")" \
    --format json-array \
    --list-tags

  jq --arg source "$(basename "$src")" '{
    source: $source,
    size: [.meta.size.w, .meta.size.h],
    frame_size: [.frames[0].sourceSize.w, .frames[0].sourceSize.h],
    frames: [.frames[] | {duration}],
    tags: [
      .meta.frameTags[]? | . as $tag
      | {name: $tag.name, from: $tag.from, to: $tag.to, direction: $tag.direction}
        + (if ($tag | has("repeat")) then {repeat: $tag.repeat} else {} end)
    ],
  }' "$raw" >"$manifest"

  echo "$png"
  echo "$manifest"
}

out_dir=""

# NOTE: Options come first, and everything from the first non-option onward is a
# source, left in the positional parameters for the walk at the bottom of the file.
while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      [ $# -ge 2 ] || usage
      out_dir="$2"
      shift 2
      ;;
    --) shift; break ;;
    -h | --help) usage ;;
    -*) usage ;;
    *) break ;;
  esac
done

[ $# -gt 0 ] || usage

for tool in jq mktemp; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "aseprite.sh: '$tool' not found in PATH." >&2
    exit 1
  fi
done

# NOTE: A status of 2 means the search already reported what was wrong. Capture it
# here, not from `$?` inside an `if !`, where the negation has replaced it with 0.
status=0
aseprite="$(find_aseprite)" || status=$?

if [ "$status" -ne 0 ]; then
  if [ "$status" -ne 2 ]; then
    echo "aseprite.sh: no Aseprite binary found; set ASEPRITE to its path." >&2
  fi

  exit 1
fi

# NOTE: One scratch directory, removed however the script exits. Cleaning up per file
# would leak Aseprite's raw data whenever `set -e` cut a bake short inside the walk.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [ -n "$out_dir" ]; then
  mkdir -p "$out_dir"
fi

for source in "$@"; do
  if [ -d "$source" ]; then
    find "$source" \( -name '*.aseprite' -o -name '*.ase' \) | while IFS= read -r file; do
      bake "$file" "${out_dir:-$(dirname "$file")}"
    done
    continue
  fi

  if [ ! -f "$source" ]; then
    echo "aseprite.sh: no such file: $source" >&2
    exit 1
  fi

  bake "$source" "${out_dir:-$(dirname "$source")}"
done
