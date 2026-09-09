#!/bin/sh
# tools/bridge.sh
#
# Runs `tools/bridge.py` through uv, which supplies the interpreter:
#
#   tools/bridge.sh launch
#   tools/bridge.sh eval 'Main.screens().get_depth()'

set -eu

here="$(dirname "$0")"
project_dir="$(CDPATH='' cd -- "$here/.." && pwd)"

if ! command -v uv >/dev/null 2>&1; then
  echo "bridge.sh: 'uv' not found in PATH; see the README's setup section." >&2
  exit 1
fi

exec uv run --project "$project_dir" python "$project_dir/tools/bridge.py" "$@"
