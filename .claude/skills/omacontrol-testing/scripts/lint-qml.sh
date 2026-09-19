#!/usr/bin/env bash
# The qmllint on PATH is Qt 5's and Quickshell is Qt 6. Qt 5's cannot parse a
# typed function signature — `function show(): void`, which IpcHandler
# requires — and exits 255 with no output when it meets one, so Panel.qml is
# never linted by it and a clean run from it is worth nothing.
#
# `qs.*` is what Quickshell aliases to the Omarchy shell directory, so the
# import root has to carry a `qs` link or every import fails.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
lint=/usr/lib/qt6/bin/qmllint
[ -x "$lint" ] || { echo "Qt 6 qmllint not at $lint — skipped (install qt6-declarative)"; exit 0; }

imports="${XDG_RUNTIME_DIR:-/tmp}/omacontrol-qsimports"
mkdir -p "$imports"
ln -sfn /usr/share/omarchy/shell "$imports/qs"

"$lint" -I "$imports" "$root"/*.qml "$root"/ui/*.qml "$root"/sections/*.qml 2>&1 \
  | ROOT="$root" python3 "$(dirname "${BASH_SOURCE[0]}")/qmllint-filter.py" "$@"
