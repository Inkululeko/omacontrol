#!/usr/bin/env bash
# Two things a human would otherwise find out later: a shell module that no
# longer parses, and a change nobody restarted the shell for.
#
# Only the first is worth blocking on here — `bash -n` is instant and its
# answer is certain. The restart is remembered instead, and asked about once,
# when the turn ends: see needs-restart.sh.
set -uo pipefail

root=${CLAUDE_PROJECT_DIR:-$(pwd)}
root=${root%/}
marker="${XDG_RUNTIME_DIR:-/tmp}/omacontrol-unverified"

payload=$(cat)
file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // .tool_input.path // empty' 2>/dev/null)
[ -n "$file" ] || exit 0

case "$file" in "$root"/*) rel=${file#"$root"/} ;; *) exit 0 ;; esac
case "$rel" in .claude/*) exit 0 ;; esac   # our own config is not the plugin

case "$rel" in
  lib/*.sh|bin/*)
    if ! err=$(bash -n "$file" 2>&1); then
      printf 'bash -n rejects %s:\n%s\n' "$rel" "$err" >&2
      exit 2
    fi
    ;;
  manifest.json)
    if ! err=$(jq empty "$file" 2>&1); then
      printf '%s is not valid JSON:\n%s\n' "$rel" "$err" >&2
      exit 2
    fi
    ;;
esac

# Only what the running process holds. `lib/` and `bin/` are re-sourced on
# every invocation — the window spawns `bash bin/omacontrol …` per call — so a
# shell change is live on the next call and marking it here would be a false
# alarm on the most frequently edited files in the repo.
case "$rel" in
  *.qml|ui/*.js|manifest.json)
    printf '%s\n' "$rel" >> "$marker"
    ;;
esac
exit 0
