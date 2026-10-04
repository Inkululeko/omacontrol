---
description: Lint OmaControl without restarting the shell — manifest, bash syntax, Qt 6 qmllint
allowed-tools: Bash(cd:*), Bash(omarchy plugin validate:*), Bash(bash -n:*), Bash(.claude/skills/omacontrol-testing/scripts/lint-qml.sh:*)
---

Manifest and shell syntax:

!`cd "${CLAUDE_PROJECT_DIR:-$PWD}" && (command -v omarchy >/dev/null && omarchy plugin validate . || echo "omarchy not on PATH"); for f in bin/omacontrol bin/omacontrol-migrate lib/*.sh; do bash -n "$f" || echo "FAILED: $f"; done; echo "bash -n: $(ls lib/*.sh | wc -l) modules + 2 scripts checked"`

Qt 6 qmllint:

!`cd "${CLAUDE_PROJECT_DIR:-$PWD}" && .claude/skills/omacontrol-testing/scripts/lint-qml.sh 2>&1 | tail -25 || true`

Summarise what is wrong, if anything. The four expected classes of qmllint
finding are counted rather than listed — a change in those counts is worth a
look, but they are not errors. This does **not** restart the shell, so it does
not tell you the change works; only `/verify` does that.
