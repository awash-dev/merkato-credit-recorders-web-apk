#!/usr/bin/env bash
#
# apk/.github/workflows/ is the SOURCE OF TRUTH for this repository's GitHub
# Actions workflows. GitHub only executes workflow files stored in the
# repository-root .github/workflows/ directory, so this script mirrors the
# canonical copies there.
#
#   ./apk/scripts/sync-workflows.sh          # copy apk/ -> root
#   ./apk/scripts/sync-workflows.sh --check  # verify they match (used by CI)
#
set -euo pipefail

MODE="apply"
if [ "${1:-}" = "--check" ]; then MODE="check"; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)" # .../apk
ROOT_DIR="$(cd "$APK_DIR/.." && pwd)"   # repository root
SRC="$APK_DIR/.github/workflows"
DST="$ROOT_DIR/.github/workflows"

if [ ! -d "$SRC" ]; then
  echo "error: canonical workflows not found at $SRC" >&2
  exit 1
fi

# Sorted *.yml / *.yaml file names in a directory (files only, no subdirs).
list_workflows() {
  [ -d "$1" ] || return 0
  find "$1" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -printf '%f\n' | LC_ALL=C sort
}

# Compare ignoring CR so Windows (CRLF) and Linux (LF) checkouts agree.
same_file() {
  cmp -s <(tr -d '\r' < "$1") <(tr -d '\r' < "$2")
}

if [ "$MODE" = "check" ]; then
  status=0

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ ! -f "$DST/$name" ] || ! same_file "$SRC/$name" "$DST/$name"; then
      echo "::error::.github/workflows/$name is missing or out of sync with apk/.github/workflows/$name"
      echo "  fix: run ./apk/scripts/sync-workflows.sh and commit the result"
      status=1
    fi
  done < <(list_workflows "$SRC")

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ ! -f "$SRC/$name" ]; then
      echo "::error::.github/workflows/$name has no canonical copy under apk/.github/workflows/"
      echo "  fix: move it into apk/.github/workflows/ and run ./apk/scripts/sync-workflows.sh"
      status=1
    fi
  done < <(list_workflows "$DST")

  if [ "$status" -eq 0 ]; then
    echo "OK: root .github/workflows/ matches apk/.github/workflows/"
  fi
  exit "$status"
fi

# --- apply mode -------------------------------------------------------------
mkdir -p "$DST"

copied=0
while IFS= read -r name; do
  [ -n "$name" ] || continue
  cp "$SRC/$name" "$DST/$name"
  copied=$((copied + 1))
done < <(list_workflows "$SRC")

# Drop stale root workflows that no longer have a canonical copy.
removed=0
while IFS= read -r name; do
  [ -n "$name" ] || continue
  rm -f "$DST/$name"
  removed=$((removed + 1))
done < <(comm -23 <(list_workflows "$DST") <(list_workflows "$SRC"))

echo "synced $copied workflow(s) into .github/workflows/ ($removed stale file(s) removed)"
