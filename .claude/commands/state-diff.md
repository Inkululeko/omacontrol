---
description: Capture the state document as a baseline, or diff the current one against it
argument-hint: "capture | compare"
allowed-tools: Bash(cd:*), Bash(.claude/skills/omacontrol-testing/scripts/state-diff.sh:*), Read
---

!`cd "${CLAUDE_PROJECT_DIR:-$PWD}" && .claude/skills/omacontrol-testing/scripts/state-diff.sh "$ARGUMENTS" || true`

Before refactoring anything in `lib/`, run `/state-diff capture`. Afterwards run
`/state-diff compare`: the document should be identical once the volatile
fields are taken out. Any other difference is a behaviour change, whether or
not it was intended — say which it is.
