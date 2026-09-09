#!/bin/sh
# tools/bridge.sh
#
# Runs `tools/bridge.py` with an interpreter that receives its arguments intact:
#
#   tools/bridge.sh launch
#   tools/bridge.sh eval 'Main.screens().get_depth()'
#
# A `python` on `PATH` is not always a program. A pyenv-win shim is a shell script that
# re-enters `pyenv`, a batch file, so `cmd.exe` re-parses the arguments and any
# expression containing parentheses dies before Python starts. Asking pyenv for the
# interpreter itself skips the shim; every other case falls through to `PATH`.
#
# Set `PYTHON` to override the search.

set -eu

here="$(dirname "$0")"

# find_python prints the path to an interpreter that can be executed directly.
find_python() {
  if [ -n "${PYTHON:-}" ]; then
    printf '%s\n' "$PYTHON"
    return 0
  fi

  if command -v pyenv >/dev/null 2>&1; then
    resolved="$(pyenv which python 2>/dev/null || true)"
    if [ -n "$resolved" ] && [ -f "$resolved" ]; then
      printf '%s\n' "$resolved"
      return 0
    fi
  fi

  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done

  return 1
}

python="$(find_python)" || {
  echo "bridge.sh: no Python 3 interpreter found; set PYTHON to its path." >&2
  exit 1
}

exec "$python" "$here/bridge.py" "$@"
