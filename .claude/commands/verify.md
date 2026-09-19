---
description: Restart the Omarchy shell and report whether OmaControl came back clean
allowed-tools: Bash(.claude/skills/omacontrol-testing/scripts/verify.sh), Bash(journalctl:*), Read
---

Tell the user first that this restarts the shell and the bar will be dead for
about seven seconds, then run:

```
.claude/skills/omacontrol-testing/scripts/verify.sh
```

Report what it found. If the journal shows a QML error, name the file and line
— a page that fails to load leaves the window blank with no other sign, so the
journal is the only place it appears.

Do not report a change as done unless this exits clean.
