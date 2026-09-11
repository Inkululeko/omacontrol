# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.
#
# What pacman has, and what it is waiting to do. Read-only apart from the
# housekeeping the page offers, each of which is handed to the tool that owns
# it rather than reimplemented.
#
# The split that matters here is cheap-vs-network. Counting what is installed
# is four `pacman -Qq` calls against the local database and costs nothing.
# Knowing what is *available* means a database sync, which is a network round
# trip — so it is cached, stamped, and never made because someone opened a
# page. That is what the design's "mirrors refreshed 06:02" is saying.

PACKAGES_CACHE="${OMACONTROL_PACKAGES_CACHE:-${XDG_CACHE_HOME:-$HOME_DIR/.cache}/omarchy/omacontrol/updates.json}"
PACKAGES_MAX_AGE=${OMACONTROL_PACKAGES_MAX_AGE:-3600}
# How long a check may stand before the page makes one itself. A day, because
# that is how often a rolling distribution is worth asking about unprompted:
# short enough that "nothing waiting" is never a week old, long enough that
# opening the page ten times in an afternoon is still ten local reads and no
# network at all.
PACKAGES_AUTO_AGE=${OMACONTROL_PACKAGES_AUTO_AGE:-86400}

packages_counts() {
  par_begin || { echo '{}'; return; }
  par_run all pacman_count -Qq
  par_run explicit pacman_count -Qqe
  par_run foreign pacman_count -Qqm
  par_run orphans pacman_count -Qqdt
  par_wait
  local all explicit foreign orphans
  all=$(par_get all 0); explicit=$(par_get explicit 0)
  foreign=$(par_get foreign 0); orphans=$(par_get orphans 0)
  par_end

  jq -cn --argjson all "${all:-0}" --argjson explicit "${explicit:-0}" \
    --argjson foreign "${foreign:-0}" --argjson orphans "${orphans:-0}" \
    '{ installed: $all, explicit: $explicit, foreign: $foreign, orphans: $orphans }'
}

pacman_count() {
  local n
  n=$(capture pacman "$@" | wc -l)
  printf '%s' "${n:-0}"
}

# ---------------------------------------------------------------- what is due
#
# `checkupdates` syncs a temporary database rather than the system one, which
# is the only safe way to ask this question without a lock — but it is still a
# sync, so it happens on request and the answer is kept.
packages_pending_cached() {
  [[ -f $PACKAGES_CACHE ]] || { echo '{}'; return; }
  emit_json "$(read_file "$PACKAGES_CACHE")" '{}'
}

packages_stale() {
  [[ ! -f $PACKAGES_CACHE ]] && return 0
  local at
  at=$(packages_pending_cached | jq -r '.checkedAt // 0' 2>/dev/null)
  (( $(date +%s) - ${at:-0} > PACKAGES_MAX_AGE ))
}

# Asked on open, and free to ask: the age is compared here rather than in the
# page, so the page may ask as often as it likes and only a check that is
# actually owed costs a sync. The same shape as `news fetch`, for the same
# reason.
packages_fetch() {
  local at
  at=$(packages_pending_cached | jq -r '.checkedAt // 0' 2>/dev/null)
  if (( $(date +%s) - ${at:-0} > PACKAGES_AUTO_AGE )); then
    packages_refresh
  else
    packages_pending_cached
  fi
}

packages_refresh() {
  command -v checkupdates >/dev/null 2>&1 || { echo '{}'; return; }
  local repo aur
  # A longer bound than the other readers get: these are network syncs, and
  # five seconds is not enough for a mirror on a bad day.
  repo=$(timeout 60 checkupdates --nocolor 2>/dev/null | head -c "$OMACONTROL_READ_MAX")
  aur=$(packages_aur_pending)

  local items
  # `pkg old -> new` from both, which is the one format they agree on.
  items=$(printf '%s\n%s\n' "$repo" "$aur" \
    | awk 'NF >= 4 && $2 != "" && $3 == "->" {
        printf "%s\t%s\t%s\n", $1, $2, $4
      }' | jq -Rc -s '
      [ split("\n")[] | select(length > 0) | split("\t")
        | { name: .[0], installed: .[1], available: .[2] } ]
      | unique_by(.name)')

  # Which of them came from the AUR, so the page can label and filter them.
  # Asked of the local database, which already knows.
  local foreign explicit sizes
  foreign=$(capture pacman -Qqm | jq -Rc -s '[ split("\n")[] | select(length > 0) ]')
  explicit=$(capture pacman -Qqe | jq -Rc -s '[ split("\n")[] | select(length > 0) ]')
  # What each one costs to fetch. One sync database query for the whole list —
  # 184 packages in a sixth of a second — so there is no reason for the page
  # to show a count of updates without their weight. AUR packages are built
  # rather than downloaded, so the repositories are the only ones with an
  # answer here.
  sizes=$(packages_sizes "$items")

  local next
  next=$(jq -cn --argjson items "${items:-[]}" --argjson foreign "${foreign:-[]}" \
    --argjson explicit "${explicit:-[]}" --argjson sizes "${sizes:-{\}}" \
    --argjson at "$(date +%s)" '''
    { checkedAt: $at,
      # Bound first. Inside `index(...)` the `.` is the list being searched,
      # not the row — so `index(.name)` asks the array for its own .name,
      # which is null, and every row comes back the same. The trap is in
      # CLAUDE.md and it still caught this one.
      items: [ $items[] | . as $row
               | $row + { foreign: ($foreign | index($row.name) != null),
                          explicit: ($explicit | index($row.name) != null),
                          bytes: ($sizes[$row.name] // null) } ] }''')
  mkdir -p "$(dirname "$PACKAGES_CACHE")"
  printf '%s\n' "$next" >"$PACKAGES_CACHE" 2>/dev/null
  printf '%s' "$next"
}

# Download size per package, keyed by name. expac asks the sync database in
# one call and answers in bytes, which is what the window formats; `pacman -Si`
# would answer in MiB strings that then have to be parsed back.
packages_sizes() {
  local names
  names=$(jq -r '[ .[] | select(.foreign != true) | .name ] | join(" ")' <<<"${1:-[]}" 2>/dev/null)
  [[ -n ${names// /} ]] || { echo '{}'; return; }
  command -v expac >/dev/null 2>&1 || { echo '{}'; return; }

  emit_json "$(capture expac -S '%n\t%k' $names \
    | jq -Rc -s '[ split("\n")[] | select(length > 0) | split("\t")
                   | { key: .[0], value: (.[1] | tonumber? // null) } ] | from_entries')" '{}'
}

# checkupdates is repositories only — it has no idea the AUR exists — so an
# AUR-heavy machine would be told it was up to date while a dozen packages
# waited. yay answers for those, behind the same reachability test Omarchy's
# own updater uses: the AUR is frequently down, and a page should not stall on
# it or report "nothing waiting" when it simply could not ask.
packages_aur_pending() {
  command -v yay >/dev/null 2>&1 || return 0
  capture pacman -Qqm >/dev/null 2>&1 || return 0
  omarchy-pkg-aur-accessible >/dev/null 2>&1 || return 0
  timeout 60 yay -Qua 2>/dev/null | head -c "$OMACONTROL_READ_MAX"
}

# ---------------------------------------------------------------- housekeeping
#
# The four questions worth asking of a machine that has been updating itself
# for a year: what is the cache holding, what is installed that nothing needs,
# what came from outside a repository, and what config changes are waiting.
packages_housekeeping() {
  par_begin || { echo '{}'; return; }
  par_run cache du_bytes /var/cache/pacman/pkg
  par_run pacnew packages_pacnew
  par_wait
  local cache pacnew
  cache=$(par_get cache null)
  pacnew=$(par_get pacnew 0)
  par_end

  jq -cn --argjson cache "${cache:-null}" --argjson pacnew "${pacnew:-0}" \
    '{ cacheBytes: $cache, pacnew: $pacnew }'
}

# A .pacnew is a config pacman would have overwritten and did not. They are
# easy to accumulate and silent about it, which is exactly what a page like
# this is for.
packages_pacnew() {
  local n
  n=$(capture find /etc -maxdepth 3 -name '*.pacnew' | wc -l)
  printf '%s' "${n:-0}"
}

# What pacman did, in the words it used itself. Read from its log rather than
# reconstructed: the log is the record, and summarising a day of upgrades as
# "upgraded 118 packages" is the only transformation applied.
packages_history() {
  local log=/var/log/pacman.log
  [[ -r $log ]] || { echo '[]'; return; }

  emit_json "$(capture tail -c 400000 "$log" \
    | awk '
      # [2026-08-31T18:16:02+0200] [ALPM] upgraded linux (7.1.8-1 -> 7.1.9-1)
      match($0, /^\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}/) {
        stamp = substr($0, 2, 16)
        if ($0 ~ /\[ALPM\] (upgraded|installed|removed|downgraded) /) {
          verb = $3; sub(/^\[ALPM\]$/, "", verb)
          for (i = 1; i <= NF; i++)
            if ($i == "upgraded" || $i == "installed" || $i == "removed" || $i == "downgraded") {
              verb = $i; name = $(i + 1); break
            }
          # One line per transaction, not per package: a system upgrade is one
          # thing the reader did, not a hundred and eighteen.
          key = stamp "\t" verb
          if (!(key in count)) { order[++n] = key; first[key] = name }
          count[key]++
        }
      }
      END {
        for (i = n; i >= 1 && i > n - 12; i--) {
          key = order[i]
          split(key, part, "\t")
          printf "%s\t%s\t%s\t%s\n", part[1], part[2], count[key], first[key]
        }
      }' \
    | jq -Rc -s '''
      [ split("\n")[] | select(length > 0) | split("\t")
        | { at: .[0], verb: .[1], count: (.[2] | tonumber? // 1), name: .[3] } ]''' 2>/dev/null)" '[]'
}

packages_state() {
  par_begin || { echo '{}'; return; }
  par_run counts packages_counts
  par_run housekeeping packages_housekeeping
  par_run history packages_history
  par_wait
  local counts housekeeping history pending
  counts=$(par_get counts '{}')
  housekeeping=$(par_get housekeeping '{}')
  history=$(par_get history '[]')
  par_end
  # Off the cache, never synced here: this runs on the page's poll.
  pending=$(packages_pending_cached)

  jq -cn \
    --argjson counts "${counts:-{\}}" \
    --argjson housekeeping "${housekeeping:-{\}}" \
    --argjson history "${history:-[]}" \
    --argjson pending "${pending:-{\}}" \
    '$counts + $housekeeping + { history: $history,
                                 pending: ($pending.items // []),
                                 checkedAt: ($pending.checkedAt // 0) }'
}

packages_cmd() {
  case ${1:-state} in
    state|poll) packages_state ;;
    refresh) packages_refresh ;;
    fetch) packages_fetch ;;
    stale) packages_stale && echo true || echo false ;;
    # Every one of these is a terminal job with a password prompt and a
    # confirmation, so it is handed to a terminal rather than run headless.
    # A settings window is not the place to be silently installing a kernel.
    update) setsid -f omarchy-update >/dev/null 2>&1 ;;
    snapshot-update) setsid -f bash -lc 'omarchy-snapshot && omarchy-update' >/dev/null 2>&1 ;;
    mirrors) setsid -f omarchy-launch-floating-terminal-with-presentation \
      "sudo pacman -Syy" >/dev/null 2>&1 ;;
    clean) setsid -f omarchy-launch-floating-terminal-with-presentation \
      "sudo paccache -rk2" >/dev/null 2>&1 ;;
    orphans) setsid -f omarchy-launch-floating-terminal-with-presentation \
      "omarchy-update-orphan-pkgs" >/dev/null 2>&1 ;;
    pacnew) setsid -f omarchy-launch-floating-terminal-with-presentation \
      "sudo DIFFPROG='nvim -d' pacdiff" >/dev/null 2>&1 ;;
    log) setsid -f omarchy-launch-tui "less +G /var/log/pacman.log" >/dev/null 2>&1 ;;
    *) die "usage: omacontrol packages poll|refresh|fetch|stale|update|snapshot-update|mirrors|clean|orphans|pacnew|log" ;;
  esac
}
