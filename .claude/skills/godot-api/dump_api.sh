#!/bin/sh
# .claude/skills/godot-api/dump_api.sh
#
# Dumps API references to '.godot-api' (gitignored) so lookups can be grepped
# instead of recalled. Three sources are dumped separately:
#
#   engine/   the built-in class reference, from ClassDB reflection. Carries
#             signatures, parameter types and defaults, properties, signals,
#             inheritance and enum values, but NO prose: a release binary does
#             not embed the description text.
#   std/      the standard library, generated from its inline '##' comments.
#             Carries prose as well as signatures. Files are named after the
#             source path.
#   project/  this project's own classes, likewise from inline comments. Files
#             are named after each script's 'class_name'.
#
# The prose in std/ and project/ is the part worth having, since those APIs
# cannot be looked up anywhere else.

set -eu

# This script ships with its skill rather than in `tools/`, so it cannot locate the
# project by its own path; the harness sets CLAUDE_PROJECT_DIR, and git covers a
# direct shell invocation.
project_dir="${CLAUDE_PROJECT_DIR:-}"
[ -n "$project_dir" ] ||
  project_dir="$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)"
out_dir="$project_dir/.godot-api"

dump_gdscript() {
  name="$1"
  source_path="$2"

  rm -rf "${out_dir:?}/$name"
  mkdir -p "$out_dir/$name"

  godot --headless --path "$project_dir" \
    --doctool "$out_dir/$name" --gdscript-docs "$source_path" >/dev/null 2>&1

  echo "  $name: $(find "$out_dir/$name" -name '*.xml' | wc -l) classes"
}

rm -rf "${out_dir:?}/engine"
mkdir -p "$out_dir/engine"
godot --headless --doctool "$out_dir/engine" >/dev/null 2>&1
echo "  engine: $(find "$out_dir/engine" -name '*.xml' | wc -l) classes (signatures only)"

dump_gdscript std "res://addons/std"
dump_gdscript project "res://project"
dump_gdscript system "res://system"
dump_gdscript platform "res://platform"

echo "dumped to $out_dir"
